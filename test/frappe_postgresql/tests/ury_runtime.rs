use std::{fs, path::PathBuf};

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

#[test]
fn kamra_and_ury_use_one_distribution_but_independent_sites() {
    let root = root();
    let runtime = fs::read_to_string(
        root.join("scripts/business-runtime/tuyu_frappe_runtime.py"),
    )
    .unwrap();
    assert!(runtime.contains("bench_apps"));
    assert!(runtime.contains("install_apps"));
    assert!(runtime.contains("database_role"));
    assert!(runtime.contains("database_schema"));
    assert!(runtime.contains("tuyu_frappe_wsgi:application"));
    assert!(runtime.contains("TUYU_FRAPPE_ASSETS"));

    let manifest = fs::read_to_string(root.join("modules/ury.module.toml")).unwrap();
    assert!(manifest.contains("schema = \"module_ury\""));
    assert!(manifest.contains("role = \"tuyu_ury_app\""));
    assert!(!manifest.contains("shared_frappe_site"));

    let lock = fs::read_to_string(
        root.join("scripts/business-runtime/runtime.lock.json"),
    )
    .unwrap();
    assert!(lock.contains("hotel.localhost"));
    assert!(lock.contains("restaurant.localhost"));
    assert!(lock.contains("58443"));
    assert!(lock.contains("58450"));
}

#[test]
fn erpnext_support_page_uses_postgresql_strict_grouping() {
    let source = fs::read_to_string(
        root().join("upstream/erpnext/erpnext/www/support/index.py"),
    )
    .unwrap();
    assert!(source.contains(
        "GROUP BY t1.name, t1.title, t1.content, t1.route, t1.category"
    ));
    assert!(!source.contains("GROUP BY route"));
}

#[test]
fn postgresql_queue_keeps_scheduler_arguments_out_of_business_payloads() {
    let source = fs::read_to_string(
        root().join("upstream/frappe/frappe/utils/tuyu_postgres_backend.py"),
    )
    .unwrap();
    assert!(source.contains("kwargs.pop(\"now\", False)"));
    assert!(source.contains("kwargs.pop(\"enqueue_after_commit\", False)"));
    assert!(source.contains("if now or not is_async:"));
    assert!(source.contains("frappe.db.after_commit.add(insert_job)"));
    assert!(source.contains("normalize_tuyu_job_id"));
    assert!(source.contains("uuid.uuid5(TUYU_JOB_NAMESPACE"));
}
