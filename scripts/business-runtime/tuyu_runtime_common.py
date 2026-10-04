#!/usr/bin/env python3
"""Shared, business-neutral helpers for independent TuyuBooking runtimes."""

from __future__ import annotations

import json
import os
import signal
import ssl
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


def read_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_private_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        temporary.chmod(0o600)
    except OSError:
        pass
    temporary.replace(path)


def executable(path: Path) -> Path:
    if os.name == "nt" and path.suffix.lower() != ".exe":
        candidate = path.with_suffix(".exe")
        if candidate.is_file():
            return candidate
        if path.as_posix().endswith("python/bin/python3"):
            embedded_python = path.parents[1] / "python.exe"
            if embedded_python.is_file():
                return embedded_python
    return path


def ensure_certificate(runtime_root: Path, data_dir: Path, hostname: str) -> tuple[Path, Path]:
    tls_dir = data_dir / "tls"
    certificate = tls_dir / "localhost.crt"
    private_key = tls_dir / "localhost.key"
    # 局域网安装身份不可因只缺一半文件而被静默替换。
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?", hostname):
        raise ValueError("invalid TLS hostname")
    if certificate.exists() or private_key.exists():
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certificate, private_key)
        return certificate, private_key

    tls_dir.mkdir(parents=True, exist_ok=True)
    openssl = executable(runtime_root / "openssl" / "bin" / "openssl")
    command = [
        str(openssl),
        "req",
        "-x509",
        "-newkey",
        "rsa:2048",
        "-sha256",
        "-nodes",
        "-days",
        "825",
        "-subj",
        f"/CN={hostname}",
        "-addext",
        f"subjectAltName=DNS:{hostname},DNS:localhost,IP:127.0.0.1",
        "-addext",
        "extendedKeyUsage=serverAuth",
        "-keyout",
        str(private_key),
        "-out",
        str(certificate),
    ]
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        private_key.chmod(0o600)
    except OSError:
        pass
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certificate, private_key)
    return certificate, private_key


def supervise(
    commands: list[tuple[list[str], dict[str, str], Path]],
) -> int:
    """Run one module's children as a single failure boundary."""
    children: list[subprocess.Popen[bytes]] = []
    stopping = False

    def stop_children(_signum: int | None = None, _frame: object | None = None) -> None:
        nonlocal stopping
        stopping = True
        for child in children:
            if child.poll() is None:
                child.terminate()

    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, stop_children)

    try:
        for command, environment, cwd in commands:
            children.append(
                subprocess.Popen(
                    command,
                    cwd=cwd,
                    env=environment,
                    stdin=subprocess.DEVNULL,
                )
            )
        while not stopping:
            for child in children:
                code = child.poll()
                if code is not None:
                    stop_children()
                    return code or 1
            time.sleep(0.25)
        return 0
    finally:
        stop_children()
        deadline = time.monotonic() + 10
        for child in children:
            if child.poll() is None:
                try:
                    child.wait(max(0.1, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    child.kill()
        for child in children:
            if child.poll() is None:
                child.wait()


def main_config(argv: list[str]) -> dict[str, Any]:
    if len(argv) != 3 or argv[1] != "--config":
        raise SystemExit("usage: runtime.py --config <supervisor.json>")
    return read_config(Path(argv[2]))
