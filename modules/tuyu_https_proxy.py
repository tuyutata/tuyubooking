"""TLS-only reverse proxy for loopback TuyuBooking business runtimes.

Module supervisors use this entry point for one loopback worker. The separate,
administrator-enabled employee mode exposes all ready modules through one LAN
HTTPS origin. It never accepts account, database or administrator secrets.
"""

from __future__ import annotations

import argparse
import sys
import hashlib
import html
import http.client
import http.server
import json
import select
import socket
import ssl
import struct
import threading
import uuid
from dataclasses import dataclass, replace
from pathlib import Path
from urllib.parse import urlsplit

from tuyu_runtime_common import ensure_certificate


HOP_BY_HOP_HEADERS = {
    "connection",
    "content-length",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}


@dataclass(frozen=True)
class Route:
    prefix: str
    origin: str
    scheme: str
    hostname: str
    port: int

    @classmethod
    def parse(cls, raw: str) -> "Route":
        # 只允许准确的本机HTTPS来源，不允许认证信息、路径、查询或明文。
        prefix, separator, origin = raw.partition("=")
        try:
            parsed = urlsplit(origin)
            port = parsed.port
            if (
                not separator or not prefix.startswith("/") or prefix == "/"
                or "/" in prefix[1:] or not prefix[1:].replace("_", "").isalnum()
                or parsed.scheme != "https"
                or parsed.hostname not in {"127.0.0.1", "localhost"}
                or port is None or port < 1
                or parsed.username is not None or parsed.password is not None
                or parsed.path not in {"", "/"} or parsed.query or parsed.fragment
            ):
                raise ValueError("invalid route")
        except ValueError:
            raise argparse.ArgumentTypeError(
                "routes must use /module=https://127.0.0.1:port"
            ) from None
        return cls(prefix, origin.rstrip("/"), "https", parsed.hostname, port)


def upstream_tls_context(ca_files: list[Path]) -> ssl.SSLContext:
    # 从显式受信证书建立客户端信任；缺失、损坏或不匹配时禁止降级。
    if not ca_files:
        raise ValueError("trusted upstream certificates are required")
    context = ssl.create_default_context()
    context.minimum_version = ssl.TLSVersion.TLSv1_3
    for certificate in ca_files:
        context.load_verify_locations(cafile=str(certificate))
    return context


def _dns_name(value: str) -> bytes:
    encoded = bytearray()
    for label in value.rstrip(".").split("."):
        raw = label.encode("utf-8")[:63]
        encoded.append(len(raw))
        encoded.extend(raw)
    encoded.append(0)
    return bytes(encoded)


def _dns_record(name: str, kind: int, data: bytes, *, flush: bool = True) -> bytes:
    dns_class = 0x8001 if flush else 1
    return _dns_name(name) + struct.pack("!HHIH", kind, dns_class, 120, len(data)) + data


def _local_ipv4() -> str:
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("192.0.2.1", 9))
        return str(probe.getsockname()[0])
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


