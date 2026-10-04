use schnorrkel::{ExpansionMode, MiniSecretKey};
use tempfile::TempDir;
use tuyubooking_native::application::{ApplicationBootstrap, ApplicationRuntime};
use tuyubooking_native::core::EntityId;
use tuyubooking_native::storage::{ConnectionMode, PostgresConnection, PostgresRuntimeConfig};

mod support;
use support::{initialize_administrator, postgres_bin_dir};

fn canonical_hex(bytes: &[u8]) -> String {
    format!(
        "0x{}",
        bytes
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>()
    )
}

#[tokio::test]
async fn shared_account_administrator_contains_only_public_identity_and_is_audited() {
    let temp = TempDir::new().unwrap();
    let installation_id = EntityId::new();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_admin_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55445,
        },
    };
    let password = "administrator-test-password";
    let runtime_result = ApplicationRuntime::start(
        config.clone(),
        password,
        ApplicationBootstrap {
            installation_id,
            installation_name: "Identity Test".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Merchant".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await;
    let runtime = runtime_result.unwrap_or_else(|error| {
        let database_diagnostic = std::fs::read_to_string(&config.log_file)
            .unwrap_or_else(|read_error| format!("database log unavailable: {read_error}"));
        panic!(
            "application startup failed: {error:?}\nPostgreSQL diagnostic:\n{database_diagnostic}"
        );
    });
    let pair = MiniSecretKey::from_bytes(&[7_u8; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519);
    let services = runtime.services();
    let session = initialize_administrator(&services, &pair, Some("前台管理员")).await;
    let loaded = services.list_administrators().await.unwrap();
    assert_eq!(loaded.len(), 1);
    assert_eq!(loaded[0].id, session.administrator_id);
    assert_eq!(loaded[0].name.as_deref(), Some("前台管理员"));
    assert_eq!(loaded[0].public_key, canonical_hex(&pair.public.to_bytes()));

    let connection = PostgresConnection::connect(&config, password)
        .await
        .unwrap();
    let initialized_audit: bool = connection
        .client
        .query_one(
            "SELECT EXISTS(
               SELECT 1 FROM tuyu_core.administrator_audit_log
               WHERE action='administrator_initialized'
                 AND target_administrator_id=$1
             )",
            &[&session.administrator_id],
        )
        .await
        .unwrap()
        .get(0);
    assert!(initialized_audit);

    let forbidden_columns: bool = connection
        .client
        .query_one(
            "SELECT EXISTS(
               SELECT 1 FROM information_schema.columns
               WHERE table_schema='tuyu_core'
                 AND table_name='local_system_administrator'
                 AND column_name IN ('private_key', 'mnemonic', 'seed_phrase')
             )",
            &[],
        )
        .await
        .unwrap()
        .get(0);
    assert!(!forbidden_columns);
    drop(connection);
    runtime.stop().unwrap();
}
