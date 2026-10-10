#!/usr/bin/env python3
"""Provision and supervise the isolated Hi.Events ticket runtime."""

from __future__ import annotations

import base64
import json
import os
import secrets
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from tuyu_runtime_common import (
    ensure_certificate,
    executable,
    main_config,
    supervise,
    write_private_json,
)


def load_secrets(data_dir: Path) -> dict[str, str]:
    path = data_dir / "secrets.json"
    if path.is_file():
        return json.loads(path.read_text(encoding="utf-8"))
    values = {
        "database_password": secrets.token_urlsafe(36),
        "app_key": "base64:" + base64.b64encode(secrets.token_bytes(32)).decode("ascii"),
    }
    write_private_json(path, values)
    return values


def provision_role(config: dict[str, Any], runtime_root: Path, password: str) -> None:
    psql = runtime_root.parent / "postgresql" / "bin" / "psql"
    if not psql.is_file():
        return
    role = str(config["database_role"])
    escaped = password.replace("'", "''")
    schema = str(config["database_schema"])
    statement = (
        "DO $tuyu$ BEGIN "
        f"IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{role}') THEN "
        f"EXECUTE 'CREATE ROLE \"{role}\" LOGIN'; "
        "END IF; END $tuyu$; "
        f'ALTER ROLE "{role}" WITH LOGIN PASSWORD \'{escaped}\'; '
        f'CREATE SCHEMA IF NOT EXISTS "{schema}" AUTHORIZATION "{role}"; '
        f'ALTER SCHEMA "{schema}" OWNER TO "{role}"; '
        f'GRANT USAGE, CREATE ON SCHEMA "{schema}" TO "{role}"; '
        f'CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA "{schema}"; '
        f'ALTER ROLE "{role}" SET search_path TO "{schema}", public;'
    )
    subprocess.run(
        [
            str(psql),
            "--host",
            str(config["database_host"]),
            "--port",
            str(config["database_port"]),
            "--username",
            str(config["database_superuser"]),
            "--dbname",
            str(config["database_name"]),
            "--set",
            "ON_ERROR_STOP=1",
            "--command",
            statement,
        ],
        env={**os.environ, "PGPASSWORD": str(config["database_superuser_password"])},
        check=True,
    )


def application_environment(
    config: dict[str, Any], runtime_root: Path, password: str
) -> dict[str, str]:
    public_port = int(config["https_port"])
    environment = os.environ.copy()
    environment.update(
        {
            "APP_ENV": "production",
            "APP_DEBUG": "false",
            "APP_KEY": load_secrets(Path(config["data_dir"]))["app_key"],
            "APP_URL": f"https://{config['public_hostname']}:{public_port}",
            "DB_CONNECTION": "pgsql",
            "DB_HOST": str(config["database_host"]),
            "DB_PORT": str(config["database_port"]),
            "DB_DATABASE": str(config["database_name"]),
            "DB_USERNAME": str(config["database_role"]),
            "DB_PASSWORD": password,
            "DB_SEARCH_PATH": f"{config['database_schema']},public",
            "LOG_CHANNEL": "stderr",
            "QUEUE_CONNECTION": "database",
            "SESSION_DRIVER": "database",
            "CACHE_STORE": "database",
            "VITE_API_URL": f"https://{config['public_hostname']}:{public_port}/api",
            "NODE_ENV": "production",
        }
    )
    environment["PATH"] = os.pathsep.join(
        [
            str(runtime_root / "php" / "bin"),
            str(runtime_root / "node" / "bin"),
            environment.get("PATH", ""),
        ]
    )
    return environment


