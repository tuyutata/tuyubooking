use std::path::PathBuf;

use serde_json::{Map, Value};

use crate::storage::StorageError;

use super::process::{ModuleLaunchSpec, ProcessModuleRuntime};
use super::ModuleRuntimeConfig;

pub(crate) fn build(
    config: ModuleRuntimeConfig,
    bench_apps: &[&str],
    install_apps: &[&str],
) -> Result<ProcessModuleRuntime, StorageError> {
    let mut required_paths = vec![
        PathBuf::from("python/bin/python3"),
        PathBuf::from("node/bin/node"),
        PathBuf::from("tuyu_runtime_common.py"),
        PathBuf::from("tuyu_frappe_runtime.py"),
        PathBuf::from("tuyu_frappe_worker.py"),
        PathBuf::from("tuyu_frappe_wsgi.py"),
        PathBuf::from("bench/apps/frappe"),
        PathBuf::from("bench/sites/assets/assets.json"),
    ];
    required_paths.extend(
        bench_apps
            .iter()
            .map(|app| PathBuf::from("bench/apps").join(app)),
    );
    let extra_config = Map::from_iter([
        (
            "bench_apps".to_owned(),
            Value::Array(
                bench_apps
                    .iter()
                    .map(|app| Value::String((*app).to_owned()))
                    .collect(),
            ),
        ),
        (
            "install_apps".to_owned(),
            Value::Array(
                install_apps
                    .iter()
                    .map(|app| Value::String((*app).to_owned()))
                    .collect(),
            ),
        ),
    ]);
    ProcessModuleRuntime::new(
        config,
        ModuleLaunchSpec {
            script: "tuyu_frappe_runtime.py",
            required_paths,
            extra_config,
        },
    )
}
