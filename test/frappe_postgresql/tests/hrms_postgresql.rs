use std::fs;
use std::path::PathBuf;

#[test]
fn employee_advance_status_patch_uses_explicit_numeric_predicates() {
    let patch = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../upstream/hrms/hrms/patches/post_install/update_employee_advance_status.py");
    let source = fs::read_to_string(patch).expect("HRMS employee advance patch must be readable");

    assert!(source.contains("advance.return_amount != 0"));
    assert!(source.contains("advance.claimed_amount != 0"));
    assert!(!source.contains("(advance.return_amount) &"));
    assert!(!source.contains("advance.claimed_amount & advance.return_amount"));
}
