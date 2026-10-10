#!/usr/bin/env python3
"""Expose packaged Frappe assets and the application on one HTTPS origin."""

from __future__ import annotations

import os
from pathlib import Path

from frappe.app import application as frappe_application
from werkzeug.middleware.shared_data import SharedDataMiddleware


assets = Path(os.environ["TUYU_FRAPPE_ASSETS"]).resolve()
if not (assets / "assets.json").is_file():
    raise RuntimeError(f"missing immutable Frappe asset map: {assets / 'assets.json'}")

# Gunicorn already terminates TLS. Static files and dynamic requests therefore
# share the same HTTPS listener and no loopback plaintext gateway is introduced.
application = SharedDataMiddleware(
    frappe_application,
    {"/assets": str(assets)},
    cache=True,
    cache_timeout=31_536_000,
)
