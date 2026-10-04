use crate::application::{
    ApplicationContext, ApplicationError, ApplicationServices, ErrorCode, LocalizedMessage,
};
use crate::core::EntityId;
use crate::runtime::{
    BusinessModule, BusinessRuntimeManager, ModuleRuntimeConfig, ModuleRuntimeSnapshot,
};
use crate::storage::{
    CoreRepository, PostgresConnection, PostgresRuntime, PostgresRuntimeConfig, SchemaExecutor,
};
use std::collections::BTreeSet;
use std::sync::Arc;
use tokio::sync::Mutex;
use zeroize::Zeroizing;

#[derive(Clone, Debug)]
pub struct ApplicationBootstrap {
    pub installation_id: EntityId,
    pub installation_name: String,
    pub merchant_id: EntityId,
    pub merchant_name: String,
    pub timezone: String,
    pub currency_code: String,
}

pub struct ApplicationRuntime {
    runtime: PostgresRuntime,
    business_runtime: Option<BusinessRuntimeManager>,
    database_password: Zeroizing<String>,
    context: ApplicationContext,
    installation_id: EntityId,
    module_configuration_complete: bool,
}

impl ApplicationRuntime {
    pub async fn start(
        config: PostgresRuntimeConfig,
        database_password: &str,
        bootstrap: ApplicationBootstrap,
    ) -> Result<Self, ApplicationError> {
        Self::start_internal(config, database_password, bootstrap, None).await
    }

    pub async fn start_with_modules(
        config: PostgresRuntimeConfig,
        database_password: &str,
        bootstrap: ApplicationBootstrap,
        module_configs: Vec<ModuleRuntimeConfig>,
    ) -> Result<Self, ApplicationError> {
        Self::start_internal(config, database_password, bootstrap, Some(module_configs)).await
    }

    async fn start_internal(
        config: PostgresRuntimeConfig,
        database_password: &str,
        bootstrap: ApplicationBootstrap,
        module_configs: Option<Vec<ModuleRuntimeConfig>>,
    ) -> Result<Self, ApplicationError> {
        let mut runtime = PostgresRuntime::new(config.clone()).map_err(startup_error)?;
        runtime
            .initialize(database_password)
            .map_err(startup_error)?;
        runtime.start().map_err(startup_error)?;
        runtime
            .ensure_application_database(database_password)
            .map_err(startup_error)?;

        let connection = PostgresConnection::connect(&config, database_password)
            .await
            .map_err(startup_error)?;
        SchemaExecutor::apply(&connection.client)
            .await
            .map_err(startup_error)?;

        let installation_id = connection
            .client
            .query_opt(
                "SELECT id FROM tuyu_core.installation ORDER BY created_at ASC LIMIT 1",
                &[],
            )
            .await
            .map_err(|error| startup_error(error.into()))?
            .map(|row| EntityId::from_uuid(row.get("id")))
            .unwrap_or(bootstrap.installation_id);
        connection
            .client
            .execute(
                "INSERT INTO tuyu_core.installation (id, instance_name)
                 VALUES ($1, $2)
                 ON CONFLICT (id) DO UPDATE SET instance_name = EXCLUDED.instance_name,
                     updated_at = CURRENT_TIMESTAMP, version = tuyu_core.installation.version + 1",
                &[&installation_id.into_uuid(), &bootstrap.installation_name],
            )
            .await
            .map_err(|error| startup_error(error.into()))?;

        let stored_modules =
            CoreRepository::business_module_configuration(&connection.client, installation_id)
                .await
                .map_err(startup_error)?;
        let enabled_modules = stored_modules
            .enabled_modules
            .iter()
            .map(|module| BusinessModule::parse(module).map_err(startup_error))
            .collect::<Result<BTreeSet<_>, _>>()?;

        let merchant_id = connection
            .client
            .query_opt(
                "SELECT id FROM tuyu_core.merchant_profile WHERE installation_id=$1
                 ORDER BY created_at ASC LIMIT 1",
                &[&installation_id.into_uuid()],
            )
            .await
            .map_err(|error| startup_error(error.into()))?
            .map(|row| EntityId::from_uuid(row.get("id")))
            .unwrap_or(bootstrap.merchant_id);
        connection
            .client
            .execute(
                "INSERT INTO tuyu_core.merchant_profile
                 (id, installation_id, display_name, timezone, currency_code)
                 VALUES ($1, $2, $3, $4, $5)
                 ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name,
                     timezone = EXCLUDED.timezone, currency_code = EXCLUDED.currency_code,
                     updated_at = CURRENT_TIMESTAMP,
                     version = tuyu_core.merchant_profile.version + 1",
                &[
                    &merchant_id.into_uuid(),
                    &installation_id.into_uuid(),
                    &bootstrap.merchant_name,
                    &bootstrap.timezone,
                    &bootstrap.currency_code,
                ],
            )
            .await
            .map_err(|error| startup_error(error.into()))?;

        let context = ApplicationContext {
            database: Arc::new(Mutex::new(connection)),
            account: Arc::new(
                tuyu_account::AccountService::new("tuyubooking", installation_id.into_uuid())
                    .map_err(ApplicationError::from)?,
            ),
        };

        let mut business_runtime = if let Some(mut configs) = module_configs {
            for config in &mut configs {
                config.enabled = enabled_modules.contains(&config.module);
            }
            Some(BusinessRuntimeManager::new(configs).map_err(startup_error)?)
        } else {
            None
        };
        if let Some(manager) = business_runtime.as_mut() {
            manager.start_enabled(runtime.config(), database_password);
        }

        Ok(Self {
            runtime,
            business_runtime,
            database_password: Zeroizing::new(database_password.to_owned()),
            context,
            installation_id,
            module_configuration_complete: stored_modules.configured,
        })
    }

