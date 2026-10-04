use std::fs;
use std::path::PathBuf;

#[test]
fn kamra_sql_uses_postgresql_date_arithmetic() {
    let kamra = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../upstream/kamra/kamra");
    let sql_sources = [
        "pricing.py",
        "api.py",
        "inventory.py",
        "kamra/doctype/room_block/room_block.py",
        "kamra/doctype/reservation/reservation.py",
    ];

    for relative in sql_sources {
        let source = fs::read_to_string(kamra.join(relative))
            .unwrap_or_else(|error| panic!("failed to read {relative}: {error}"));
        assert!(!source.contains("DATE_ADD("), "{relative} contains MariaDB DATE_ADD");
        assert!(!source.contains("DATE_SUB("), "{relative} contains MariaDB DATE_SUB");
    }
}

#[test]
fn booking_flow_removes_security_deposits_before_reservations() {
    let source = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../upstream/kamra/kamra/scripts/test_booking_flow.py"),
    )
    .expect("Kamra booking flow must be readable");

    let deposit = source
        .find("frappe.delete_doc(\"Security Deposit\"")
        .expect("booking flow must remove linked security deposits");
    let reservation = source
        .find("frappe.delete_doc(\"Reservation\"")
        .expect("booking flow must remove reservations");
    assert!(deposit < reservation);
    assert!(source.contains("cancellation_preview(res_villa.name)"));
    assert!(source.contains("fee + expected_credit"));
}
