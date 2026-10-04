use crate::storage::StorageError;

use super::frappe_distribution;
use super::process::ProcessModuleRuntime;
use super::ModuleRuntimeConfig;

pub(crate) fn build(config: ModuleRuntimeConfig) -> Result<ProcessModuleRuntime, StorageError> {
    frappe_distribution::build(config, &["frappe", "kamra"], &["kamra"])
}
