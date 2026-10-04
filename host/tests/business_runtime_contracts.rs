use std::collections::BTreeSet;

use tempfile::TempDir;
use tuyubooking_native::runtime::{
    BusinessModule, BusinessRuntimeManager, ConnectionMode, ModuleRuntimeConfig,
    ModuleRuntimeStatus, PostgresRuntimeConfig,
};
use tuyubooking_native::storage::StorageError;

fn config(temp: &TempDir, module: BusinessModule, enabled: bool) -> ModuleRuntimeConfig {
    ModuleRuntimeConfig {
        module,
        enabled,
        installation_dir: temp.path().join("install"),
        runtime_dir: temp.path().join("payload"),
        data_dir: temp.path().join("data").join(module.as_str()),
        log_file: temp
            .path()
            .join("logs")
            .join(format!("{}.log", module.as_str())),
        public_hostname: "localhost".to_owned(),
        merchant_name: "Test Merchant".to_owned(),
        https_port: match module {
            BusinessModule::Hotel => 58_443,
            BusinessModule::Restaurant => 58_450,
            BusinessModule::Tour => 58_444,
            BusinessModule::Ticket => 58_446,
        },
        site_name: matches!(module, BusinessModule::Hotel | BusinessModule::Restaurant)
            .then(|| format!("{}.localhost", module.as_str())),
        administrator_password: matches!(
            module,
            BusinessModule::Hotel | BusinessModule::Restaurant
        )
        .then(|| "test-only-password".to_owned()),
    }
}

fn postgres_config(temp: &TempDir) -> PostgresRuntimeConfig {
    PostgresRuntimeConfig {
        bin_dir: temp.path().join("postgresql/bin"),
        installation_dir: temp.path().join("install"),
        data_dir: temp.path().join("postgresql/data"),
        log_file: temp.path().join("logs/postgresql.log"),
        username: "tuyubooking".to_owned(),
        database: "tuyubooking".to_owned(),
        connection: ConnectionMode::LoopbackTcp { port: 55_432 },
    }
}

#[test]
fn every_business_module_has_an_independent_schema_and_endpoint() {
    let temp = TempDir::new().unwrap();
    let mut manager = BusinessRuntimeManager::new(
        BusinessModule::ALL
            .into_iter()
            .map(|module| config(&temp, module, true))
            .collect(),
    )
    .unwrap();
    let snapshots = manager.snapshots();
    assert_eq!(snapshots.len(), 4);
    assert_eq!(
        snapshots
            .iter()
            .map(|snapshot| snapshot.schema)
            .collect::<BTreeSet<_>>()
            .len(),
        4
    );
    assert!(snapshots
        .iter()
        .all(|snapshot| snapshot.status == ModuleRuntimeStatus::PayloadMissing));
}

#[test]
fn a_missing_payload_does_not_change_another_modules_state() {
    let temp = TempDir::new().unwrap();
    let mut manager = BusinessRuntimeManager::new(vec![
        config(&temp, BusinessModule::Hotel, true),
        config(&temp, BusinessModule::Restaurant, false),
    ])
    .unwrap();
    let snapshots = manager.snapshots();
    assert_eq!(snapshots[0].status, ModuleRuntimeStatus::PayloadMissing);
    assert_eq!(snapshots[1].status, ModuleRuntimeStatus::Disabled);
}

#[test]
fn restarting_one_module_preserves_every_sibling_state() {
    let temp = TempDir::new().unwrap();
    let mut manager = BusinessRuntimeManager::new(vec![
        config(&temp, BusinessModule::Hotel, true),
        config(&temp, BusinessModule::Restaurant, false),
        config(&temp, BusinessModule::Tour, true),
    ])
    .unwrap();

    let restarted = manager
        .restart(
            BusinessModule::Hotel,
            &postgres_config(&temp),
            "test-only-database-password",
        )
        .unwrap();
    assert_eq!(restarted.status, ModuleRuntimeStatus::PayloadMissing);

    let snapshots = manager.snapshots();
    assert_eq!(snapshots[0].status, ModuleRuntimeStatus::PayloadMissing);
    assert_eq!(snapshots[1].status, ModuleRuntimeStatus::Disabled);
    assert_eq!(snapshots[2].status, ModuleRuntimeStatus::PayloadMissing);
}

#[test]
fn module_data_cannot_be_stored_inside_the_installation() {
    let temp = TempDir::new().unwrap();
    let mut invalid = config(&temp, BusinessModule::Hotel, true);
    invalid.data_dir = invalid.installation_dir.join("mutable");
    assert!(matches!(
        BusinessRuntimeManager::new(vec![invalid]),
        Err(StorageError::DataDirectoryInsideInstallation)
    ));
}

#[test]
fn only_selected_modules_are_enabled_and_started() {
    let temp = TempDir::new().unwrap();
    let mut manager = BusinessRuntimeManager::new(
        BusinessModule::ALL
            .into_iter()
            .map(|module| config(&temp, module, false))
            .collect(),
    )
    .unwrap();
    manager
        .configure_enabled(
            &BTreeSet::from([BusinessModule::Restaurant]),
            &postgres_config(&temp),
            "test-only-database-password",
        )
        .unwrap();
    let snapshots = manager.snapshots();
    assert_eq!(snapshots[0].status, ModuleRuntimeStatus::Disabled);
    assert_eq!(snapshots[1].status, ModuleRuntimeStatus::PayloadMissing);
    assert_eq!(snapshots[2].status, ModuleRuntimeStatus::Disabled);
    assert_eq!(snapshots[3].status, ModuleRuntimeStatus::Disabled);
}
