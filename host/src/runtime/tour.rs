use std::path::PathBuf;

use serde_json::{Map, Value};

use crate::storage::StorageError;

use super::process::{ModuleLaunchSpec, ProcessModuleRuntime};
use super::ModuleRuntimeConfig;

pub(crate) fn build(config: ModuleRuntimeConfig) -> Result<ProcessModuleRuntime, StorageError> {
    ProcessModuleRuntime::new(
        config,
        ModuleLaunchSpec {
            script: "tuyu_voyant_runtime.py",
            required_paths: vec![
                PathBuf::from("python/bin/python3"),
                PathBuf::from("node/bin/node"),
                PathBuf::from("tuyu_runtime_common.py"),
                PathBuf::from("tuyu_https_proxy.py"),
                PathBuf::from("tuyu_voyant_runtime.py"),
                PathBuf::from("voyant/operator/.output/server/index.mjs"),
                PathBuf::from("voyant/operator/.output/migration/migrate.mjs"),
                PathBuf::from("voyant/operator/migrations/0000_baseline.sql"),
            ],
            extra_config: Map::from_iter([(
                "node_executable".to_owned(),
                Value::String("node/bin/node".to_owned()),
            )]),
        },
    )
}
