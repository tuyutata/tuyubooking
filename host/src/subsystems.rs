//! Contracts shared by every bundled TuyuBooking business subsystem.
//!
//! Every local platform administrator has the same TuyuBooking authority.
//! Business employees continue to use each subsystem's native account model.

use serde::Deserialize;
use std::{
    collections::BTreeSet,
    fs,
    path::{Path, PathBuf},
};
use thiserror::Error;

pub const DATABASE_NAME: &str = "tuyubooking";
pub const CORE_SCHEMA: &str = "tuyu_core";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlatformAccountPolicy {
    pub administrators_have_equal_access: bool,
    pub authentication: &'static str,
}

impl Default for PlatformAccountPolicy {
    fn default() -> Self {
        Self {
            administrators_have_equal_access: true,
            authentication: "tuyu_sr25519",
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct ModuleManifest {
    pub id: String,
    pub name_zh: String,
    pub name_en: String,
    pub version: String,
    pub module_api: u32,
    pub integration_status: String,
    pub verification: VerificationContract,
    pub source: SourceContract,
    pub runtime: RuntimeContract,
    pub localization: LocalizationContract,
    pub authentication: AuthenticationContract,
    pub access: AccessContract,
    pub database: DatabaseContract,
    pub orders: OrderContract,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SourceContract {
    pub repository: String,
    pub commit: String,
    pub path: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RuntimeContract {
    pub family: String,
    pub build: String,
    pub start: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct VerificationContract {
    pub source: String,
    pub database: String,
    pub runtime: String,
    pub e2e: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LocalizationContract {
    pub default: String,
    pub supported: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AuthenticationContract {
    pub administrator: String,
    pub staff: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AccessContract {
    pub employee_access: String,
    pub https_required: bool,
    pub public_access: bool,
    pub gateway_only: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DatabaseContract {
    pub engine: String,
    pub database: String,
    pub schema: String,
    pub role: String,
    pub isolated_database: bool,
    pub additional_persistent_database: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct OrderContract {
    pub owns_orders: bool,
    pub event_contract: String,
}

#[derive(Debug)]
pub struct ModuleRegistry {
    modules: Vec<ModuleManifest>,
}

impl ModuleRegistry {
    pub fn load(directory: impl AsRef<Path>) -> Result<Self, RegistryError> {
        let directory = directory.as_ref();
        let mut paths = fs::read_dir(directory)
            .map_err(|source| RegistryError::Io {
                path: directory.to_path_buf(),
                source,
            })?
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|entry_path| {
                entry_path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .map(|name| name.ends_with(".module.toml"))
                    .unwrap_or(false)
            })
            .collect::<Vec<_>>();
        paths.sort();

        let mut modules = Vec::with_capacity(paths.len());
        for manifest_path in paths {
            let contents =
                fs::read_to_string(&manifest_path).map_err(|source| RegistryError::Io {
                    path: manifest_path.clone(),
                    source,
                })?;
            modules.push(
                toml::from_str(&contents).map_err(|source| RegistryError::Parse {
                    path: manifest_path,
                    source,
                })?,
            );
        }

        let registry = Self { modules };
        registry.validate()?;
        Ok(registry)
    }

    pub fn modules(&self) -> &[ModuleManifest] {
        &self.modules
    }

    fn validate(&self) -> Result<(), RegistryError> {
        if self.modules.is_empty() {
            return Err(RegistryError::Invalid(
                "no subsystem manifests found".into(),
            ));
        }

        let mut ids = BTreeSet::new();
        let mut schemas = BTreeSet::new();
        let mut roles = BTreeSet::new();
        for module in &self.modules {
            if !ids.insert(module.id.as_str()) {
                return Err(invalid(module, "duplicate module id"));
            }
            if !schemas.insert(module.database.schema.as_str()) {
                return Err(invalid(module, "duplicate module schema"));
            }
            if !roles.insert(module.database.role.as_str()) {
                return Err(invalid(module, "duplicate database role"));
            }
            validate_module(module)?;
        }
        Ok(())
    }
}

fn invalid(module: &ModuleManifest, reason: &str) -> RegistryError {
    RegistryError::Invalid(format!("{}: {reason}", module.id))
}

fn validate_module(module: &ModuleManifest) -> Result<(), RegistryError> {
    if module.module_api != 1
        || module.version.is_empty()
        || module.name_zh.is_empty()
        || module.name_en.is_empty()
    {
        return Err(invalid(module, "invalid identity or module API"));
    }
    if module.integration_status != "source_integrated" {
        return Err(invalid(module, "source integration state is invalid"));
    }
    if module.verification.source != "verified"
        || module.verification.database != "verified"
        || !matches!(module.verification.runtime.as_str(), "pending" | "verified")
        || !matches!(module.verification.e2e.as_str(), "pending" | "verified")
    {
        return Err(invalid(module, "verification state is invalid"));
    }
    // 业务模块只接受所属组织的准确仓库与路径，不以账号前缀代替来源身份。
    let repository = match module.id.as_str() {
        "hi_events" => "Hi.Events",
        "kamra" => "kamra-pms",
        "ury" | "voyant" => module.id.as_str(),
        _ => return Err(invalid(module, "unknown source module")),
    };
    if module.source.repository != format!("https://github.com/tuyutata/{repository}")
        || module.source.path != format!("upstream/{}", module.id)
        || module.source.commit.len() != 40
        || !module.source.commit.bytes().all(|value| value.is_ascii_digit() || (b'a'..=b'f').contains(&value))
    {
        return Err(invalid(module, "source is not the pinned module fork"));
    }
    if module.runtime.family.is_empty()
        || module.runtime.build.is_empty()
        || module.runtime.start.is_empty()
    {
        return Err(invalid(module, "runtime contract is incomplete"));
    }

    let locales = module
        .localization
        .supported
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    if module.localization.default != "zh-CN" || locales != BTreeSet::from(["en", "zh-CN"]) {
        return Err(invalid(
            module,
            "locale contract must be Chinese-default and English",
        ));
    }
    if module.authentication.administrator != "tuyu_sr25519_local_qr"
        || module.authentication.staff != "upstream_native"
    {
        return Err(invalid(module, "account boundary is invalid"));
    }
    if module.access.employee_access != "lan_browser"
        || !module.access.https_required
        || module.access.public_access
        || !module.access.gateway_only
    {
        return Err(invalid(
            module,
            "employee access must use the LAN HTTPS gateway",
        ));
    }
    if module.database.engine != "postgresql"
        || module.database.database != DATABASE_NAME
        || module.database.schema == "public"
        || !module.database.schema.starts_with("module_")
        || module.database.isolated_database
        || module.database.additional_persistent_database
    {
        return Err(invalid(
            module,
            "module must use the single PostgreSQL database and an isolated schema",
        ));
    }
    if !module.orders.owns_orders || module.orders.event_contract != "tuyubooking.order.v1" {
        return Err(invalid(module, "order ownership contract is invalid"));
    }
    Ok(())
}

#[derive(Debug, Error)]
pub enum RegistryError {
    #[error("cannot access module contract at {path}: {source}")]
    Io {
        path: PathBuf,
        source: std::io::Error,
    },
    #[error("cannot parse module contract at {path}: {source}")]
    Parse {
        path: PathBuf,
        source: toml::de::Error,
    },
    #[error("invalid module registry: {0}")]
    Invalid(String),
}

#[cfg(test)]
mod tests {
    use super::PlatformAccountPolicy;

    #[test]
    fn all_local_administrators_have_equal_platform_access() {
        let policy = PlatformAccountPolicy::default();
        assert!(policy.administrators_have_equal_access);
        assert_eq!(policy.authentication, "tuyu_sr25519");
    }
}
