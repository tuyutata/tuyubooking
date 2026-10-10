#!/usr/bin/env python3
"""Supervise the merchant-local Voyant DMC runtime behind an HTTPS endpoint."""

from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

from tuyu_runtime_common import (
    ensure_certificate,
    executable,
    main_config,
    supervise,
    write_private_json,
)


IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def safe_identifier(value: str) -> str:
    if not IDENTIFIER.fullmatch(value):
        raise ValueError(f"invalid PostgreSQL identifier: {value!r}")
    return value


def load_secrets(data_dir: Path) -> dict[str, str]:
    path = data_dir / "secrets.json"
    if path.is_file():
        values = json.loads(path.read_text(encoding="utf-8"))
    else:
        values = {
            "database_password": secrets.token_urlsafe(36),
            "session_secret": secrets.token_urlsafe(48),
        }
        write_private_json(path, values)
    for key in ("database_password", "session_secret"):
        if not isinstance(values.get(key), str) or not values[key]:
            raise ValueError(f"Voyant secret {key} is missing")
    return values


def database_url(config: dict[str, object], password: str) -> str:
    role = quote(str(config["database_role"]), safe="")
    encoded_password = quote(password, safe="")
    host = str(config["database_host"])
    port = int(config["database_port"])
    database = quote(str(config["database_name"]), safe="")
    return f"postgresql://{role}:{encoded_password}@{host}:{port}/{database}"


def psql_command(
    config: dict[str, object], runtime_root: Path, user: str
) -> list[str]:
    psql = executable(runtime_root.parent / "postgresql" / "bin" / "psql")
    return [
        str(psql),
        "--no-psqlrc",
        "--set",
        "ON_ERROR_STOP=1",
        "--host",
        str(config["database_host"]),
        "--port",
        str(config["database_port"]),
        "--username",
        user,
        "--dbname",
        str(config["database_name"]),
    ]


