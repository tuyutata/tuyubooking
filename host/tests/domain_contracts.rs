use rust_decimal::Decimal;
use std::path::Path;
use std::str::FromStr;
use tuyubooking_native::core::{CurrencyCode, DomainError, Money, Version};
use tuyubooking_native::storage::{sha256_hex, CORE_SCHEMA};

#[test]
fn money_uses_fixed_point_values() {
    let currency = CurrencyCode::new("GMB").expect("valid currency");
    let left = Money::parse("0.1", currency.clone()).expect("valid decimal");
    let right = Money::parse("0.2", currency).expect("valid decimal");
    let total = left.checked_add(&right).expect("same currency");

    assert_eq!(total.amount(), Decimal::from_str("0.3").unwrap());
}

#[test]
fn different_currencies_cannot_be_added() {
    let gmb = Money::parse("1", CurrencyCode::new("GMB").unwrap()).unwrap();
    let cny = Money::parse("1", CurrencyCode::new("CNY").unwrap()).unwrap();

    assert_eq!(gmb.checked_add(&cny), Err(DomainError::CurrencyMismatch));
}

#[test]
fn optimistic_lock_version_increments() {
    assert_eq!(Version::INITIAL.next().unwrap().value(), 2);
}

#[test]
fn embedded_schema_has_fixed_identity_and_hash() {
    assert_eq!(CORE_SCHEMA.name, "tuyu_core");
    assert_eq!(CORE_SCHEMA.schema, "tuyu_core");
    assert_eq!(sha256_hex(CORE_SCHEMA.sql), CORE_SCHEMA.sha256);
    assert_eq!(CORE_SCHEMA.sha256.len(), 64);
    assert!(CORE_SCHEMA.sql.starts_with("-- TuyuBooking"));
    assert!(!CORE_SCHEMA.sql.contains("BEGIN;"));
    assert!(!CORE_SCHEMA.sql.contains("COMMIT;"));
}

#[test]
fn upstream_owned_business_scaffolding_is_absent() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let forbidden = [
        "host/src/hotel",
        "host/src/restaurant",
        "host/src/ticket",
        "host/src/core/capacity.rs",
        "host/src/application/hotel_service.rs",
        "host/src/application/restaurant_service.rs",
        "host/src/application/ticket_service.rs",
        "host/src/storage/hotel_repository.rs",
        "host/src/storage/restaurant_repository.rs",
        "host/src/storage/ticket_repository.rs",
        "host/src/storage/hold_placement.rs",
        "host/database/hotel",
        "host/database/restaurant",
        "host/database/tour",
        "host/database/ticket",
    ];

    for relative in forbidden {
        assert!(
            !root.join(relative).exists(),
            "legacy business scaffold must stay absent: {relative}"
        );
    }
}
