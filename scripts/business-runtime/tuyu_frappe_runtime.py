#!/usr/bin/env python3
"""Provision and supervise one isolated Frappe business site."""

from __future__ import annotations

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


def runtime_environment(
    config: dict[str, Any], runtime_root: Path, bench: Path
) -> dict[str, str]:
    environment = os.environ.copy()
    # Resolve the generated bench links before exposing applications to Python.
    # Frappe assembles one PostgreSQL bootstrap command through a shell; keeping
    # its immutable source path out of "Application Support" avoids splitting
    # framework_postgres.sql at the directory's space without patching upstream.
    app_paths = [
        str(path.resolve()) for path in (bench / "apps").iterdir() if path.is_dir()
    ]
    environment["PYTHONPATH"] = os.pathsep.join([str(runtime_root), *app_paths])
    environment["PATH"] = os.pathsep.join(
        [
            str(runtime_root / "node" / "bin"),
            str(runtime_root / "python" / "bin"),
            environment.get("PATH", ""),
        ]
    )
    environment["PGHOST"] = str(config["database_host"])
    environment["PGPORT"] = str(config["database_port"])
    environment["PGOPTIONS"] = (
        f"-c search_path={config['database_schema']},public"
    )
    environment["TUYU_POSTGRES_ONLY"] = "1"
    environment["PYTHONHOME"] = str(runtime_root / "python")
    environment["PYTHONNOUSERSITE"] = "1"
    environment["TUYU_FRAPPE_ASSETS"] = str(
        (runtime_root / "bench" / "sites" / "assets").resolve()
    )
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    environment["NODE_PATH"] = str(runtime_root / "node" / "lib" / "node_modules")
    return environment


def bench_command(runtime_root: Path, bench: Path, *arguments: str) -> list[str]:
    return [
        str(executable(runtime_root / "python" / "bin" / "python3")),
        "-m",
        "frappe.utils.bench_helper",
        "frappe",
        *arguments,
    ]


def run_sensitive_provisioning_command(
    command: list[str], *, cwd: Path, environment: dict[str, str]
) -> None:
    """Run Frappe provisioning without copying credential arguments into logs."""
    try:
        subprocess.run(
            command,
            cwd=cwd,
            env=environment,
            stdin=subprocess.DEVNULL,
            check=True,
        )
    except subprocess.CalledProcessError as error:
        raise RuntimeError(
            f"Frappe site provisioning failed with exit status {error.returncode}"
        ) from None


def replace_generated_link(path: Path, target: Path) -> None:
    """Point a generated runtime path at one immutable packaged directory."""
    if not target.is_dir():
        raise FileNotFoundError(f"missing immutable Frappe runtime path: {target}")
    if path.is_symlink():
        if path.resolve() == target.resolve():
            return
        path.unlink()
    elif path.exists():
        # Older development builds copied these generated directories. They do
        # not contain site data and are safely replaced during the upgrade.
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()
    path.symlink_to(target, target_is_directory=True)


def prepare_bench(config: dict[str, Any], runtime_root: Path, data_dir: Path) -> Path:
    source = runtime_root / "bench"
    source_apps = source / "apps"
    source_assets = source / "sites" / "assets"
    if not (source_assets / "assets.json").is_file():
        raise FileNotFoundError(
            f"missing immutable Frappe asset map: {source_assets / 'assets.json'}"
        )
    bench = data_dir / "bench"
    bench.mkdir(parents=True, exist_ok=True)
    replace_generated_link(bench / "apps", source_apps)
    sites = bench / "sites"
    sites.mkdir(parents=True, exist_ok=True)
    replace_generated_link(sites / "assets", source_assets)
    # Frappe opens database.log during new-site before it creates the bench log tree.
    (bench / "logs").mkdir(parents=True, exist_ok=True)
    apps = [str(app) for app in config["bench_apps"]]
    (sites / "apps.txt").write_text("\n".join(apps) + "\n", encoding="utf-8")
    common = {
        "db_type": "postgres",
        "db_port": int(config["database_port"]),
        "db_name": config["database_name"],
        "db_user": config["database_role"],
        "db_schema": config["database_schema"],
        "default_site": config["site_name"],
        "serve_default_site": True,
        "tuyu_single_database": True,
        "tuyu_postgres_backend": True,
        "socketio_port": 9000,
    }
    database_host = str(config["database_host"])
    if os.path.isabs(database_host):
        common["db_socket"] = database_host
    else:
        common["db_host"] = database_host
    (sites / "common_site_config.json").write_text(
        json.dumps(common, indent=2), encoding="utf-8"
    )
    return bench


def load_database_password(data_dir: Path, site: Path) -> str:
    """Keep the module role password stable across host-runtime restarts."""
    site_config = site / "site_config.json"
    if site_config.is_file():
        existing = json.loads(site_config.read_text(encoding="utf-8")).get(
            "db_password"
        )
        if existing:
            return str(existing)
    path = data_dir / "secrets.json"
    if path.is_file():
        existing = json.loads(path.read_text(encoding="utf-8")).get(
            "database_password"
        )
        if existing:
            return str(existing)
    password = secrets.token_urlsafe(36)
    write_private_json(path, {"database_password": password})
    return password


