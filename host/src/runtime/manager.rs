use std::collections::{BTreeMap, BTreeSet};

use crate::runtime::postgres::PostgresRuntimeConfig;
use crate::storage::StorageError;

use super::process::ProcessModuleRuntime;
use super::{hotel, restaurant, ticket, tour};
use super::{BusinessModule, ModuleRuntimeConfig, ModuleRuntimeSnapshot, ModuleRuntimeStatus};

/// Owns each module as an independent lifecycle and failure boundary.
pub struct BusinessRuntimeManager {
    modules: BTreeMap<BusinessModule, ProcessModuleRuntime>,
}

impl BusinessRuntimeManager {
    pub fn new(configs: Vec<ModuleRuntimeConfig>) -> Result<Self, StorageError> {
        let mut modules = BTreeMap::new();
        for config in configs {
            let module = config.module;
            if modules.contains_key(&module) {
                return Err(StorageError::InvalidData(format!(
                    "duplicate business runtime configuration: {}",
                    module.as_str()
                )));
            }
            let runtime = match module {
                BusinessModule::Hotel => hotel::build(config)?,
                BusinessModule::Restaurant => restaurant::build(config)?,
                BusinessModule::Tour => tour::build(config)?,
                BusinessModule::Ticket => ticket::build(config)?,
            };
            modules.insert(module, runtime);
        }
        Ok(Self { modules })
    }

    pub fn start_enabled(&mut self, postgres: &PostgresRuntimeConfig, password: &str) {
        for runtime in self.modules.values_mut() {
            if runtime.is_enabled() {
                runtime.start(postgres, password);
            }
        }
    }

    pub fn configure_enabled(
        &mut self,
        enabled: &BTreeSet<BusinessModule>,
        postgres: &PostgresRuntimeConfig,
        password: &str,
    ) -> Result<Vec<ModuleRuntimeSnapshot>, StorageError> {
        for (module, runtime) in &mut self.modules {
            if enabled.contains(module) {
                runtime.enable();
                runtime.start(postgres, password);
            } else {
                runtime.disable()?;
            }
        }
        Ok(self.snapshots())
    }

    pub fn enabled_modules(&self) -> BTreeSet<BusinessModule> {
        self.modules
            .iter()
            .filter(|(_, runtime)| runtime.is_enabled())
            .map(|(module, _)| *module)
            .collect()
    }

    pub fn snapshots(&mut self) -> Vec<ModuleRuntimeSnapshot> {
        self.modules
            .values_mut()
            .map(ProcessModuleRuntime::snapshot)
            .collect()
    }

    pub fn all_enabled_ready(&mut self) -> bool {
        self.snapshots().into_iter().all(|snapshot| {
            matches!(
                snapshot.status,
                ModuleRuntimeStatus::Disabled | ModuleRuntimeStatus::Ready
            )
        })
    }

    /// Restarts exactly one business failure boundary. PostgreSQL and the
    /// other three module process groups remain untouched.
    pub fn restart(
        &mut self,
        module: BusinessModule,
        postgres: &PostgresRuntimeConfig,
        password: &str,
    ) -> Result<ModuleRuntimeSnapshot, StorageError> {
        let runtime = self.modules.get_mut(&module).ok_or_else(|| {
            StorageError::InvalidData(format!(
                "business runtime is not configured: {}",
                module.as_str()
            ))
        })?;
        runtime.stop()?;
        runtime.start(postgres, password);
        Ok(runtime.snapshot())
    }

    pub fn stop(&mut self) -> Result<(), StorageError> {
        let mut first_error = None;
        for runtime in self.modules.values_mut().rev() {
            if let Err(error) = runtime.stop() {
                first_error.get_or_insert(error);
            }
        }
        match first_error {
            Some(error) => Err(error),
            None => Ok(()),
        }
    }
}

impl Drop for BusinessRuntimeManager {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}
