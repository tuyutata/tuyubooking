use schnorrkel::{ExpansionMode, Keypair, MiniSecretKey};
use tempfile::TempDir;
use tuyu_account::{TUYU_PROTOCOL, TUYU_VERSION};
use tuyubooking_native::application::{ApplicationBootstrap, ApplicationRuntime};
use tuyubooking_native::core::EntityId;
use tuyubooking_native::storage::{ConnectionMode, PostgresRuntimeConfig};

mod support;
use support::{initialize_administrator, postgres_bin_dir, signed_response};

fn canonical_hex(bytes: &[u8]) -> String {
    format!(
        "0x{}",
        bytes
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>()
    )
}

fn public_key_qr(pair: &Keypair) -> String {
    serde_json::json!({
        "p": TUYU_PROTOCOL, "v": TUYU_VERSION, "k": 0,
        "b": {"u": canonical_hex(&pair.public.to_bytes())}
    })
    .to_string()
}

#[tokio::test]
async fn local_qr_login_accepts_one_authorized_signature_and_rejects_replay() {
    let temp = TempDir::new().unwrap();
    let installation_id = EntityId::new();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_qr_login_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55446,
        },
    };
    let password = "qr-login-test-password";
    let runtime = ApplicationRuntime::start(
        config.clone(),
        password,
        ApplicationBootstrap {
            installation_id,
            installation_name: "QR Login Test".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Merchant".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await
    .unwrap();
    let mini = MiniSecretKey::from_bytes(&[9_u8; 32]).unwrap();
    let pair = mini.expand_to_keypair(ExpansionMode::Ed25519);
    let services = runtime.services();
    initialize_administrator(&services, &pair, Some("值班管理员")).await;
    services.logout().unwrap();
    let challenge = services.create_qr_login_challenge().await.unwrap();
    let response = signed_response(&challenge, &pair);
    let session = services.complete_qr_login(response.clone()).await.unwrap();
    assert_eq!(session.administrator_name.as_deref(), Some("值班管理员"));
    assert_eq!(
        services.hotel.access().unwrap().administrator_id,
        EntityId::from_uuid(session.administrator_id)
    );
    assert!(services.complete_qr_login(response).await.is_err());

    runtime.stop().unwrap();
}

#[tokio::test]
async fn local_qr_login_rejects_an_unregistered_public_key() {
    let temp = TempDir::new().unwrap();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_unknown_admin_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55447,
        },
    };
    let runtime = ApplicationRuntime::start(
        config,
        "unknown-admin-password",
        ApplicationBootstrap {
            installation_id: EntityId::new(),
            installation_name: "Unknown Administrator Test".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Merchant".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await
    .unwrap();
    let authorized_pair = MiniSecretKey::from_bytes(&[7_u8; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519);
    let unknown_pair = MiniSecretKey::from_bytes(&[8_u8; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519);
    let services = runtime.services();
    initialize_administrator(&services, &authorized_pair, Some("授权管理员")).await;
    services.logout().unwrap();
    let challenge = services.create_qr_login_challenge().await.unwrap();
    let result = services
        .complete_qr_login(signed_response(&challenge, &unknown_pair))
        .await;
    assert!(result.is_err());
    runtime.stop().unwrap();
}

#[tokio::test]
async fn every_active_administrator_can_login_and_a_disabled_one_cannot() {
    let temp = TempDir::new().unwrap();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_multiple_admin_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55449,
        },
    };
    let runtime = ApplicationRuntime::start(
        config,
        "multiple-admin-password",
        ApplicationBootstrap {
            installation_id: EntityId::new(),
            installation_name: "Multiple Administrator Test".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Merchant".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await
    .unwrap();
    let first_pair = MiniSecretKey::from_bytes(&[10_u8; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519);
    let second_pair = MiniSecretKey::from_bytes(&[11_u8; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519);
    let services = runtime.services();
    initialize_administrator(&services, &first_pair, Some("第一管理员")).await;
    let second = services
        .add_administrator(&public_key_qr(&second_pair), Some("第二管理员"))
        .await
        .unwrap();
    services.logout().unwrap();

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let session = services
        .complete_qr_login(signed_response(&challenge, &second_pair))
        .await
        .unwrap();
    assert_eq!(session.administrator_id, second.id);
    assert_eq!(session.administrator_name.as_deref(), Some("第二管理员"));

    services
        .set_administrator_status(EntityId::from_uuid(second.id), "disabled")
        .await
        .unwrap();
    let challenge = services.create_qr_login_challenge().await.unwrap();
    assert!(services
        .complete_qr_login(signed_response(&challenge, &second_pair))
        .await
        .is_err());
    runtime.stop().unwrap();
}

#[tokio::test]
async fn altered_scope_nonce_identity_and_expiry_are_rejected() {
    let temp = TempDir::new().unwrap();
    let config = PostgresRuntimeConfig {
        bin_dir: postgres_bin_dir(),
        installation_dir: temp.path().join("installation"),
        data_dir: temp.path().join("data"),
        log_file: temp.path().join("postgres.log"),
        username: "tuyu_tampered_login_test".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::UnixSocket {
            directory: temp.path().join("socket"),
            port: 55450,
        },
    };
    let runtime = ApplicationRuntime::start(
        config,
        "tampered-login-password",
        ApplicationBootstrap {
            installation_id: EntityId::new(),
            installation_name: "Tampered Login Test".to_owned(),
            merchant_id: EntityId::new(),
            merchant_name: "Merchant".to_owned(),
            timezone: "UTC".to_owned(),
            currency_code: "GMB".to_owned(),
        },
    )
    .await
    .unwrap();
    let pair = MiniSecretKey::from_bytes(&[12_u8; 32])
        .unwrap()
        .expand_to_keypair(ExpansionMode::Ed25519);
    let services = runtime.services();
    initialize_administrator(&services, &pair, Some("安全管理员")).await;
    services.logout().unwrap();

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let mut altered = challenge.clone();
    altered.b.a = "another-product".to_owned();
    assert!(services
        .complete_qr_login(signed_response(&altered, &pair))
        .await
        .is_err());

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let mut altered = challenge.clone();
    altered.b.t = "another-installation".to_owned();
    assert!(services
        .complete_qr_login(signed_response(&altered, &pair))
        .await
        .is_err());

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let mut altered = challenge.clone();
    altered.b.n = format!("0x{}", "55".repeat(32));
    assert!(services
        .complete_qr_login(signed_response(&altered, &pair))
        .await
        .is_err());

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let mut altered_response = signed_response(&challenge, &pair);
    altered_response.i = format!("tyc_{}", "66".repeat(16));
    assert!(services.complete_qr_login(altered_response).await.is_err());

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let mut altered_response = signed_response(&challenge, &pair);
    altered_response.e += 1;
    assert!(services.complete_qr_login(altered_response).await.is_err());

    let challenge = services.create_qr_login_challenge().await.unwrap();
    let mut altered_response = signed_response(&challenge, &pair);
    altered_response.v += 1;
    assert!(services.complete_qr_login(altered_response).await.is_err());
    runtime.stop().unwrap();
}