def provision_database(
    config: dict[str, Any],
    runtime_root: Path,
    password: str,
    *,
    reset_schema: bool,
) -> None:
    """Create one app role and one owned Schema in the shared database."""
    psql = executable(runtime_root.parent / "postgresql" / "bin" / "psql")
    role = str(config["database_role"])
    schema = str(config["database_schema"])
    database = str(config["database_name"])
    for identifier in (role, schema, database):
        if not identifier.replace("_", "").isalnum():
            raise ValueError("TuyuBooking database identifiers are invalid")
    escaped_password = password.replace("'", "''")
    schema_statement = (
        f'DROP SCHEMA IF EXISTS "{schema}" CASCADE; '
        f'CREATE SCHEMA "{schema}" AUTHORIZATION "{role}"; '
        if reset_schema
        else f'CREATE SCHEMA IF NOT EXISTS "{schema}" AUTHORIZATION "{role}"; '
    )
    statement = (
        "DO $tuyu$ BEGIN "
        f"IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{role}') THEN "
        f"EXECUTE 'CREATE ROLE \"{role}\" LOGIN'; "
        "END IF; END $tuyu$; "
        f'ALTER ROLE "{role}" WITH LOGIN PASSWORD \'{escaped_password}\'; '
        + schema_statement
        + f'ALTER SCHEMA "{schema}" OWNER TO "{role}"; '
        f'GRANT CONNECT ON DATABASE "{database}" TO "{role}"; '
        f'GRANT USAGE, CREATE ON SCHEMA "{schema}" TO "{role}"; '
        f'ALTER ROLE "{role}" IN DATABASE "{database}" '
        f'SET search_path TO "{schema}", pg_catalog;'
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
            database,
            "--set",
            "ON_ERROR_STOP=1",
            "--command",
            statement,
        ],
        env={**os.environ, "PGPASSWORD": str(config["database_superuser_password"])},
        check=True,
    )


def provision_site(config: dict[str, Any], runtime_root: Path, bench: Path) -> None:
    site_name = str(config["site_name"])
    sites = bench / "sites"
    site = sites / site_name
    new_site_marker = site / ".tuyu-new-site-complete"
    password = load_database_password(Path(config["data_dir"]), site)
    provision_database(
        config,
        runtime_root,
        password,
        reset_schema=not new_site_marker.is_file(),
    )
    environment = runtime_environment(config, runtime_root, bench)
    if not new_site_marker.is_file():
        database_host = str(config["database_host"])
        endpoint_arguments = (
            ["--db-socket", database_host]
            if os.path.isabs(database_host)
            else ["--db-host", database_host]
        )
        command = bench_command(
            runtime_root,
            bench,
            "new-site",
            site_name,
            "--db-type",
            "postgres",
            *endpoint_arguments,
            "--db-port",
            str(config["database_port"]),
            "--db-name",
            str(config["database_name"]),
            "--db-user",
            str(config["database_role"]),
            "--db-password",
            password,
            "--db-root-username",
            str(config["database_superuser"]),
            "--db-root-password",
            str(config["database_superuser_password"]),
            "--admin-password",
            str(config["administrator_password"]),
            "--no-setup-db",
        )
        if site.exists():
            command.append("--force")
        run_sensitive_provisioning_command(
            command,
            cwd=sites,
            environment=environment,
        )
        new_site_marker.touch()
    for app in config["install_apps"]:
        installed = subprocess.run(
            bench_command(runtime_root, bench, "--site", site_name, "list-apps"),
            cwd=sites,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        if app not in installed:
            subprocess.run(
                bench_command(runtime_root, bench, "--site", site_name, "install-app", str(app)),
                cwd=sites,
                env=environment,
                check=True,
            )
    subprocess.run(
        bench_command(runtime_root, bench, "--site", site_name, "migrate"),
        cwd=sites,
        env=environment,
        check=True,
    )


def main() -> int:
    config = main_config(sys.argv)
    runtime_root = Path(config["runtime_dir"])
    data_dir = Path(config["data_dir"])
    data_dir.mkdir(parents=True, exist_ok=True)
    # Frappe resolves some process loggers relative to the site-data parent.
    (data_dir / "logs").mkdir(parents=True, exist_ok=True)
    bench = prepare_bench(config, runtime_root, data_dir)
    provision_site(config, runtime_root, bench)
    sites = bench / "sites"
    (sites / str(config["site_name"]) / "logs").mkdir(parents=True, exist_ok=True)
    certificate, private_key = ensure_certificate(
        runtime_root, data_dir, str(config["public_hostname"])
    )
    environment = runtime_environment(config, runtime_root, bench)
    environment["FRAPPE_SITE_NAME_HEADER"] = str(config["site_name"])
    python = str(executable(runtime_root / "python" / "bin" / "python3"))
    commands = [
        (
            [
                python,
                "-m",
                "gunicorn",
                "--bind",
                f"127.0.0.1:{int(config['https_port'])}",
                "--certfile",
                str(certificate),
                "--keyfile",
                str(private_key),
                "tuyu_frappe_wsgi:application",
            ],
            environment,
            sites,
        ),
        (
            [
                python,
                str(runtime_root / "tuyu_frappe_worker.py"),
                "--bench",
                str(bench),
                "--site",
                str(config["site_name"]),
            ],
            environment,
            sites,
        ),
    ]
    return supervise(commands)


if __name__ == "__main__":
    raise SystemExit(main())