def run_psql(
    config: dict[str, object],
    runtime_root: Path,
    user: str,
    password: str,
    *,
    sql: str | None = None,
    arguments: list[str] | None = None,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["PGPASSWORD"] = password
    command = psql_command(config, runtime_root, user)
    command.extend(arguments or [])
    return subprocess.run(
        command,
        input=sql,
        text=True,
        env=environment,
        check=True,
        capture_output=capture_output,
    )


def provision_database_role(
    config: dict[str, object], runtime_root: Path, password: str
) -> None:
    role = safe_identifier(str(config["database_role"]))
    schema = safe_identifier(str(config["database_schema"]))
    database = safe_identifier(str(config["database_name"]))
    escaped_password = password.replace("'", "''")
    sql = f'''
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{role}') THEN
    CREATE ROLE "{role}" LOGIN;
  END IF;
END
$$;
ALTER ROLE "{role}" PASSWORD '{escaped_password}';
CREATE SCHEMA IF NOT EXISTS "{schema}" AUTHORIZATION "{role}";
ALTER SCHEMA "{schema}" OWNER TO "{role}";
GRANT CONNECT ON DATABASE "{database}" TO "{role}";
GRANT USAGE, CREATE ON SCHEMA "{schema}" TO "{role}";
ALTER ROLE "{role}" IN DATABASE "{database}"
  SET search_path TO "{schema}", pg_catalog;
'''
    run_psql(
        config,
        runtime_root,
        str(config["database_superuser"]),
        str(config["database_superuser_password"]),
        sql=sql,
    )


def rewrite_migration(source: Path, destination: Path, schema: str) -> None:
    schema = safe_identifier(schema)
    sql = source.read_text(encoding="utf-8")
    sql = sql.replace('"public".', f'"{schema}".')
    sql = sql.replace("n.nspname = 'public'", f"n.nspname = '{schema}'")
    sql = sql.replace("table_schema = 'public'", f"table_schema = '{schema}'")
    destination.write_text(sql, encoding="utf-8")


def apply_migrations(
    config: dict[str, object], runtime_root: Path, data_dir: Path, password: str
) -> int:
    role = safe_identifier(str(config["database_role"]))
    schema = safe_identifier(str(config["database_schema"]))
    migrations = runtime_root / "voyant" / "operator" / "migrations"
    work = data_dir / "migrations"
    work.mkdir(parents=True, exist_ok=True)
    run_psql(
        config,
        runtime_root,
        role,
        password,
        sql=(
            f'CREATE TABLE IF NOT EXISTS "{schema}".__tuyu_migrations ('
            "migration_name text PRIMARY KEY, sha256 text NOT NULL, "
            "applied_at timestamptz NOT NULL DEFAULT now());"
        ),
    )
    applied = 0
    for source in sorted(migrations.glob("*.sql")):
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        name = source.name
        query = (
            f"SELECT sha256 FROM \"{schema}\".__tuyu_migrations "
            f"WHERE migration_name = '{name}';"
        )
        existing = run_psql(
            config,
            runtime_root,
            role,
            password,
            arguments=["--tuples-only", "--no-align", "--command", query],
            capture_output=True,
        ).stdout.strip()
        if existing:
            if existing != digest:
                raise RuntimeError(f"Voyant migration changed after apply: {name}")
            continue
        rewritten = work / name
        rewrite_migration(source, rewritten, schema)
        run_psql(
            config,
            runtime_root,
            role,
            password,
            arguments=["--single-transaction", "--file", str(rewritten)],
        )
        run_psql(
            config,
            runtime_root,
            role,
            password,
            sql=(
                f"INSERT INTO \"{schema}\".__tuyu_migrations"
                "(migration_name, sha256) "
                f"VALUES ('{name}', '{digest}');"
            ),
        )
        applied += 1
    return applied


def main() -> int:
    config = main_config(sys.argv)
    runtime_root = Path(str(config["runtime_dir"]))
    data_dir = Path(str(config["data_dir"]))
    data_dir.mkdir(parents=True, exist_ok=True)
    values = load_secrets(data_dir)
    password = values["database_password"]
    provision_database_role(config, runtime_root, password)
    apply_migrations(config, runtime_root, data_dir, password)

    public_port = int(config["https_port"])
    upstream_port = public_port + 1001
    certificate, private_key = ensure_certificate(
        runtime_root, data_dir, str(config["public_hostname"])
    )
    voyant = runtime_root / "voyant" / "operator"
    node = str(executable(runtime_root / "node" / "bin" / "node"))
    environment = os.environ.copy()
    environment["PATH"] = os.pathsep.join(
        [
            str(runtime_root / "node" / "bin"),
            str(voyant / "node_modules" / ".bin"),
            environment.get("PATH", ""),
        ]
    )
    environment["NODE_ENV"] = "production"
    origin = f"https://{config['public_hostname']}:{public_port}"
    environment.update(
        {
            "HOST": "127.0.0.1",
            "PORT": str(upstream_port),
            "NITRO_HOST": "127.0.0.1",
            "NITRO_PORT": str(upstream_port),
            "DATABASE_URL": database_url(config, password),
            "DB_ADAPTER": "node",
            "APP_URL": origin,
            "DASH_BASE_URL": origin,
            "API_BASE_URL": f"{origin}/api",
            "SESSION_CLAIMS_SECRET": values["session_secret"],
            "VOYANT_ADMIN_AUTH_MODE": "local",
        }
    )
    server = [
        node,
        str(runtime_root / "tuyu_voyant_https.mjs"),
        str(voyant / ".output" / "server" / "index.mjs"),
        str(certificate),
        str(private_key),
        str(upstream_port),
    ]
    proxy = [
        str(executable(runtime_root / "python" / "bin" / "python3")),
        str(runtime_root / "tuyu_https_proxy.py"),
        "--listen-port",
        str(public_port),
        "--upstream-origin",
        f"https://127.0.0.1:{upstream_port}",
        "--ca",
        str(certificate),
        "--certificate",
        str(certificate),
        "--private-key",
        str(private_key),
    ]
    return supervise(
        [
            (server, environment, voyant),
            (proxy, environment, runtime_root),
        ]
    )


if __name__ == "__main__":
    raise SystemExit(main())
