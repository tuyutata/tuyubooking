use std::{fs, path::PathBuf};

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

#[test]
fn bridge_is_https_one_time_scoped_and_audited() {
    let schema = fs::read_to_string(root().join("host/database/tuyu_core.sql")).unwrap();
    let bridge = fs::read_to_string(
        root().join("upstream/kamra/kamra/tuyu_admin_bridge.py"),
    )
    .unwrap();
    let page = fs::read_to_string(root().join("upstream/kamra/kamra/www/tuyu_admin.html"))
        .unwrap();
    let hooks = fs::read_to_string(root().join("upstream/kamra/kamra/hooks.py")).unwrap();

    assert!(schema.contains("CREATE TABLE IF NOT EXISTS tuyu_core.administrator_assertion"));
    assert!(schema.contains("upstream_administrator_session"));
    assert!(schema.contains("administrator_bridge_audit"));
    assert!(bridge.contains("SET consumed_at = CURRENT_TIMESTAMP"));
    assert!(bridge.contains("consumed_at IS NULL"));
    assert!(bridge.contains("revoked_at IS NULL"));
    assert!(bridge.contains("expires_at > CURRENT_TIMESTAMP"));
    assert!(bridge.contains("REPLAY_EXPIRED_REVOKED_OR_FOREIGN"));
    assert!(bridge.contains("System Manager"));
    assert!(hooks.contains("validate_active_bridge_session"));
    assert!(page.contains("location.hash"));
    assert!(!page.contains("http://"));
    assert!(!bridge.contains("private_key"));
}
