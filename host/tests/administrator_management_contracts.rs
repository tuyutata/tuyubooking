use schnorrkel::{ExpansionMode, Keypair, MiniSecretKey};
use tempfile::TempDir;
use tuyu_account::{TUYU_PROTOCOL, TUYU_VERSION};
use tuyubooking_native::application::{ApplicationBootstrap, ApplicationRuntime};
use tuyubooking_native::core::EntityId;
use tuyubooking_native::storage::{ConnectionMode, PostgresConnection, PostgresRuntimeConfig};

mod support;
use support::{initialize_administrator, postgres_bin_dir, signed_response};

fn keypair(seed: u8) -> Keypair {
    MiniSecretKey::from_bytes(&[seed; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519)
}

fn canonical_hex(bytes: &[u8]) -> String {
    format!(
        "0x{}",
        bytes
            .iter()
            .map(|value| format!("{value:02x}"))
            .collect::<String>()
    )
}

fn public_key_qr(pair: &Keypair) -> String {
    serde_json::json!({
        "p": TUYU_PROTOCOL,
        "v": TUYU_VERSION,
        "k": 0,
        "b": {"u": canonical_hex(&pair.public.to_bytes())}
    })
    .to_string()
}

async fn qr_login(services: &tuyubooking_native::application::ApplicationServices, pair: &Keypair) {
    let challenge = services.create_qr_login_challenge().await.unwrap();
    services
        .complete_qr_login(signed_response(&challenge, pair))
        .await
        .unwrap();
}

#[tokio::test]
async fn administrator_lifecycle_enforces_local_identity_policy() {
    let temp = TempDir::new().unwrap();
    let installation_id = EntityId::new();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_administrator_management_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55448,
        },
    };
    let password = "administrator-management-test-password";
    let runtime = ApplicationRuntime::start(
        config.clone(),
        password,
        ApplicationBootstrap {
            installation_id,
            installation_name: "Administrator Management Test".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Merchant".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await
    .unwrap();
    let services = runtime.services();

    let state = services.administrator_state().await.unwrap();
    assert!(!state.initialized);
    assert_eq!((state.total, state.active), (0, 0));
    assert!(services.list_administrators().await.is_err());

    let first_pair = keypair(1);
    let first_session =
        initialize_administrator(&services, &first_pair, Some(" 首位管理员 ")).await;
    let first_id = EntityId::from_uuid(first_session.administrator_id);
    assert_eq!(
        first_session.administrator_name.as_deref(),
        Some("首位管理员")
    );
    let duplicate_pair = keypair(100);
    let duplicate_challenge = services.create_qr_login_challenge().await.unwrap();
    assert!(services
        .initialize_administrator(signed_response(&duplicate_challenge, &duplicate_pair), None,)
        .await
        .is_err());
    assert!(services
        .set_administrator_status(first_id, "disabled")
        .await
        .is_err());
    assert!(services.delete_administrator(first_id).await.is_err());

    let second_pair = keypair(2);
    let second = services
        .add_administrator(&public_key_qr(&second_pair), Some("第二管理员"))
        .await
        .unwrap();
    assert!(services
        .add_administrator(&public_key_qr(&second_pair), None)
        .await
        .is_err());
    let original_public_key = second.public_key.clone();
    let renamed = services
        .rename_administrator(EntityId::from_uuid(second.id), Some("值班管理员"))
        .await
        .unwrap();
    assert_eq!(renamed.public_key, original_public_key);
    assert_eq!(renamed.name.as_deref(), Some("值班管理员"));
    services
        .set_administrator_status(EntityId::from_uuid(second.id), "disabled")
        .await
        .unwrap();
    assert_eq!(
        services
            .list_administrators()
            .await
            .unwrap()
            .into_iter()
            .find(|value| value.id == second.id)
            .unwrap()
            .status,
        "disabled"
    );
    services
        .set_administrator_status(EntityId::from_uuid(second.id), "active")
        .await
        .unwrap();

    for seed in 3..=99 {
        services
            .add_administrator(&public_key_qr(&keypair(seed)), None)
            .await
            .unwrap();
    }
    assert_eq!(services.administrator_state().await.unwrap().total, 99);
    assert!(services
        .add_administrator(&public_key_qr(&keypair(100)), None)
        .await
        .is_err());

    let connection = PostgresConnection::connect(&config, password)
        .await
        .unwrap();
    assert!(connection
        .client
        .execute(
            "UPDATE tuyu_core.local_system_administrator SET public_key=$3
             WHERE installation_id=$1 AND id=$2",
            &[
                &installation_id.into_uuid(),
                &second.id,
                &&keypair(100).public.to_bytes()[..],
            ],
        )
        .await
        .is_err());

    services.delete_administrator(first_id).await.unwrap();
    assert!(services.list_administrators().await.is_err());
    let deleted_fingerprint = first_session.public_key_fingerprint;
    let audit_exists: bool = connection
        .client
        .query_one(
            "SELECT EXISTS(
               SELECT 1 FROM tuyu_core.administrator_audit_log
               WHERE action='administrator_deleted'
                 AND target_public_key_fingerprint=$1
             )",
            &[&deleted_fingerprint],
        )
        .await
        .unwrap()
        .get(0);
    assert!(audit_exists);

    qr_login(&services, &second_pair).await;
    connection
        .client
        .execute(
            "UPDATE tuyu_core.local_system_administrator SET status='disabled'
             WHERE installation_id=$1 AND id<>$2",
            &[&installation_id.into_uuid(), &second.id],
        )
        .await
        .unwrap();
    assert_eq!(services.administrator_state().await.unwrap().active, 1);
    assert!(services
        .delete_administrator(EntityId::from_uuid(second.id))
        .await
        .is_err());
    assert!(services
        .set_administrator_status(EntityId::from_uuid(second.id), "disabled")
        .await
        .is_err());

    drop(connection);
    runtime.stop().unwrap();
}