class MdnsAdvertiser(threading.Thread):
    """Minimal DNS-SD responder with no runtime package dependency."""

    service = "_tuyubooking._tcp.local"

    def __init__(self, port: int, instance_id: str, merchant_name: str) -> None:
        super().__init__(name="tuyubooking-mdns", daemon=True)
        self.port = port
        self.instance_id = instance_id
        self.merchant_name = merchant_name
        self.stopping = threading.Event()
        self.sock: socket.socket | None = None

    def _packet(self) -> bytes:
        instance = f"TuyuBooking-{self.instance_id[:12]}.{self.service}"
        target = f"{socket.gethostname().split('.')[0]}.local"
        merchant = self.merchant_name.encode("utf-8")[:200]
        txt_values = [
            b"protocol=TUYU/1",
            b"service=TuyuBooking",
            f"instance_id={self.instance_id}".encode("ascii"),
            b"merchant_name=" + merchant,
            b"api_version=1",
        ]
        txt = b"".join(bytes([len(value)]) + value for value in txt_values)
        records = [
            _dns_record(self.service, 12, _dns_name(instance), flush=False),
            _dns_record(instance, 33, struct.pack("!HHH", 0, 0, self.port) + _dns_name(target)),
            _dns_record(instance, 16, txt),
            _dns_record(target, 1, socket.inet_aton(_local_ipv4())),
        ]
        return struct.pack("!HHHHHH", 0, 0x8400, 0, len(records), 0, 0) + b"".join(records)

    def run(self) -> None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        self.sock = sock
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(("", 5353))
            membership = socket.inet_aton("224.0.0.251") + socket.inet_aton("0.0.0.0")
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
            sock.settimeout(1)
            packet = self._packet()
            sock.sendto(packet, ("224.0.0.251", 5353))
            while not self.stopping.is_set():
                try:
                    query, _ = sock.recvfrom(9000)
                except TimeoutError:
                    continue
                if b"_tuyubooking" in query.lower():
                    sock.sendto(packet, ("224.0.0.251", 5353))
        except OSError:
            return
        finally:
            sock.close()

    def close(self) -> None:
        self.stopping.set()
        if self.sock is not None:
            try:
                self.sock.close()
            except OSError:
                pass


class TuyuProxyServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        address: tuple[str, int],
        routes: list[Route],
        metadata: dict[str, str],
        upstream_context: ssl.SSLContext,
    ) -> None:
        super().__init__(address, ProxyHandler)
        self.routes = tuple(
            sorted(routes, key=lambda route: len(route.prefix), reverse=True)
        )
        self.metadata = metadata
        self.upstream_context = upstream_context


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    @property
    def routes(self) -> tuple[Route, ...]:
        return self.server.routes  # type: ignore[attr-defined]

    def _route(self) -> tuple[Route, str] | None:
        request_path = urlsplit(self.path).path
        for route in self.routes:
            if request_path == route.prefix or request_path.startswith(
                f"{route.prefix}/"
            ):
                suffix = self.path[len(route.prefix) :]
                return route, suffix if suffix.startswith("/") else f"/{suffix}"

        # Root-relative assets are associated with their module by Referer.
        referer_path = urlsplit(self.headers.get("referer", "")).path
        for route in self.routes:
            if referer_path == route.prefix or referer_path.startswith(
                f"{route.prefix}/"
            ):
                return route, self.path
        return None

    def _send_gateway_index(self) -> None:
        links = "".join(
            f'<li><a href="{html.escape(route.prefix)}/">'
            f"{html.escape(route.prefix[1:])}</a></li>"
            for route in self.routes
        )
        payload = (
            "<!doctype html><html lang=\"zh\"><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
            "<title>TuyuBooking</title><body><main>"
            "<h1>途遇商家端 / TuyuBooking</h1>"
            "<p>请选择业务子系统 / Select a business subsystem</p>"
            f"<ul>{links}</ul></main></body></html>"
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("content-type", "text/html; charset=utf-8")
        self._security_headers()
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _send_status(self) -> None:
        payload = json.dumps(
            {
                "ok": True,
                **self.server.metadata,  # type: ignore[attr-defined]
                "routes": [route.prefix for route in self.routes],
            },
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self._security_headers()
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _forward(self) -> None:
        if self.path == "/" and len(self.routes) > 1:
            self._send_gateway_index()
            return
        if self.path == "/tuyu/status" and len(self.routes) > 1:
            self._send_status()
            return

        selected = self._route()
        if selected is None:
            self.send_error(404)
            return
        route, upstream_path = selected
        if self.headers.get("upgrade", "").lower() == "websocket":
            self._forward_websocket(route, upstream_path)
            return

        length = int(self.headers.get("content-length", "0"))
        body = self.rfile.read(length) if length else None
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP_HEADERS
        }
        headers["host"] = f"{route.hostname}:{route.port}"
        headers["x-forwarded-proto"] = "https"
        headers["x-forwarded-host"] = self.headers.get("host", "")
        headers["x-forwarded-prefix"] = route.prefix
        # HTTPS请求复用受信CA与主机名校验，绝不创建HTTP连接。
        upstream = http.client.HTTPSConnection(
            route.hostname, route.port, timeout=60,
            context=self.server.upstream_context,  # type: ignore[attr-defined]
        )
        try:
            upstream.request(self.command, upstream_path, body=body, headers=headers)
            response = upstream.getresponse()
            payload = response.read()
            self.send_response(response.status, response.reason)
            for key, value in response.getheaders():
                lower = key.lower()
                if lower in HOP_BY_HOP_HEADERS:
                    continue
                if lower == "location":
                    value = self._rewrite_location(route, value)
                elif lower == "set-cookie" and "path=/" in value.lower():
                    value = value.replace("Path=/", f"Path={route.prefix}/")
                self.send_header(key, value)
            self._security_headers()
            self.send_header("content-length", str(len(payload)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(payload)
        finally:
            upstream.close()

    def _forward_websocket(self, route: Route, upstream_path: str) -> None:
        raw = socket.create_connection((route.hostname, route.port), timeout=60)
        # WebSocket升级也必须先通过同一受信TLS握手。
        try:
            upstream = self.server.upstream_context.wrap_socket(  # type: ignore[attr-defined]
                raw, server_hostname=route.hostname
            )
        except BaseException:
            raw.close()
            raise
        try:
            headers = []
            for key, value in self.headers.items():
                if key.lower() == "host":
                    value = f"{route.hostname}:{route.port}"
                headers.append(f"{key}: {value}\r\n")
            request = (
                f"{self.command} {upstream_path} HTTP/1.1\r\n"
                f"{''.join(headers)}\r\n"
            )
            upstream.sendall(request.encode("latin-1"))
            response = bytearray()
            while b"\r\n\r\n" not in response:
                chunk = upstream.recv(4096)
                if not chunk:
                    raise ConnectionError(
                        "upstream closed during WebSocket handshake"
                    )
                response.extend(chunk)
            self.connection.sendall(response)
            while True:
                readable, _, _ = select.select(
                    [self.connection, upstream], [], [], 60
                )
                if not readable:
                    continue
                for source in readable:
                    payload = source.recv(65536)
                    if not payload:
                        return
                    destination = (
                        upstream if source is self.connection else self.connection
                    )
                    destination.sendall(payload)
        finally:
            upstream.close()

    @staticmethod
    def _rewrite_location(route: Route, value: str) -> str:
        if value.startswith(route.origin):
            return f"{route.prefix}{value[len(route.origin):]}"
        if value.startswith("/") and not value.startswith(route.prefix):
            return f"{route.prefix}{value}"
        return value

    def _security_headers(self) -> None:
        self.send_header("strict-transport-security", "max-age=31536000")
        self.send_header("x-content-type-options", "nosniff")
        self.send_header("referrer-policy", "same-origin")
        self.send_header("x-frame-options", "SAMEORIGIN")

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_HEAD = _forward

    def log_message(self, format: str, *args: object) -> None:
        return


def certificate_fingerprint(certificate: Path) -> str:
    pem = certificate.read_text(encoding="ascii")
    der = ssl.PEM_cert_to_DER_cert(pem)
    return hashlib.sha256(der).hexdigest()


def installation_instance_id(data_dir: Path) -> str:
    path = data_dir / "instance-id"
    if path.is_file():
        value = path.read_text(encoding="ascii").strip()
        if value:
            return value
    value = uuid.uuid4().hex
    data_dir.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="ascii")
    try:
        path.chmod(0o600)
    except OSError:
        pass
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-host", default="127.0.0.1")
    parser.add_argument("--listen-port", required=True, type=int)
    parser.add_argument("--upstream-origin")
    parser.add_argument("--ca", action="append", type=Path, default=[])
    parser.add_argument("--route", action="append", type=Route.parse, default=[])
    parser.add_argument("--certificate")
    parser.add_argument("--private-key")
    parser.add_argument("--runtime-root")
    parser.add_argument("--data-dir")
    parser.add_argument("--hostname")
    parser.add_argument("--merchant-name", default="TuyuBooking Merchant")
    arguments = parser.parse_args()

    routes = list(arguments.route)
    if arguments.upstream_origin:
        if routes:
            parser.error("--upstream-origin cannot be combined with --route")
        routes.append(replace(Route.parse("/root=" + arguments.upstream_origin), prefix=""))
    if not routes or len({route.prefix for route in routes}) != len(routes):
        parser.error("one upstream origin or distinct module routes are required")
    upstream_context = upstream_tls_context(arguments.ca)
    if bool(arguments.certificate) != bool(arguments.private_key):
        parser.error("certificate and private-key paths must both be provided")

    if arguments.certificate and arguments.private_key:
        certificate = Path(arguments.certificate)
        private_key = Path(arguments.private_key)
    elif arguments.runtime_root and arguments.data_dir and arguments.hostname:
        certificate, private_key = ensure_certificate(
            Path(arguments.runtime_root),
            Path(arguments.data_dir),
            arguments.hostname,
        )
    else:
        parser.error("certificate paths or runtime certificate inputs are required")

    fingerprint = certificate_fingerprint(certificate)
    metadata: dict[str, str] = {}
    data_dir = Path(arguments.data_dir) if arguments.data_dir else None
    if data_dir:
        fingerprint_file = data_dir / "tls" / "certificate.sha256"
        fingerprint_file.parent.mkdir(parents=True, exist_ok=True)
        fingerprint_file.write_text(fingerprint, encoding="ascii")
        metadata = {
            "instance_id": installation_instance_id(data_dir),
            "merchant_name": arguments.merchant_name,
            "certificate_sha256": fingerprint,
            "api_version": "1",
        }

    server = TuyuProxyServer(
        (arguments.listen_host, arguments.listen_port), routes, metadata, upstream_context
    )
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_3
    context.load_cert_chain(certificate, private_key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    advertiser = None
    if len(routes) > 1 and metadata:
        advertiser = MdnsAdvertiser(
            arguments.listen_port,
            metadata["instance_id"],
            metadata["merchant_name"],
        )
        advertiser.start()
    try:
        server.serve_forever()
    finally:
        if advertiser is not None:
            advertiser.close()
    return 0


if __name__ == "__main__" and sys.argv[1:] != ["--test"]:
    raise SystemExit(main())

# 正式实现结束；仅明确测试模式加载以下回归。
import os as _test_os
import sys as _test_sys
if (__name__ == "__main__" and _test_sys.argv[1:] == ["--test"]) or _test_os.environ.get("PRODUCT_SCRIPT_TESTS") == "1":
    _test_sys.modules.setdefault(Path(__file__).stem, _test_sys.modules[__name__])

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
    # 测试临时数据归产品当前工作现场；没有注入现场时使用宿主平台test。
    _product_root = Path(__file__).resolve().parents[2]
    _test_target = _product_root / "target"
    _supplied_temp = Path(os.environ.get("TMPDIR", str(_test_target / "test")))
    _test_temp = _supplied_temp
    if _test_temp != _test_target / "test":
        raise ValueError("测试工作根必须是本产品target/test")
    for _ancestor in reversed((_test_temp, *_test_temp.parents)):
        if _ancestor.is_symlink() or (_ancestor.exists() and not _ancestor.is_dir()):
            raise ValueError("测试目录禁止链接或非目录")
        _ancestor.mkdir(exist_ok=True)
    tempfile.tempdir = str(_test_temp)

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
        unittest.main(argv=[_test_sys.argv[0]])