    pub fn services(&self) -> ApplicationServices {
        ApplicationServices::new(self.context.clone())
    }

    /// 检查已有核心连接和安装记录，不以子系统进程状态代替数据库健康状态。
    /// 超时包含等待连接锁的时间，数据库失联不能无限阻塞桌面状态查询。
    pub async fn core_is_ready(&self) -> bool {
        core_health_result(async {
            let database = self.context.database.lock().await;
            database
                .client
                .query_opt(
                    "SELECT id FROM tuyu_core.installation WHERE id = $1",
                    &[&self.installation_id.into_uuid()],
                )
                .await
                .map(|row| row.is_some())
                .unwrap_or(false)
        })
        .await
    }

    pub fn is_ready(&mut self) -> bool {
        self.business_runtime
            .as_mut()
            .map(BusinessRuntimeManager::all_enabled_ready)
            .unwrap_or(true)
    }

    pub fn business_snapshots(&mut self) -> Vec<ModuleRuntimeSnapshot> {
        self.business_runtime
            .as_mut()
            .map(BusinessRuntimeManager::snapshots)
            .unwrap_or_default()
    }

    pub fn module_configuration_complete(&self) -> bool {
        self.module_configuration_complete
    }

    pub fn enabled_business_modules(&self) -> BTreeSet<BusinessModule> {
        self.business_runtime
            .as_ref()
            .map(BusinessRuntimeManager::enabled_modules)
            .unwrap_or_default()
    }

    pub async fn configure_business_modules(
        &mut self,
        enabled: BTreeSet<BusinessModule>,
    ) -> Result<Vec<ModuleRuntimeSnapshot>, ApplicationError> {
        if enabled.is_empty() {
            return Err(business_module_configuration_error());
        }
        let names = enabled
            .iter()
            .map(|module| module.as_str().to_owned())
            .collect();
        let database = self.context.database.lock().await;
        CoreRepository::set_business_modules(&database.client, self.installation_id, &names)
            .await
            .map_err(|_| business_module_configuration_error())?;
        drop(database);
        let manager = self
            .business_runtime
            .as_mut()
            .ok_or_else(business_module_configuration_error)?;
        let snapshots = manager
            .configure_enabled(
                &enabled,
                self.runtime.config(),
                self.database_password.as_str(),
            )
            .map_err(|_| business_module_configuration_error())?;
        self.module_configuration_complete = true;
        Ok(snapshots)
    }

