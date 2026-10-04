use std::fs;
use std::path::PathBuf;

#[test]
fn ury_end_to_end_fixture_bootstraps_its_company() {
    let source = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../upstream/ury/ury/ury_pos/test_e2e_p0_p1_flow.py"),
    )
    .expect("URY P0/P1 test must be readable");

    let ensure = source
        .find("self.company = self._ensure_company()")
        .expect("setUp must ensure the ERPNext company");
    let restaurant = source
        .find("self.restaurant = self._make_restaurant()")
        .expect("setUp must create the restaurant");
    assert!(ensure < restaurant);
    assert!(source.contains("install(\"India\")"));
    assert!(source.contains("\"price_list_name\": \"Standard Selling\""));
    assert!(source.contains("\"company_name\": TEST_COMPANY"));
    assert!(source.contains("\"default_currency\": \"INR\""));
    assert!(source.contains("def _ensure_fiscal_year(self, company):"));
    assert!(source.contains("raise_on_missing=False"));
    assert!(source.contains("date(current.year, 12, 31)"));

    let acceptance = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("business_acceptance.py"),
    )
    .expect("Frappe business acceptance must be readable");
    assert!(acceptance.contains("bootstrap._ensure_company()"));
    assert!(acceptance.contains("frappe.db.commit()"));
    assert!(acceptance.contains(
        "frappe.db.set_single_value(\"POS Settings\", \"invoice_type\", \"POS Invoice\")"
    ));
    assert!(acceptance.contains(
        "frappe.db.set_single_value(\"POS Settings\", \"invoice_type\", original_invoice_type)"
    ));

    let hooks = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../upstream/ury/ury/hooks.py"),
    )
    .expect("URY hooks must be readable");
    assert!(hooks.contains(
        "after_migrate = \"ury.patches.v2_0.default_permissions.ensure_permissions\""
    ));

    let permissions = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../upstream/ury/ury/patches/v2_0/default_permissions.py"),
    )
    .expect("URY permission patch must be readable");
    assert!(permissions.contains("def ensure_permissions():"));
    assert!(permissions.contains("\"Custom DocPerm\""));

    let closing = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(
            "../../upstream/ury/ury/ury/doctype/sub_pos_closing/sub_pos_closing.py",
        ),
    )
    .expect("URY sub-POS closing source must be readable");
    assert!(closing.contains("status != %s"));
    assert!(closing.contains("(user, pos_profile, \"Consolidated\")"));
    assert!(!closing.contains("status != \"Consolidated\""));
}
