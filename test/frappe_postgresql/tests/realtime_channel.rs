use std::fs;
use std::path::PathBuf;

#[test]
fn realtime_channels_obey_postgresql_identifier_limit() {
    let source = fs::read_to_string(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../upstream/frappe/frappe/utils/tuyu_postgres_backend.py"),
    )
    .expect("Tuyu PostgreSQL backend must be readable");

    assert!(source.contains("def tuyu_notification_channel"));
    assert!(source.contains("len(encoded) <= 63"));
    assert!(source.contains("hashlib.sha256(encoded).hexdigest()[:56]"));
    assert!(source.contains("tuyu_notification_channel(channel)"));
}