    pub fn restart_business_module(
        &mut self,
        module: BusinessModule,
    ) -> Result<ModuleRuntimeSnapshot, ApplicationError> {
        let manager = self
            .business_runtime
            .as_mut()
            .ok_or_else(business_runtime_error)?;
        manager
            .restart(
                module,
                self.runtime.config(),
                self.database_password.as_str(),
            )
            .map_err(|_| business_runtime_error())
    }

    pub fn stop(mut self) -> Result<(), ApplicationError> {
        if let Some(manager) = self.business_runtime.as_mut() {
            manager.stop().map_err(startup_error)?;
        }
        self.runtime.stop().map_err(startup_error)
    }
}

async fn core_health_result(check: impl std::future::Future<Output = bool>) -> bool {
    tokio::time::timeout(std::time::Duration::from_secs(2), check)
        .await
        .unwrap_or(false)
}

fn startup_error(error: crate::storage::StorageError) -> ApplicationError {
    let message = match error {
        crate::storage::StorageError::SchemaChecksumMismatch { .. } => LocalizedMessage::new(
            "startup.database_version_mismatch",
            "本机数据结构与当前途遇商家端版本不一致",
            "The local data structure does not match this TuyuBooking version",
        ),
        crate::storage::StorageError::SchemaExecution { .. } => LocalizedMessage::new(
            "startup.database_initialization_failed",
            "途遇商家端本地数据库初始化失败",
            "The TuyuBooking local database could not be initialized",
        ),
        _ => LocalizedMessage::new(
            "startup.database_failed",
            "途遇商家端本地数据服务启动失败",
            "The TuyuBooking local data service failed to start",
        ),
    };
    ApplicationError::new(ErrorCode::StartupFailed, message)
}

fn business_runtime_error() -> ApplicationError {
    ApplicationError::new(
        ErrorCode::StartupFailed,
        LocalizedMessage::new(
            "runtime.module_restart_failed",
            "业务子系统重新启动失败",
            "The business subsystem could not be restarted",
        ),
    )
}

fn business_module_configuration_error() -> ApplicationError {
    ApplicationError::new(
        ErrorCode::StartupFailed,
        LocalizedMessage::new(
            "runtime.module_configuration_failed",
            "业务系统启用配置保存失败",
            "The business system configuration could not be saved",
        ),
    )
}

#[cfg(test)]
mod tests {
    use super::startup_error;
    use crate::storage::StorageError;

    #[tokio::test]
    async fn core_health_requires_a_successful_query() {
        assert!(super::core_health_result(async { true }).await);
        assert!(!super::core_health_result(async { false }).await);
    }

    #[tokio::test]
    async fn core_health_timeout_is_not_ready() {
        // 用不返回的查询替身覆盖失联路径，不启动真实商家数据库。
        assert!(!super::core_health_result(std::future::pending()).await);
    }

    #[test]
    fn startup_errors_expose_safe_categories_without_internal_details() {
        let mismatch = startup_error(StorageError::SchemaChecksumMismatch {
            schema_name: "secret-schema-name".to_owned(),
        });
        assert_eq!(mismatch.message.key, "startup.database_version_mismatch");
        assert!(!mismatch.message.zh_cn.contains("secret-schema-name"));
        assert!(!mismatch.message.en_us.contains("secret-schema-name"));

        let execution = startup_error(StorageError::SchemaExecution {
            schema_name: "secret-schema-name".to_owned(),
            message: "secret-database-detail".to_owned(),
        });
        assert_eq!(
            execution.message.key,
            "startup.database_initialization_failed"
        );
        assert!(!execution.message.zh_cn.contains("secret-database-detail"));
        assert!(!execution.message.en_us.contains("secret-database-detail"));
    }
}
