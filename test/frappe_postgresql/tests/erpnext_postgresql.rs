use std::fs;
use std::path::PathBuf;

#[test]
fn pos_closing_combines_dates_with_the_database_mapper() {
    let source = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(
            "../../upstream/erpnext/erpnext/accounts/doctype/pos_closing_entry/pos_closing_entry.py",
        ),
    )
    .expect("ERPNext POS closing source must be readable");

    assert!(source.contains("fn.CombineDatetime("));
    assert!(!source.contains("fn.Timestamp(InvoiceDocType.posting_date"));
}
