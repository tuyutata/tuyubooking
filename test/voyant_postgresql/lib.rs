#[cfg(test)]
mod tests {
    use serde_json::Value;
    use std::{fs, path::{Path, PathBuf}};

    fn root() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent().and_then(Path::parent).unwrap().to_path_buf()
    }

    fn read(path: &str) -> String {
        fs::read_to_string(root().join(path)).unwrap_or_else(|error| panic!("{path}: {error}"))
    }

    #[test]
    fn voyant_is_a_local_node_source_integrated() {
        let manifest: toml::Value =
            toml::from_str(&read("modules/voyant.module.toml")).unwrap();
        assert_eq!(manifest["integration_status"].as_str(), Some("source_integrated"));
        assert_eq!(manifest["runtime"]["family"].as_str(), Some("node-tanstack-start"));
        assert_eq!(manifest["database"]["database"].as_str(), Some("tuyubooking"));
        assert_eq!(manifest["database"]["schema"].as_str(), Some("module_voyant"));
        assert_eq!(manifest["database"]["role"].as_str(), Some("tuyu_voyant_app"));

        let package: Value = serde_json::from_str(&read("upstream/voyant/templates/operator/package.json")).unwrap();
        assert_eq!(package["scripts"]["build:tuyu"], "node scripts/build-tuyu.mjs");
        assert!(read("upstream/voyant/templates/operator/scripts/build-tuyu.mjs")
            .contains("TUYU_BOOKING_RUNTIME = \"1\""));
        assert_eq!(package["scripts"]["start:tuyu"], "node .output/server/index.mjs");
        assert!(package["devDependencies"]["nitro"].as_str().is_some());
    }

    #[test]
    fn voyant_is_schema_isolated_and_has_no_runtime_installer() {
        let migrate = read("upstream/voyant/templates/operator/scripts/migrate.ts");
        assert!(migrate.contains("module_voyant"));
        assert!(migrate.contains("search_path"));
        assert!(migrate.contains("replaceAll"));
        assert!(migrate.contains("/tuyubooking"));
        let materialize = read("scripts/business-runtime/materialize.sh");
        assert!(materialize.contains("grep -q '^v24\\.'"));
        assert!(materialize.contains("voyant/operator/.output/server/index.mjs"));
        assert!(materialize.contains("voyant/operator/.output/migration/migrate.mjs"));
        assert!(!materialize.contains("voyant/dist/server/index.js"));
        for forbidden in ["pnpm install", "npm install", "curl ", "wget ", "docker", "podman"] {
            assert!(!materialize.contains(forbidden), "runtime installer contains {forbidden}");
        }
    }

    #[test]
    fn administrator_bridge_is_one_time_https_and_audited() {
        let core = read("upstream/voyant/templates/operator/src/api/tuyu-admin-core.ts");
        assert!(core.contains("consumed_at IS NULL"));
        assert!(core.contains("revoked_at IS NULL"));
        assert!(core.contains("identity_session_expires_at > CURRENT_TIMESTAMP"));
        assert!(core.contains("upstream_administrator_session"));
        assert!(core.contains("ADMINISTRATOR_REQUEST"));
        let server = read("upstream/voyant/templates/operator/src/server.ts");
        assert!(server.contains("location.hash.slice(1)"));
        assert!(server.contains("history.replaceState"));
        assert!(server.contains("content-security-policy"));
        assert!(!server.contains("http://"));
    }

    #[test]
    fn chinese_is_default_and_english_is_supported() {
        let locale = read("upstream/voyant/packages/admin/src/providers/locale.tsx");
        assert!(locale.contains("[\"zh-CN\", \"en\"]"));
        assert!(locale.contains("DEFAULT_ADMIN_LOCALE = \"zh-CN\""));
        let nav = read("upstream/voyant/packages/i18n/src/admin/operator-nav.ts");
        let auth = read("upstream/voyant/packages/i18n/src/admin/auth.ts");
        assert!(nav.contains("旅行团"));
        assert!(auth.contains("旅行社员工账户"));
    }

    #[test]
    fn step4_acceptance_uses_voyant_product_slot_and_booking_routes() {
        let runner = read("test/voyant_postgresql/business_acceptance.mjs");
        assert!(runner.contains("TEST_DATABASE_URL"));
        assert!(runner.contains("products/tests/integration/routes.test.ts"));
        assert!(runner.contains("availability/tests/integration/routes.test.ts"));
        assert!(runner.contains("bookings/tests/integration/routes.test.ts"));
        assert!(runner.contains("reserves a slot and creates on-hold allocations"));
        assert!(runner.contains(
            "allows scoped non-staff booking status mutations through the capability guard"
        ));
        for forbidden in ["curl ", "wget ", "docker", "podman"] {
            assert!(!runner.contains(forbidden), "acceptance runner contains {forbidden}");
        }
    }
}
