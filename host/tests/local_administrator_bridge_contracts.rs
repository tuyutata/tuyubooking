use std::{fs, path::PathBuf};

fn repository_file(relative: &str) -> String {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("native directory has a repository parent")
        .join(relative);
    fs::read_to_string(&path).unwrap_or_else(|error| panic!("{}: {error}", path.display()))
}

#[test]
fn initial_schema_uses_only_local_administrator_bridge_identity() {
    let sql = repository_file("host/database/tuyu_core.sql");
    let bridge = sql
        .split("CREATE TABLE IF NOT EXISTS tuyu_core.administrator_assertion")
        .nth(1)
        .expect("administrator bridge schema");
    assert!(bridge.contains("administrator_public_key_fingerprint"));
    assert!(bridge.contains("REFERENCES tuyu_core.local_system_administrator"));
    assert!(!bridge.contains("merchant_instance_id"));
    assert!(!bridge.contains("tuyu_id"));
    assert!(!bridge.contains("signer_id"));
    assert!(!bridge.contains("device_id"));
    assert!(!bridge.contains("merchant_role"));
}

#[test]
fn every_upstream_bridge_requires_an_active_local_administrator() {
    let bridges = [
        "upstream/kamra/kamra/tuyu_admin_bridge.py",
        "upstream/voyant/templates/operator/src/api/tuyu-admin-core.ts",
        "upstream/hi_events/backend/app/Services/Infrastructure/Tuyu/TuyuAdministratorBridge.php",
        "upstream/hi_events/backend/app/Http/Middleware/ValidateTuyuAdministratorSession.php",
    ];
    for bridge in bridges {
        let source = repository_file(bridge);
        assert!(source.contains("local_system_administrator"), "{bridge}");
        assert!(
            source.contains("administrator.status = 'active'"),
            "{bridge}"
        );
        assert!(
            source.contains("administrator_public_key_fingerprint"),
            "{bridge}"
        );
        assert!(!source.contains("merchant_instance_id"), "{bridge}");
        assert!(!source.contains("tuyu_id"), "{bridge}");
        assert!(!source.contains("signer_id"), "{bridge}");
        assert!(!source.contains("device_id"), "{bridge}");
        assert!(!source.contains("merchant_role"), "{bridge}");
    }
}
