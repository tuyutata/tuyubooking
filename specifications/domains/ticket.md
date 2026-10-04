# Ticket domain

Initial source: Hi.Events commit `048243e2a99a65c8e77fc6f3cb44de158169855e`.

The native Tuyu ticket domain must preserve organizers, events, recurring and
multi-date schedules, ticket products, capacities, promotions, checkout
questions, orders, attendees, PDF/QR tickets, check-in lists, scan logs,
refunds, invoices, webhooks, messaging, reporting, and offline payments.

Target ownership:

- Rust owns event, inventory, order, attendee, check-in, audit, and public APIs.
- Flutter owns organizer, sales, attendee, scanner, and reporting interfaces.
- PostgreSQL schema `ticket` owns authoritative ticketing data.
- Attribution and AGPL duties remain until legally changed by a valid license.

Hi.Events can be retired only after capacity, order, ticket generation,
check-in, refund, migration, webhook, and restore parity tests pass.
