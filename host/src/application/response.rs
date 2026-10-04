use crate::core::{DomainError, EntityId, Version};
use crate::storage::StorageError;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    NotAuthenticated,
    InvalidIdentity,
    SessionMismatch,
    InvalidCommand,
    Conflict,
    StorageUnavailable,
    StartupFailed,
    Internal,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct LocalizedMessage {
    pub key: String,
    pub zh_cn: String,
    pub en_us: String,
}

impl LocalizedMessage {
    pub fn new(key: impl Into<String>, zh_cn: impl Into<String>, en_us: impl Into<String>) -> Self {
        Self {
            key: key.into(),
            zh_cn: zh_cn.into(),
            en_us: en_us.into(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ApplicationError {
    pub code: ErrorCode,
    pub message: LocalizedMessage,
}

impl ApplicationError {
    pub fn new(code: ErrorCode, message: LocalizedMessage) -> Self {
        Self { code, message }
    }

    pub fn not_authenticated() -> Self {
        Self::new(
            ErrorCode::NotAuthenticated,
            LocalizedMessage::new(
                "session.not_authenticated",
                "请先使用管理员二维码签名登录",
                "Sign in with an administrator QR signature first",
            ),
        )
    }

    pub fn internal(key: &str, zh_cn: &str, en_us: &str) -> Self {
        Self::new(
            ErrorCode::Internal,
            LocalizedMessage::new(key, zh_cn, en_us),
        )
    }
}

impl From<DomainError> for ApplicationError {
    fn from(error: DomainError) -> Self {
        let (code, key, zh_cn, en_us) = match error {
            DomainError::VersionConflict => (
                ErrorCode::Conflict,
                "domain.version_conflict",
                "数据已被其他操作更新",
                "The data was updated by another operation",
            ),
            _ => (
                ErrorCode::InvalidCommand,
                "domain.command_rejected",
                "当前操作不允许执行",
                "The command is not allowed",
            ),
        };
        Self::new(code, LocalizedMessage::new(key, zh_cn, en_us))
    }
}

impl From<StorageError> for ApplicationError {
    fn from(error: StorageError) -> Self {
        if let StorageError::Domain(domain) = error {
            return domain.into();
        }

        Self::new(
            ErrorCode::StorageUnavailable,
            LocalizedMessage::new(
                "storage.unavailable",
                "本地数据服务暂时不可用",
                "The local data service is unavailable",
            ),
        )
    }
}

impl From<tuyu_account::Error> for ApplicationError {
    fn from(error: tuyu_account::Error) -> Self {
        let code = match error.kind {
            tuyu_account::ErrorKind::NotAuthenticated => ErrorCode::NotAuthenticated,
            tuyu_account::ErrorKind::InvalidIdentity => ErrorCode::InvalidIdentity,
            tuyu_account::ErrorKind::Policy => ErrorCode::InvalidCommand,
            tuyu_account::ErrorKind::Storage => ErrorCode::StorageUnavailable,
            tuyu_account::ErrorKind::Unavailable => ErrorCode::Internal,
        };
        Self::new(
            code,
            LocalizedMessage::new(error.key, error.zh_cn, error.en_us),
        )
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EventSummary {
    pub event_type: String,
    pub aggregate_id: EntityId,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CommandResponse<T> {
    pub value: T,
    pub object_id: Option<EntityId>,
    pub version: Option<Version>,
    pub events: Vec<EventSummary>,
}

impl<T> CommandResponse<T> {
    pub fn new(value: T) -> Self {
        Self {
            value,
            object_id: None,
            version: None,
            events: Vec::new(),
        }
    }
}
