use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::storage::StorageError;

use super::ModuleRuntimeStatus;

/// Stable identifiers shared by native code, Flutter and module manifests.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BusinessModule {
    Hotel,
    Restaurant,
    Tour,
    Ticket,
}

impl BusinessModule {
    pub const ALL: [Self; 4] = [Self::Hotel, Self::Restaurant, Self::Tour, Self::Ticket];

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Hotel => "hotel",
            Self::Restaurant => "restaurant",
            Self::Tour => "tour",
            Self::Ticket => "ticket",
        }
    }

    pub const fn schema(self) -> &'static str {
        match self {
            Self::Hotel => "module_kamra",
            Self::Restaurant => "module_ury",
            Self::Tour => "module_voyant",
            Self::Ticket => "module_hi_events",
        }
    }

    pub const fn database_role(self) -> &'static str {
        match self {
            Self::Hotel => "tuyu_kamra_app",
            Self::Restaurant => "tuyu_ury_app",
            Self::Tour => "tuyu_voyant_app",
            Self::Ticket => "tuyu_hi_events_app",
        }
    }

    pub fn parse(value: &str) -> Result<Self, StorageError> {
        match value {
            "hotel" => Ok(Self::Hotel),
            "restaurant" => Ok(Self::Restaurant),
            "tour" => Ok(Self::Tour),
            "ticket" => Ok(Self::Ticket),
            _ => Err(StorageError::InvalidData(format!(
                "unknown business module: {value}"
            ))),
        }
    }
}

#[derive(Debug, Clone)]
pub struct ModuleRuntimeConfig {
    pub module: BusinessModule,
    pub enabled: bool,
    pub installation_dir: PathBuf,
    pub runtime_dir: PathBuf,
    pub data_dir: PathBuf,
    pub log_file: PathBuf,
    pub public_hostname: String,
    pub merchant_name: String,
    pub https_port: u16,
    pub site_name: Option<String>,
    pub administrator_password: Option<String>,
}

impl ModuleRuntimeConfig {
    pub fn validate(&self) -> Result<(), StorageError> {
        if self.data_dir.as_os_str().is_empty() || self.log_file.as_os_str().is_empty() {
            return Err(StorageError::InvalidData(format!(
                "{} runtime requires explicit data and log paths",
                self.module.as_str()
            )));
        }
        if self.data_dir.starts_with(&self.installation_dir) {
            return Err(StorageError::DataDirectoryInsideInstallation);
        }
        if self.https_port == 0 || self.public_hostname.trim().is_empty() {
            return Err(StorageError::InvalidData(format!(
                "{} runtime requires a valid HTTPS endpoint",
                self.module.as_str()
            )));
        }
        Ok(())
    }

    pub fn https_origin(&self) -> String {
        format!("https://{}:{}", self.public_hostname, self.https_port)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ModuleRuntimeSnapshot {
    pub id: &'static str,
    pub status: ModuleRuntimeStatus,
    pub schema: &'static str,
    pub https_origin: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum EmployeeGatewayStatus {
    Disabled,
    Starting,
    Ready,
    Failed,
    Stopping,
}

#[derive(Debug, Clone)]
pub struct EmployeeGatewayConfig {
    pub installation_dir: PathBuf,
    pub runtime_dir: PathBuf,
    pub data_dir: PathBuf,
    pub log_file: PathBuf,
    pub public_hostname: String,
    pub merchant_name: String,
    pub https_port: u16,
}

impl EmployeeGatewayConfig {
    pub fn validate(&self) -> Result<(), StorageError> {
        if self.runtime_dir.as_os_str().is_empty()
            || self.data_dir.as_os_str().is_empty()
            || self.log_file.as_os_str().is_empty()
            || self.public_hostname.trim().is_empty()
            || self.merchant_name.trim().is_empty()
            || self.https_port == 0
        {
            return Err(StorageError::InvalidData(
                "employee gateway requires runtime, data, log and HTTPS endpoint".to_owned(),
            ));
        }
        if self.data_dir.starts_with(&self.installation_dir) {
            return Err(StorageError::DataDirectoryInsideInstallation);
        }
        Ok(())
    }

    pub fn https_origin(&self) -> String {
        format!("https://{}:{}", self.public_hostname, self.https_port)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct EmployeeGatewayRouteSnapshot {
    pub module: &'static str,
    pub path: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct EmployeeGatewaySnapshot {
    pub enabled: bool,
    pub status: EmployeeGatewayStatus,
    pub https_origin: String,
    pub certificate_fingerprint: Option<String>,
    pub routes: Vec<EmployeeGatewayRouteSnapshot>,
    pub error: Option<String>,
}
