use tempfile::TempDir;
use tuyubooking_native::storage::{ConnectionMode, PostgresRuntime, PostgresRuntimeConfig};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

mod support;
use support::postgres_bin_dir;

#[test]
fn existing_database_restores_process_scoped_runtime_directories() {
    let temp = TempDir::new().unwrap();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data/postgresql"),
        log_file: temp.path().join("logs/postgresql.log"),
        username: "tuyubooking".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55432,
        },
    };
    std::fs::create_dir_all(&config.data_dir).unwrap();
    std::fs::write(config.data_dir.join("PG_VERSION"), "17\n").unwrap();
    std::fs::write(
        config.data_dir.join("pg_hba.conf"),
        "local all all scram-sha-256\n",
    )
    .unwrap();

    PostgresRuntime::new(config.clone())
        .unwrap()
        .initialize("not-used-by-private-unix-socket")
        .unwrap();

    let socket = match &config.connection {
        ConnectionMode::UnixSocket { directory, .. } => directory,
        ConnectionMode::LoopbackTcp { .. } => unreachable!(),
    };
    assert!(socket.is_dir());
    assert!(config.log_file.parent().unwrap().is_dir());
    #[cfg(unix)]
    assert_eq!(
        std::fs::metadata(socket).unwrap().permissions().mode() & 0o777,
        0o700
    );
    #[cfg(unix)]
    assert!(std::fs::read_to_string(config.data_dir.join("pg_hba.conf"))
        .unwrap()
        .starts_with("# TuyuBooking private Unix socket\nlocal all all trust\n"));
}
