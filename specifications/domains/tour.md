# Tour domain

Initial source: Voyant `v0.104.1`.

The native Tuyu tour domain must preserve catalog, tours, packages, departures,
allotments, pricing, availability, participants, requirements, itineraries,
bookings, supplier operations, proposals, CRM, invoices, taxes, costs,
profitability, distribution, and notifications.

Target ownership:

- Rust owns tour commands, lifecycle rules, idempotency, audit, and APIs.
- Flutter owns tour operations, sales, traveler, and itinerary interfaces.
- PostgreSQL schema `tour` owns authoritative tour data.
- Provider integrations remain replaceable adapters outside domain logic.

Voyant can be retired only after booking lifecycle, finance, migration,
integration-event, and restore parity tests pass.
