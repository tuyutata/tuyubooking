# TuyuBooking upstream runtime contract

## Current implementation state

Step 2 establishes the independent runtime framework. The four fork sources and PostgreSQL schema contracts are verified. Packaged runtime and end-to-end verification remain pending until the materialized payload is built and each upstream application is exercised on macOS.

The manifest state is intentionally split:

- `source = verified`
- `database = verified`
- `runtime = pending`
- `e2e = pending`

`source_integrated` never means that a module has passed runtime or end-to-end tests.

## Runtime topology

TuyuBooking is one desktop product and one installer. Its native host owns four independent business runtime boundaries:

| Module | Upstream | Runtime | Site or process | PostgreSQL Schema | Role | HTTPS |
| --- | --- | --- | --- | --- | --- | --- |
| Hotel and hotel restaurant | Kamra PMS | Frappe | `hotel.localhost` | `module_kamra` | `tuyu_kamra_app` | `58443` |
| Independent restaurant | URY | Frappe | `restaurant.localhost` | `module_ury` | `tuyu_ury_app` | `58450` |
| Travel group and activity | Voyant | Node.js | independent process group | `module_voyant` | `tuyu_voyant_app` | `58444` |
| Ticketing | Hi.Events | PHP and Node.js | independent process group | `module_hi_events` | `tuyu_hi_events_app` | `58446` |

Kamra and URY may consume the same immutable Frappe/Python/Node payload included in the installer. They must not share a Frappe site, Schema, role, configuration directory, mutable working copy, log, process, employee account, migration history, or business data.

## Shared and isolated resources

Shared:

- One TuyuBooking installer.
- One native lifecycle host.
- One packaged, immutable business-runtime payload.
- One local PostgreSQL server.
- One PostgreSQL database named `tuyubooking`.

Isolated per module:

- Lifecycle state and failure state.
- HTTPS origin and public port.
- Data directory and log file.
- Application process tree.
- PostgreSQL Schema and application role.
- Upstream migrations and employee accounts.
- Orders, rooms, menus, activities, tickets and every other upstream-owned record.

The `tuyu_core` Schema belongs only to TuyuBooking platform identity, merchant-instance and integration metadata. Rust must not recreate or become authoritative for upstream business entities.

## Lifecycle behavior

The native `BusinessRuntimeManager` loads all four module configurations and exposes one snapshot per module. Supported states are `DISABLED`, `PAYLOAD_MISSING`, `INSTALLED`, `STARTING`, `READY`, `DEGRADED`, `FAILED`, `STOPPING` and `STOPPED`.

A missing or failed module does not stop PostgreSQL and does not rewrite another module's state. The Flutter shell may enter a degraded state and open every module whose snapshot contains a ready HTTPS origin. It never derives one module address by adding an offset to another module's port.

## Network boundary

All browser-facing module entry points use HTTPS. Plain HTTP is permitted only as an internal loopback hop between a module-local TLS proxy and its own child process. No upstream business port is intentionally exposed as a public HTTP service.

TuyuBooking runs on the merchant's own host. Cloudflare does not host these four business runtimes.

## Packaging boundary

`scripts/business-runtime/materialize.sh` materializes pinned fork sources and the embedded language runtimes. The runtime supervisor scripts are:

- `tuyu_runtime_common.py`
- `tuyu_frappe_runtime.py`
- `tuyu_voyant_runtime.py`
- `tuyu_hi_events_runtime.py`
- `tuyu_https_proxy.py`

The generic Frappe supervisor receives an explicit app list, install list, site, database role and Schema. It therefore cannot silently merge Kamra and URY into one site.
