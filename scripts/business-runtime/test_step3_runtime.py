from __future__ import annotations

import importlib.util
import json
import re
import base64
import hashlib
import argparse
import os
import ssl
import socket
import threading
import http.server
import subprocess
from unittest import mock
import tuyu_https_proxy as PROXY
import tuyu_runtime_common as COMMON
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))


def load_runtime(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / f"{name}.py")
    assert spec and spec.loader
    runtime = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runtime)
    return runtime


VOYANT_RUNTIME = load_runtime("tuyu_voyant_runtime")
FRAPPE_RUNTIME = load_runtime("tuyu_frappe_runtime")
HI_EVENTS_RUNTIME = load_runtime("tuyu_hi_events_runtime")


class VoyantRuntimeTests(unittest.TestCase):
    def test_rewrite_migration_keeps_tables_inside_module_schema(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.sql"
            target = Path(directory) / "target.sql"
            source.write_text(
                'CREATE TYPE "public"."kind" AS ENUM(\'a\');\n'
                "WHERE n.nspname = 'public';\n",
                encoding="utf-8",
            )
            VOYANT_RUNTIME.rewrite_migration(source, target, "module_voyant")
            sql = target.read_text(encoding="utf-8")
            self.assertIn('"module_voyant"."kind"', sql)
            self.assertIn("n.nspname = 'module_voyant'", sql)
            self.assertNotIn('"public".', sql)

    def test_identifiers_are_restricted(self) -> None:
        self.assertEqual(
            VOYANT_RUNTIME.safe_identifier("module_voyant"), "module_voyant"
        )
        with self.assertRaises(ValueError):
            VOYANT_RUNTIME.safe_identifier(
                "module_voyant; DROP DATABASE tuyubooking"
            )


class FrappeRuntimeTests(unittest.TestCase):
    @staticmethod
    def config() -> dict[str, object]:
        return {
            "bench_apps": ["frappe", "kamra"],
            "database_host": "127.0.0.1",
            "database_port": 5432,
            "database_name": "tuyubooking",
            "database_role": "tuyu_kamra_app",
            "database_schema": "module_kamra",
            "site_name": "hotel.localhost",
        }

    @staticmethod
    def create_runtime(root: Path, include_assets: bool = True) -> Path:
        runtime = root / "runtime"
        (runtime / "bench" / "apps" / "frappe").mkdir(parents=True)
        if include_assets:
            assets = runtime / "bench" / "sites" / "assets"
            assets.mkdir(parents=True)
            (assets / "assets.json").write_text(
                json.dumps({"login.bundle.css": "/assets/frappe/login.css"}),
                encoding="utf-8",
            )
        return runtime

    def test_prepare_bench_shares_only_immutable_code_and_assets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = self.create_runtime(root)
            data = root / "data"
            bench = FRAPPE_RUNTIME.prepare_bench(self.config(), runtime, data)

            self.assertTrue((bench / "apps").is_symlink())
            self.assertEqual(
                (bench / "apps").resolve(), (runtime / "bench" / "apps").resolve()
            )
            self.assertTrue((bench / "sites" / "assets").is_symlink())
            self.assertEqual(
                (bench / "sites" / "assets").resolve(),
                (runtime / "bench" / "sites" / "assets").resolve(),
            )
            self.assertFalse((runtime / "bench" / "sites" / "hotel.localhost").exists())
            common = json.loads(
                (bench / "sites" / "common_site_config.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(common["db_schema"], "module_kamra")
            environment = FRAPPE_RUNTIME.runtime_environment(
                self.config(), runtime, bench
            )
            self.assertEqual(
                Path(environment["TUYU_FRAPPE_ASSETS"]).resolve(),
                (runtime / "bench" / "sites" / "assets").resolve(),
            )
            self.assertTrue(environment["PYTHONPATH"].startswith(str(runtime)))

    def test_prepare_bench_replaces_legacy_generated_copies(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = self.create_runtime(root)
            data = root / "data"
            (data / "bench" / "apps" / "stale").mkdir(parents=True)
            (data / "bench" / "sites" / "assets" / "stale").mkdir(parents=True)

            bench = FRAPPE_RUNTIME.prepare_bench(self.config(), runtime, data)

            self.assertTrue((bench / "apps").is_symlink())
            self.assertTrue((bench / "sites" / "assets").is_symlink())

    def test_prepare_bench_rejects_missing_asset_map(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = self.create_runtime(root, include_assets=False)
            with self.assertRaises(FileNotFoundError):
                FRAPPE_RUNTIME.prepare_bench(self.config(), runtime, root / "data")


class StrictTlsTests(unittest.TestCase):
    # 运行地址检查既覆盖普通HTTPS，也覆盖旧明文、越界和URL歧义。
    def test_module_origins_require_https_without_url_credentials(self) -> None:
        self.assertEqual(PROXY.Route.parse("/hotel=https://127.0.0.1:58443").port, 58443)
        self.assertEqual(PROXY.Route.parse("/hotel=https://localhost:58443/").hostname, "localhost")
        for value in [
            "/hotel=http://127.0.0.1:58443", "/hotel=ws://127.0.0.1:58443",
            "/hotel=wss://127.0.0.1:58443", "/hotel=https://user@localhost:58443",
            "/hotel=https://localhost:58443/path", "/hotel=https://localhost:58443?x=1",
            "/hotel=https://localhost:58443#x", "/hotel=https://example.com:58443",
            "/hotel=https://localhost:0", "/hotel=https://localhost:99999",
            "/hotel=https://localhost:no", "/../hotel=https://localhost:58443",
        ]:
            with self.subTest(origin=value), self.assertRaises(argparse.ArgumentTypeError):
                PROXY.Route.parse(value)

    def test_missing_or_corrupt_ca_never_disables_verification(self) -> None:
        with self.assertRaises(ValueError):
            PROXY.upstream_tls_context([])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ca.pem"
            with self.assertRaises(OSError):
                PROXY.upstream_tls_context([path])
            path.write_text("invalid public certificate", encoding="ascii")
            with self.assertRaises(ssl.SSLError):
                PROXY.upstream_tls_context([path])

    def test_partial_identity_fails_without_replacing_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tls = root / "data" / "tls"
            tls.mkdir(parents=True)
            certificate = tls / "localhost.crt"
            certificate.write_text("invalid public certificate", encoding="ascii")
            before = certificate.read_bytes()
            with mock.patch.object(COMMON.subprocess, "run") as generate:
                with self.assertRaises((OSError, ssl.SSLError)):
                    COMMON.ensure_certificate(root / "runtime", root / "data", "merchant.local")
                generate.assert_not_called()
            self.assertEqual(certificate.read_bytes(), before)
            self.assertFalse((tls / "localhost.key").exists())

    def test_hi_events_config_has_no_plaintext_http_hop(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, config = HI_EVENTS_RUNTIME.write_service_configs(
                root / "runtime", root / "data", 58446, root / "cert.pem", root / "key.pem"
            )
            text = config.read_text()
            self.assertIn("listen 127.0.0.1:59448 ssl;", text)
            self.assertIn("proxy_pass https://127.0.0.1:59449;", text)
            self.assertIn("proxy_ssl_verify on;", text)
            self.assertIn('proxy_ssl_trusted_certificate "', text)
            self.assertNotIn("proxy_pass http:", text)

    def test_real_tls_requires_trusted_certificate_and_correct_hostname(self) -> None:
        # 临时TLS身份只存在私有系统临时目录，不输出私钥或其摘要。
        openssl = os.environ.get("TUYU_TEST_OPENSSL")
        if not openssl or not Path(openssl).is_absolute() or not os.access(openssl, os.X_OK):
            self.fail("real TLS regression requires explicit registered OpenSSL path")
        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            def do_GET(self):
                if self.headers.get("Upgrade", "").lower() == "websocket":
                    key = self.headers.get("Sec-WebSocket-Key", "")
                    accept = base64.b64encode(hashlib.sha1(
                        (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")
                    ).digest()).decode("ascii")
                    self.send_response(101)
                    self.send_header("Upgrade", "websocket")
                    self.send_header("Connection", "Upgrade")
                    self.send_header("Sec-WebSocket-Accept", accept)
                    self.end_headers()
                    header = self.rfile.read(2)
                    if len(header) != 2 or header[0] != 0x81 or not header[1] & 0x80:
                        return
                    length = header[1] & 0x7f
                    if length >= 126:
                        return
                    mask, payload = self.rfile.read(4), self.rfile.read(length)
                    if len(mask) != 4 or len(payload) != length:
                        return
                    payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
                    self.wfile.write(bytes([0x81, length]) + payload)
                    self.wfile.flush()
                    self.close_connection = True
                    return
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"verified TLS")
            def log_message(self, *_args):
                pass
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cert, key = root / "server.crt", root / "server.key"
            subprocess.run([
                openssl, "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes",
                "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
                "-addext", "extendedKeyUsage=serverAuth", "-keyout", str(key), "-out", str(cert),
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            key.chmod(0o600)
            server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = ssl.TLSVersion.TLSv1_3
            context.load_cert_chain(cert, key)
            server.socket = context.wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:

                rust = (ROOT.parent.parent / "host/src/runtime/process.rs").read_text()
                match = re.search(r'const TLS_READINESS_PROBE: &str = r#"([\s\S]*?)"#;', rust)
                self.assertIsNotNone(match, "native TLS readiness implementation missing")
                probe = match.group(1)
                def readiness(hostname: str, authority=cert, port=server.server_port):
                    return subprocess.run([
                        sys.executable, "-I", "-c", probe, str(authority.resolve()),
                        hostname, str(port),
                    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3).returncode
                self.assertEqual(readiness("localhost"), 0)
                self.assertNotEqual(readiness("wrong.invalid"), 0)
                self.assertNotEqual(readiness("localhost", root / "missing.pem"), 0)
                corrupt = root / "corrupt.crt"
                corrupt.write_text("invalid public certificate", encoding="ascii")
                self.assertNotEqual(readiness("localhost", corrupt), 0)
                alias = root / "alias.crt"
                alias.symlink_to(cert)
                # 原始路径必须传入，不能先解析链接替探针掩盖边界。
                self.assertNotEqual(subprocess.run([
                    sys.executable, "-I", "-c", probe, str(alias), "localhost",
                    str(server.server_port),
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3).returncode, 0)
                plain = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
                plain_thread = threading.Thread(target=plain.serve_forever, daemon=True)
                plain_thread.start()
                try:
                    self.assertNotEqual(readiness("localhost", port=plain.server_port), 0)
                finally:
                    plain.shutdown()
                    plain.server_close()
                    plain_thread.join(timeout=3)

                trusted = PROXY.upstream_tls_context([cert])
                self.assertTrue(trusted.check_hostname)
                self.assertEqual(trusted.verify_mode, ssl.CERT_REQUIRED)
                with socket.create_connection(("127.0.0.1", server.server_port), timeout=3) as raw:
                    with trusted.wrap_socket(raw, server_hostname="localhost") as connection:
                        connection.sendall(b"GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
                        self.assertIn(b"200", connection.recv(4096))
                for verification, hostname in [
                    (trusted, "wrong.invalid"), (ssl.create_default_context(), "localhost"),
                ]:
                    with socket.create_connection(("127.0.0.1", server.server_port), timeout=3) as raw:
                        with self.assertRaises(ssl.SSLCertVerificationError):
                            verification.wrap_socket(raw, server_hostname=hostname)

                # 实际穿过员工网关的WSS升级和帧，两个TLS跳数均核验受信证书与主机名。
                class Gateway(PROXY.TuyuProxyServer):
                    def handle_error(self, *_args):
                        pass
                def websocket_exchange(origin: str, authority: ssl.SSLContext, expect_success: bool):
                    gateway = Gateway(("127.0.0.1", 0), [PROXY.Route.parse("/hotel=" + origin)], {}, authority)
                    gateway.socket = context.wrap_socket(gateway.socket, server_side=True)
                    gateway_thread = threading.Thread(target=gateway.serve_forever, daemon=True)
                    gateway_thread.start()
                    try:
                        with socket.create_connection(("127.0.0.1", gateway.server_port), timeout=3) as raw:
                            with trusted.wrap_socket(raw, server_hostname="localhost") as connection:
                                key = "dGhlIHNhbXBsZSBub25jZQ=="
                                connection.sendall((
                                    "GET /hotel/ws HTTP/1.1\r\nHost: localhost\r\n"
                                    "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                                    "Sec-WebSocket-Version: 13\r\nSec-WebSocket-Key: " + key + "\r\n\r\n"
                                ).encode("ascii"))
                                response = bytearray()
                                try:
                                    while b"\r\n\r\n" not in response:
                                        data = connection.recv(4096)
                                        if not data:
                                            break
                                        response.extend(data)
                                        self.assertLessEqual(len(response), 65536)
                                except (ssl.SSLError, ConnectionError, OSError):
                                    if expect_success:
                                        raise
                                if not expect_success:
                                    self.assertNotIn(b" 101 ", response)
                                    return
                                self.assertIn(b" 101 ", response)
                                self.assertIn(b"Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", response)
                                payload, mask = b"verified WSS", b"\x01\x02\x03\x04"
                                frame = bytes([0x81, 0x80 | len(payload)]) + mask + bytes(
                                    value ^ mask[index % 4] for index, value in enumerate(payload)
                                )
                                connection.sendall(frame)
                                expected = bytes([0x81, len(payload)]) + payload
                                echoed = bytearray()
                                while len(echoed) < len(expected):
                                    data = connection.recv(len(expected) - len(echoed))
                                    self.assertTrue(data)
                                    echoed.extend(data)
                                self.assertEqual(bytes(echoed), expected)
                    finally:
                        gateway.shutdown()
                        gateway.server_close()
                        gateway_thread.join(timeout=3)
                websocket_exchange(f"https://localhost:{server.server_port}", trusted, True)
                websocket_exchange(f"https://127.0.0.1:{server.server_port}", trusted, False)
                websocket_exchange(f"https://localhost:{server.server_port}", ssl.create_default_context(), False)
                plain_ws = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
                plain_ws_thread = threading.Thread(target=plain_ws.serve_forever, daemon=True)
                plain_ws_thread.start()
                try:
                    websocket_exchange(f"https://localhost:{plain_ws.server_port}", trusted, False)
                finally:
                    plain_ws.shutdown()
                    plain_ws.server_close()
                    plain_ws_thread.join(timeout=3)

                # 同一端口的明文请求不得得到应用成功响应。
                with socket.create_connection(("127.0.0.1", server.server_port), timeout=3) as raw:
                    raw.sendall(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
                    try:
                        self.assertNotIn(b"200", raw.recv(4096))
                    except (ConnectionError, OSError):
                        pass
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=3)


if __name__ == "__main__":
    unittest.main()
