# Restaurant domain

Initial source: URY commit `4d2c559d3219cc61687cae6586af8560993ea70c`.

The native Tuyu restaurant domain must preserve menus, modifiers, tables,
areas, dine-in, takeaway, delivery, POS, KOT/KDS, preparation states, split and
merged bills, printing, stock consumption, cashier close, analytics, and
branch-aware permissions.

Target ownership:

- Rust owns restaurant commands, order state, idempotency, audit, and APIs.
- Flutter owns POS, table, kitchen, cashier, and reporting interfaces.
- PostgreSQL schema `restaurant` owns authoritative restaurant data.
- Employee roles remain domain business roles and are not Tuyu identity roles.

URY/ERPNext/Frappe can be retired only after order, accounting, stock,
printing, permission, migration, and restore parity tests pass.
