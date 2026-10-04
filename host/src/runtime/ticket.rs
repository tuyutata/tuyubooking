use std::path::PathBuf;

use serde_json::Map;

use crate::storage::StorageError;

use super::process::{ModuleLaunchSpec, ProcessModuleRuntime};
use super::ModuleRuntimeConfig;

pub(crate) fn build(config: ModuleRuntimeConfig) -> Result<ProcessModuleRuntime, StorageError> {
    ProcessModuleRuntime::new(
        config,
        ModuleLaunchSpec {
            script: "tuyu_hi_events_runtime.py",
            required_paths: vec![
                PathBuf::from("python/bin/python3"),
                PathBuf::from("php/bin/php"),
                PathBuf::from("nginx/sbin/nginx"),
                PathBuf::from("tuyu_runtime_common.py"),
                PathBuf::from("tuyu_https_proxy.py"),
                PathBuf::from("tuyu_hi_events_runtime.py"),
                PathBuf::from("hi_events/backend/artisan"),
                PathBuf::from("hi_events/frontend/server.js"),
                PathBuf::from("hi_events/frontend/dist/server/entry.server.js"),
            ],
            extra_config: Map::new(),
        },
    )
}
