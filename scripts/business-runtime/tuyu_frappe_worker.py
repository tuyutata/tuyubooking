#!/usr/bin/env python3
"""Run Frappe background jobs from the module's isolated PostgreSQL queue."""

from __future__ import annotations

import argparse
import signal
import time
from pathlib import Path

import frappe

from frappe.utils.tuyu_postgres_backend import run_tuyu_job_once


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bench", required=True, type=Path)
    parser.add_argument("--site", required=True)
    args = parser.parse_args()
    running = True

    def stop(_signum: int, _frame: object) -> None:
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    frappe.init(site=args.site, sites_path=str(args.bench / "sites"))
    frappe.connect()
    try:
        while running:
            processed = False
            for queue in ("short", "default", "long"):
                try:
                    result = run_tuyu_job_once(queue)
                    frappe.db.commit()
                    processed = processed or result is not None
                except Exception:
                    frappe.db.rollback()
                    frappe.log_error(title=f"TuyuBooking PostgreSQL worker: {queue}")
            if not processed:
                time.sleep(0.5)
    finally:
        frappe.destroy()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
