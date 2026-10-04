# Hotel domain

Initial source: Kamra PMS `v2.5.0`.

The native Tuyu hotel domain must preserve room types, rooms, per-date rates,
availability, reservations, check-in/out, housekeeping, folios, taxes, guest
profiles, hotel restaurant service, room posting, inventory, KOT/KDS, audit,
and cancellation/no-show behavior.

Target ownership:

- Rust owns hotel commands, policies, idempotency, audit, and public APIs.
- Flutter owns the unified hotel and hotel-restaurant interface.
- PostgreSQL schema `hotel` owns authoritative hotel data.
- Cross-domain references use stable IDs and APIs, never direct table reads.

Kamra/Frappe can be retired only after functional parity, financial
conservation, inventory, migration, and restore tests pass.
