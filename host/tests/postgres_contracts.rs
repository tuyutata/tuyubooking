use tempfile::TempDir;
use tuyubooking_native::storage::{
    ConnectionMode, PostgresConnection, PostgresRuntime, PostgresRuntimeConfig, SchemaExecutor,
    StorageError,
};

mod support;
use support::postgres_bin_dir;

fn runtime_config(temp: &TempDir) -> PostgresRuntimeConfig {
    let bin_dir = postgres_bin_dir();
    let root = temp.path();

    PostgresRuntimeConfig {
        bin_dir,
        installation_dir: root.join("read-only-installation"),
        data_dir: root.join("application-data/postgresql"),
        log_file: root.join("logs/postgresql.log"),
        username: "tuyu_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: root.join("socket"),
            port: 55439,
        },
    }
}

#[test]
fn runtime_configuration_disables_external_listening() {
    let temp = TempDir::new().unwrap();
    let config = runtime_config(&temp);
    let options = config.server_options();

    assert!(options.contains("listen_addresses=''"));
    assert!(!options.contains("0.0.0.0"));
    assert!(!options.contains("listen_addresses=*"));
    assert!(options.contains("shared_memory_type=mmap"));
    assert!(options.contains("dynamic_shared_memory_type=mmap"));
    assert_eq!(
        config.share_dir(),
        config.bin_dir.parent().unwrap().join("share/postgresql")
    );
    assert!(!config.data_dir.starts_with(&config.installation_dir));
}

#[test]
fn runtime_rejects_data_inside_installation() {
    let temp = TempDir::new().unwrap();
    let mut config = runtime_config(&temp);
    config.data_dir = config.installation_dir.join("data");

    assert!(matches!(
        PostgresRuntime::new(config),
        Err(StorageError::DataDirectoryInsideInstallation)
    ));
}

#[tokio::test]
async fn real_postgresql_applies_schema_once_and_rolls_back_failures() {
    let temp = TempDir::new().unwrap();
    let config = runtime_config(&temp);
    let password = "tuyu-test-only-password";
    let mut runtime = PostgresRuntime::new(config.clone()).unwrap();

    runtime.initialize(password).unwrap();
    runtime.start().unwrap();
    runtime.ensure_application_database(password).unwrap();

    let connection = PostgresConnection::connect(&config, password)
        .await
        .unwrap();
    let first_applied = SchemaExecutor::apply(&connection.client).await.unwrap();
    let second_applied = SchemaExecutor::apply(&connection.client).await.unwrap();

    assert!(first_applied);
    assert!(!second_applied);

    #[cfg(target_os = "macos")]
    {
        // 真正加载两种保留的过程语言；PL/Perl必须读取当前运行包的strict模块。
        connection.client.batch_execute(
            "CREATE EXTENSION plperl; CREATE EXTENSION pltcl;
             CREATE FUNCTION tuyu_core.controlled_perl() RETURNS integer AS $$
                 use strict; return 42;
             $$ LANGUAGE plperl;
             CREATE FUNCTION tuyu_core.controlled_tcl() RETURNS integer AS $$
                 return 7
             $$ LANGUAGE pltcl;",
        ).await.unwrap();
        let values = connection.client.query_one(
            "SELECT tuyu_core.controlled_perl(), tuyu_core.controlled_tcl()", &[],
        ).await.unwrap();
        assert_eq!(values.get::<_, i32>(0), 42);
        assert_eq!(values.get::<_, i32>(1), 7);
    }


    let schema_count: i64 = connection
        .client
        .query_one(
            "SELECT count(*) FROM information_schema.schemata WHERE schema_name = ANY($1)",
            &[&vec!["tuyu_core"]],
        )
        .await
        .unwrap()
        .get(0);
    assert_eq!(schema_count, 1);

    let table_count: i64 = connection
        .client
        .query_one(
            "SELECT count(*) FROM information_schema.tables WHERE table_schema = ANY($1)",
            &[&vec!["tuyu_core"]],
        )
        .await
        .unwrap()
        .get(0);
    // 初始核心模式包含 business_module，四个业务模块的启停状态由这一张正式表持久化。
    assert_eq!(table_count, 17);

    let failed = SchemaExecutor::execute_transactional_probe(
        &connection.client,
        "BEGIN; CREATE TABLE tuyu_core.rollback_probe (id integer); SELECT * FROM missing_table; COMMIT;",
    )
    .await;
    assert!(failed.is_err());

    let rollback_probe_exists: bool = connection
        .client
        .query_one(
            "SELECT to_regclass('tuyu_core.rollback_probe') IS NOT NULL",
            &[],
        )
        .await
        .unwrap()
        .get(0);
    assert!(!rollback_probe_exists);

    connection
        .client
        .execute(
            "UPDATE tuyu_core.schema_state SET checksum_sha256 = repeat('0', 64) WHERE schema_name = 'tuyu_core'",
            &[],
        )
        .await
        .unwrap();

    assert!(matches!(
        SchemaExecutor::apply(&connection.client).await,
        Err(StorageError::SchemaChecksumMismatch { .. })
    ));

    drop(connection);
    runtime.stop().unwrap();
}


#[cfg(target_os = "macos")]
#[test]
fn missing_packaged_perl_core_fails_before_writing_initialization_password() {
    let temp = TempDir::new().unwrap();
    let root = temp.path().join("runtime");
    std::fs::create_dir_all(root.join("bin")).unwrap();
    std::fs::create_dir_all(root.join("share/postgresql")).unwrap();
    for name in ["postgres", "initdb", "pg_ctl", "psql"] {
        std::fs::write(root.join("bin").join(name), b"fixture").unwrap();
    }
    for name in ["postgres.bki", "postgresql.conf.sample"] {
        std::fs::write(root.join("share/postgresql").join(name), b"fixture").unwrap();
    }
    let mut config = runtime_config(&temp);
    config.bin_dir = root.join("bin");
    let password_parent = config.data_dir.parent().unwrap().to_path_buf();
    let runtime = PostgresRuntime::new(config).unwrap();
    assert!(matches!(runtime.initialize("synthetic-only"), Err(StorageError::MissingExecutable(_))));
    assert!(std::fs::read_dir(password_parent).unwrap().all(|entry| {
        !entry.unwrap().file_name().to_string_lossy().starts_with(".tuyu-initdb-password-")
    }));
}
