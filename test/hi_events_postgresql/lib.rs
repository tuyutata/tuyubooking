#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::{Path, PathBuf};

    fn root() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap()
    }

    fn read(path: &str) -> String {
        fs::read_to_string(root().join(path)).unwrap()
    }

    #[test]
    fn hi_events_is_local_offline_and_postgresql_only() {
        let manifest = read("modules/hi_events.module.toml");
        let database = read("upstream/hi_events/backend/config/database.php");
        let runtime = read("scripts/business-runtime/tuyu_hi_events_runtime.py");
        assert!(manifest.contains("integration_status = \"source_integrated\""));
        assert!(manifest.contains("database = \"tuyubooking\""));
        assert!(manifest.contains("schema = \"module_hi_events\""));
        assert!(database.contains("'default' => 'pgsql'"));
        assert!(!database.contains("'mysql' =>"));
        assert!(!database.contains("'sqlite' =>"));
        assert!(runtime.contains("PHP 8.4") || read("scripts/business-runtime/materialize.sh").contains("PHP 8\\.4"));
        assert!(runtime.contains("php-fpm"));
        assert!(runtime.contains("php-cgi"));
        assert!(runtime.contains("os.name == \"nt\""));
        assert!(runtime.contains("127.0.0.1"));
        assert!(!runtime.contains("docker"));
    }

    #[test]
    fn administrator_bridge_is_one_time_fragment_only_and_audited() {
        let bridge = read("upstream/hi_events/backend/app/Services/Infrastructure/Tuyu/TuyuAdministratorBridge.php");
        let middleware = read("upstream/hi_events/backend/app/Http/Middleware/ValidateTuyuAdministratorSession.php");
        let frontend = read("upstream/hi_events/frontend/server.js");
        assert!(bridge.contains("hash('sha256', $assertionToken)"));
        assert!(bridge.contains("consumed_at IS NULL"));
        assert!(bridge.contains("expires_at > CURRENT_TIMESTAMP"));
        assert!(bridge.contains("local_session_expires_at > CURRENT_TIMESTAMP"));
        assert!(bridge.contains("upstream_administrator_session"));
        assert!(middleware.contains("hi_events_administrator_write"));
        assert!(frontend.contains("location.hash.slice(1)"));
        assert!(frontend.contains("history.replaceState"));
        assert!(!frontend.contains("?assertion="));
    }

    #[test]
    fn chinese_and_english_are_the_only_locales() {
        let locales = read("upstream/hi_events/frontend/src/locales.ts");
        let lingui = read("upstream/hi_events/frontend/lingui.config.ts");
        let app = read("upstream/hi_events/backend/config/app.php");
        assert!(locales.contains("[\"zh-cn\", \"en\"]"));
        assert!(locales.contains("return \"zh-cn\""));
        assert!(lingui.contains("locales: [\"zh-cn\", \"en\"]"));
        assert!(app.contains("env('APP_LOCALE', 'zh-cn')"));
    }

    #[test]
    fn legacy_rust_tour_business_scaffold_is_absent() {
        for path in [
            "host/src/tour",
            "host/src/application/tour_service.rs",
            "host/src/storage/tour_repository.rs",
            "host/database/tour",
        ] {
            assert!(!root().join(path).exists(), "legacy path remains: {path}");
        }
        let schema = read("host/src/storage/schema.rs");
        let storage = read("host/src/storage/mod.rs");
        assert!(!schema.contains("TOUR_SQL"));
        assert!(!storage.contains("TourRepository"));
    }

    #[test]
    fn desktop_and_runtime_expose_ticket_https_port() {
        let desktop = read("app/lib/desktop/workspace/merchant_home_page.dart");
        let native = read("host/src/runtime/ticket.rs");
        let materialize = read("scripts/business-runtime/materialize.sh");
        assert!(desktop.contains("moduleOrigin(module.id)"));
        assert!(native.contains("tuyu_hi_events_runtime.py"));
        assert!(native.contains("entry.server.js"));
        assert!(materialize.contains("hi_events/backend/vendor/autoload.php"));
        assert!(materialize.contains("tuyu_hi_events_runtime.py"));
    }

    #[test]
    fn step4_acceptance_uses_real_event_ticket_and_public_order_services() {
        let acceptance = read("test/hi_events_postgresql/BusinessFlowTest.php");
        assert!(acceptance.contains("CreateOrganizerHandler"));
        assert!(acceptance.contains("CreateEventHandler"));
        assert!(acceptance.contains("CreateProductHandler"));
        assert!(acceptance.contains("ProductPriceType::FREE"));
        assert!(acceptance.contains("/public/events/"));
        assert!(acceptance.contains("OrderStatus::COMPLETED"));
        assert!(acceptance.contains("Attendee::query()"));
        assert!(!acceptance.contains("CREATE TABLE"));
    }
}
