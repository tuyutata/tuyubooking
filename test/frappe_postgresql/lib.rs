#[cfg(test)]
mod tests {
    use std::{fs, path::PathBuf};

    fn root() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .and_then(|path| path.parent())
            .expect("test crate must remain under test/frappe_postgresql")
            .to_path_buf()
    }

    #[test]
    fn framework_uses_one_postgresql_database_without_redis_runtime() {
        let manifest = fs::read_to_string(root().join("modules/frappe.framework.toml"))
            .expect("read framework manifest");
        assert!(manifest.contains("database_name = \"tuyubooking\""));
        assert!(manifest.contains("redis_service = false"));
        assert!(manifest.contains("tuyu_single_database = true"));
        assert!(manifest.contains("tuyu_postgres_backend = true"));

        let schema = fs::read_to_string(root().join("modules/frappe.schema.sql"))
            .expect("read framework schema");
        assert!(schema.contains("CREATE SCHEMA IF NOT EXISTS tuyu_core"));
        assert!(schema.contains("CREATE SCHEMA IF NOT EXISTS module_kamra"));
        assert!(!schema.to_uppercase().contains("CREATE DATABASE"));
        assert!(!schema.to_lowercase().contains("mariadb"));
        assert!(!schema.to_lowercase().contains("mysql"));
    }

    #[test]
    fn frappe_profile_routes_runtime_primitives_to_postgresql() {
        let frappe = root().join("upstream/frappe/frappe");
        let init = fs::read_to_string(frappe.join("__init__.py")).expect("read frappe init");
        let setup = fs::read_to_string(frappe.join("database/postgres/setup_db.py"))
            .expect("read postgres setup");
        let backend = fs::read_to_string(frappe.join("utils/tuyu_postgres_backend.py"))
            .expect("read tuyu backend");
        assert!(init.contains("TuyuPostgresCache"));
        assert!(setup.contains("setup_tuyu_schema"));
        assert!(setup.contains("tuyu_single_database"));
        assert!(backend.contains("FOR UPDATE SKIP LOCKED"));
        assert!(backend.contains("pg_notify"));
        assert!(backend.contains("pg_try_advisory_lock"));
    }

    #[test]
    fn kamra_has_postgresql_sql_and_chinese_defaults() {
        let kamra = root().join("upstream/kamra/kamra");
        let install = fs::read_to_string(kamra.join("install.py")).expect("read Kamra installer");
        let hooks = fs::read_to_string(kamra.join("hooks.py")).expect("read Kamra hooks");
        assert!(install.contains("set_tuyu_defaults"));
        assert!(install.contains("\"zh\""));
        assert!(hooks.contains("required_apps = []"));

        for relative in [
            "folio.py",
            "reports.py",
            "patches/v28/backfill_property_kind.py",
            "patches/v29/backfill_booking_mode.py",
        ] {
            let sql = fs::read_to_string(kamra.join(relative)).expect("read Kamra SQL source");
            assert!(!sql.to_uppercase().contains("IFNULL("), "MySQL IFNULL remains in {relative}");
        }
    }

    #[test]
    fn packaged_kamra_runtime_is_offline_https_and_single_database() {
        let runtime = fs::read_to_string(
            root().join("scripts/business-runtime/tuyu_frappe_runtime.py"),
        )
        .expect("read Kamra runtime supervisor");
        let lock = fs::read_to_string(
            root().join("scripts/business-runtime/runtime.lock.json"),
        )
        .expect("read business runtime lock");
        assert!(runtime.contains("--certfile"));
        assert!(runtime.contains("--keyfile"));
        assert!(runtime.contains("database_name"));
        assert!(runtime.contains("database_role"));
        assert!(runtime.contains("database_schema"));
        assert!(!runtime.contains("http://"));
        assert!(lock.contains("\"database_name\": \"tuyubooking\""));
        assert!(lock.contains("\"network_install_allowed\": false"));
        assert!(lock.contains("\"redis_service\": false"));
    }

    #[test]
    fn step4_acceptance_uses_real_kamra_and_ury_business_models() {
        let acceptance = fs::read_to_string(
            root().join("test/frappe_postgresql/business_acceptance.py"),
        )
        .expect("read Frappe business acceptance");
        assert!(acceptance.contains("kamra.scripts.test_booking_flow"));
        assert!(acceptance.contains("\"POS Order\""));
        assert!(acceptance.contains("TestP0P1EndToEndFlow"));
        assert!(acceptance.contains("sync_order"));
        assert!(acceptance.contains("\"POS Invoice\""));
        assert!(!acceptance.contains("CREATE TABLE"));
    }
}
