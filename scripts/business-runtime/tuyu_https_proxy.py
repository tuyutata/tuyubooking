"""TLS-only reverse proxy for loopback TuyuBooking business runtimes.

Module supervisors use this entry point for one loopback worker. The separate,
administrator-enabled employee mode exposes all ready modules through one LAN
HTTPS origin. It never accepts account, database or administrator secrets.
"""

from __future__ import annotations

import argparse
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


if __name__ == "__main__":
    raise SystemExit(main())
