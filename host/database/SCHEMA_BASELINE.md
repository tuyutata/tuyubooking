# TuyuBooking PostgreSQL schema baseline

## Authority

TuyuBooking installs one local PostgreSQL server and one database named `tuyubooking`. Persistent data is divided into five authoritative Schemas:

| Schema | Owner | Content boundary |
| --- | --- | --- |
| `tuyu_core` | TuyuBooking native core | installation identity, merchant binding, platform administrator and integration metadata |
| `module_kamra` | Kamra PMS | hotel and hotel-restaurant business data |
| `module_ury` | URY | independent restaurant business data |
| `module_voyant` | Voyant | travel-group and activity business data |
| `module_hi_events` | Hi.Events | events and ticketing business data |

Every upstream module owns its final schema, tables, employee accounts and orders inside its Schema. No two modules may share a Schema or application role.

## Prohibited duplicate model

The early Rust hotel, restaurant, activity and ticket domain scaffolds are obsolete. Rust must not create parallel authoritative tables for rooms, menus, tours, events, tickets or upstream orders. Platform code may hold identifiers, signed integration assertions, routing metadata and cross-module event envelopes only.

## Cross-module exchange

Cross-module reads and writes must use a versioned adapter API or an outbox/inbox event contract. Direct joins against another module's private tables are not a supported integration boundary. The initial event name remains `tuyubooking.order.v1` until a separately approved contract revision replaces it.

## Frappe isolation

Kamra uses `module_kamra` and role `tuyu_kamra_app`. URY uses `module_ury` and role `tuyu_ury_app`. They are separate Frappe sites even when the installer provides one shared immutable Frappe distribution.

## Schema initialization rule

The installer applies one final schema baseline for roles, Schemas and platform integration metadata. Every upstream schema initializer must execute with that module's role and `search_path`. Runtime or end-to-end verification cannot be marked complete merely because source and database contracts pass static checks.