def write_service_configs(
    runtime_root: Path, data_dir: Path, public_port: int, certificate: Path,
    private_key: Path, backend: Path | None = None
) -> tuple[Path, Path]:
    (data_dir / "logs").mkdir(parents=True, exist_ok=True)
    fpm_port = public_port + 1001
    gateway_port = public_port + 1002
    backend = backend or runtime_root / "hi_events" / "backend"
    fpm_config = data_dir / "php-fpm.conf"
    fpm_config.write_text(
        "\n".join(
            [
                "[global]",
                "daemonize = no",
                f'error_log = "{data_dir / "php-fpm.log"}"',
                "[www]",
                f"listen = 127.0.0.1:{fpm_port}",
                "pm = dynamic",
                "pm.max_children = 8",
                "pm.start_servers = 2",
                "pm.min_spare_servers = 1",
                "pm.max_spare_servers = 3",
                "clear_env = no",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    nginx_config = data_dir / "nginx.conf"
    nginx_config.write_text(
        f"""events {{ worker_connections 256; }}
http {{
  access_log "{data_dir / 'nginx-access.log'}";
  error_log "{data_dir / 'nginx-error.log'}";
  server {{
    listen 127.0.0.1:{gateway_port} ssl;
    ssl_certificate "{certificate}";
    ssl_certificate_key "{private_key}";
    ssl_protocols TLSv1.2 TLSv1.3;
    root "{backend / 'public'}";
    index index.php;
    location /api {{ try_files $uri $uri/ /index.php?$query_string; }}
    location ~ \\.php$ {{
      include "{runtime_root / 'nginx' / 'conf' / 'fastcgi_params'}";
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      fastcgi_pass 127.0.0.1:{fpm_port};
    }}
    location / {{
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-Proto https;
      # SSR连接也校验本机服务证书，不允许内部明文或关闭校验。
      proxy_ssl_verify on;
      proxy_ssl_trusted_certificate "{certificate}";
      proxy_ssl_server_name on;
      proxy_ssl_name 127.0.0.1;
      proxy_pass https://127.0.0.1:{public_port + 1003};
    }}
  }}
}}
""",
        encoding="utf-8",
    )
    return fpm_config, nginx_config


def main() -> int:
    config = main_config(sys.argv)
    runtime_root = Path(config["runtime_dir"])
    data_dir = Path(config["data_dir"])
    data_dir.mkdir(parents=True, exist_ok=True)
    secret_values = load_secrets(data_dir)
    provision_role(config, runtime_root, secret_values["database_password"])
    environment = application_environment(
        config, runtime_root, secret_values["database_password"]
    )
    source_backend = runtime_root / "hi_events" / "backend"
    backend = data_dir / "backend"
    if not backend.is_dir():
        shutil.copytree(source_backend, backend, symlinks=True)
    php = str(executable(runtime_root / "php" / "bin" / "php"))
    subprocess.run(
        [php, "artisan", "migrate", "--force"],
        cwd=backend,
        env=environment,
        check=True,
    )
    public_port = int(config["https_port"])
    certificate, private_key = ensure_certificate(
        runtime_root, data_dir, str(config["public_hostname"])
    )
    # 生成配置前取得完整TLS身份，三个HTTPS进程使用同一安装证书。
    fpm_config, nginx_config = write_service_configs(
        runtime_root, data_dir, public_port, certificate, private_key, backend
    )
    php_server = (
        [
            str(executable(runtime_root / "php" / "bin" / "php-cgi")),
            "-b",
            f"127.0.0.1:{public_port + 1001}",
        ]
        if os.name == "nt"
        else [
            str(runtime_root / "php" / "sbin" / "php-fpm"),
            "--nodaemonize",
            "--fpm-config",
            str(fpm_config),
        ]
    )
    commands = [
        (
            php_server,
            environment,
            backend,
        ),
        (
            [
                str(executable(runtime_root / "nginx" / "sbin" / "nginx")),
                "-c",
                str(nginx_config),
                "-p",
                str(data_dir),
                "-g",
                "daemon off;",
            ],
            environment,
            data_dir,
        ),
        (
            [
                str(executable(runtime_root / "node" / "bin" / "node")),
                str(runtime_root / "hi_events" / "frontend" / "server.js"),
            ],
            {
                **environment,
                "NODE_ENV": "production",
                "NODE_PORT": str(public_port + 1003),
                "HOST": "127.0.0.1",
                "VITE_API_URL_SERVER": f"https://127.0.0.1:{public_port + 1002}/api",
                "NODE_EXTRA_CA_CERTS": str(certificate),
                "TUYU_TLS_CERT_FILE": str(certificate),
                "TUYU_TLS_KEY_FILE": str(private_key),
                "VITE_API_URL_CLIENT": (
                    f"https://{config['public_hostname']}:{public_port}/api"
                ),
                "VITE_FRONTEND_URL": (
                    f"https://{config['public_hostname']}:{public_port}"
                ),
            },
            runtime_root / "hi_events" / "frontend",
        ),
        (
            [
                str(executable(runtime_root / "python" / "bin" / "python3")),
                str(runtime_root / "tuyu_https_proxy.py"),
                "--listen-port",
                str(public_port),
                "--upstream-origin",
                f"https://127.0.0.1:{public_port + 1002}",
                "--ca",
                str(certificate),
                "--certificate",
                str(certificate),
                "--private-key",
                str(private_key),
            ],
            environment,
            runtime_root,
        ),
        (
            [php, "artisan", "queue:work", "--sleep=1", "--tries=3"],
            environment,
            backend,
        ),
    ]
    return supervise(commands)


if __name__ == "__main__":
    raise SystemExit(main())
