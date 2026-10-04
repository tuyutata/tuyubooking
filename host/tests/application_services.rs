use serde_json::json;
use tempfile::TempDir;
use time::OffsetDateTime;
use tuyubooking_native::application::{
    AppLocale, ApplicationBootstrap, ApplicationRuntime, CommandCoordinator, CommandDisposition,
    CommandEnvelope, ErrorCode, Subsystem, VerifiedLocalAdministrator,
};
use tuyubooking_native::core::{CommandKey, EntityId};
use tuyubooking_native::storage::{ConnectionMode, PostgresRuntimeConfig};

mod support;
use support::postgres_bin_dir;

fn runtime_config(temp: &TempDir) -> PostgresRuntimeConfig {
    PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_application_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55443,
        },
    }
}

#[tokio::test]
async fn one_verified_local_administrator_accesses_all_subsystems_and_commands_are_idempotent() {
    let temp = TempDir::new().unwrap();
    let bootstrap = ApplicationBootstrap {
        installation_id: EntityId::new(),
        installation_name: "TuyuBooking Test".to_owned(),
        merchant_id: EntityId::new(),
        merchant_name: "Merchant".to_owned(),
        timezone: "UTC".to_owned(),
        currency_code: "GMB".to_owned(),
    };
    let mut runtime = ApplicationRuntime::start(
        runtime_config(&temp),
        "application-test-password",
        bootstrap,
    )
    .await
    .unwrap();
    assert!(runtime.is_ready());

    let services = runtime.services();
    assert_eq!(
        services.hotel.access().unwrap_err().code,
        ErrorCode::NotAuthenticated
    );

    let identity = VerifiedLocalAdministrator::new(
        EntityId::new().into_uuid(),
        Some("Test Administrator".to_owned()),
        format!("0x{}", "a".repeat(64)),
        "a".repeat(64),
        1_900_000_000_000,
    )
    .unwrap();
    let session = services.login_local_administrator(identity).unwrap();

    assert_eq!(services.available_subsystems(), Subsystem::ALL);
    assert_eq!(
        services.hotel.access().unwrap().administrator_id,
        EntityId::from_uuid(session.administrator_id)
    );
    assert_eq!(
        services.restaurant.access().unwrap().session_id,
        EntityId::from_uuid(session.id)
    );
    assert_eq!(services.tour.access().unwrap().subsystem, Subsystem::Tour);
    assert_eq!(
        services.ticket.access().unwrap().subsystem,
        Subsystem::Ticket
    );

    let envelope = CommandEnvelope {
        command_id: EntityId::new(),
        idempotency_key: CommandKey::new("same-command").unwrap(),
        session_id: EntityId::from_uuid(session.id),
        subsystem: Subsystem::Hotel,
        command_type: "hotel.quote".to_owned(),
        payload: json!({"room_type": "KING"}),
        client_time: OffsetDateTime::from_unix_timestamp(1_800_000_000).unwrap(),
        locale: AppLocale::ZhCn,
    };

    let (_, first) = CommandCoordinator::begin(services.context(), &envelope, &"b".repeat(64))
        .await
        .unwrap();
    assert_eq!(first, CommandDisposition::Acquired);

    let (_, duplicate_in_progress) =
        CommandCoordinator::begin(services.context(), &envelope, &"b".repeat(64))
            .await
            .unwrap();
    assert_eq!(duplicate_in_progress, CommandDisposition::InProgress);

    CommandCoordinator::complete(
        services.context(),
        &envelope,
        200,
        &json!({"reservation_id": "R-1"}),
    )
    .await
    .unwrap();

    let (_, completed) = CommandCoordinator::begin(services.context(), &envelope, &"b".repeat(64))
        .await
        .unwrap();
    assert!(matches!(
        completed,
        CommandDisposition::Completed {
            response_status: 200,
            ..
        }
    ));

    let serialized = serde_json::to_string(&session).unwrap();
    assert!(!serialized.contains("private"));
    assert!(!serialized.contains("mnemonic"));
    assert!(!serialized.contains("seed"));

    services.logout().unwrap();
    assert_eq!(
        services.ticket.access().unwrap_err().code,
        ErrorCode::NotAuthenticated
    );

    runtime.stop().unwrap();
}

#[tokio::test]
async fn startup_failure_never_returns_a_ready_runtime() {
    let temp = TempDir::new().unwrap();
    let mut config = runtime_config(&temp);
    config.bin_dir = temp.path().join("missing-postgresql");

    let result = ApplicationRuntime::start(
        config,
        "unused-password",
        ApplicationBootstrap {
            installation_id: EntityId::new(),
            installation_name: "Invalid".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Invalid".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await;

    let error = match result {
        Ok(_) => panic!("startup unexpectedly succeeded"),
        Err(error) => error,
    };
    assert_eq!(error.code, ErrorCode::StartupFailed);
}
