use std::collections::BTreeSet;
use tempfile::TempDir;
use time::{Duration, OffsetDateTime};
use tuyubooking_native::core::EntityId;
use tuyubooking_native::storage::{
    ConnectionMode, CoreRepository, IdempotencyClaim, PostgresConnection, PostgresRuntime,
    PostgresRuntimeConfig, SchemaExecutor,
};

mod support;
use support::postgres_bin_dir;

fn now() -> OffsetDateTime {
    OffsetDateTime::from_unix_timestamp(1_800_000_000).unwrap()
}

fn runtime_config(temp: &TempDir) -> PostgresRuntimeConfig {
    PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_core_repo_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55441,
        },
    }
}

#[tokio::test]
async fn core_repository_persists_idempotency_claims() {
    let temp = TempDir::new().unwrap();
    let config = runtime_config(&temp);
    let password = "core-repository-test-password";
    let mut runtime = PostgresRuntime::new(config.clone()).unwrap();
    runtime.initialize(password).unwrap();
    runtime.start().unwrap();
    runtime.ensure_application_database(password).unwrap();

    let connection = PostgresConnection::connect(&config, password)
        .await
        .unwrap();
    SchemaExecutor::apply(&connection.client).await.unwrap();

    let installation_id = EntityId::new();
    connection
        .client
        .execute(
            "INSERT INTO tuyu_core.installation (id, instance_name) VALUES ($1, 'Core Test')",
            &[&installation_id.into_uuid()],
        )
        .await
        .unwrap();

    let first = CoreRepository::claim_idempotency(
        &connection.client,
        installation_id,
        EntityId::new(),
        "core-test",
        "same-command",
        &"a".repeat(64),
        now() + Duration::minutes(10),
    )
    .await
    .unwrap();
    let duplicate = CoreRepository::claim_idempotency(
        &connection.client,
        installation_id,
        EntityId::new(),
        "core-test",
        "same-command",
        &"a".repeat(64),
        now() + Duration::minutes(10),
    )
    .await
    .unwrap();

    assert_eq!(first, IdempotencyClaim::Acquired);
    assert_eq!(duplicate, IdempotencyClaim::InProgress);

    CoreRepository::set_business_modules(
        &connection.client,
        installation_id,
        &BTreeSet::from(["restaurant".to_owned()]),
    )
    .await
    .unwrap();
    let modules =
        CoreRepository::business_module_configuration(&connection.client, installation_id)
            .await
            .unwrap();
    assert!(modules.configured);
    assert_eq!(
        modules.enabled_modules,
        BTreeSet::from(["restaurant".to_owned()])
    );

    drop(connection);
    runtime.stop().unwrap();
}
