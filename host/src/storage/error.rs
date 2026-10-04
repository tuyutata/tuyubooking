use crate::core::DomainError;
use std::path::PathBuf;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StorageError {
    #[error("PostgreSQL executable is missing: {0}")]
    MissingExecutable(PathBuf),

    #[error("the database data directory cannot be inside the installation directory")]
    DataDirectoryInsideInstallation,

    #[error("the PostgreSQL runtime command failed: {0}")]
    RuntimeCommand(String),

    #[error("database I/O failed")]
    Io(#[from] std::io::Error),

    #[error("PostgreSQL operation failed")]
    Postgres(#[from] tokio_postgres::Error),

    #[error("domain operation failed")]
    Domain(#[from] DomainError),

    #[error("stored data is invalid: {0}")]
    InvalidData(String),

    #[error("schema checksum mismatch for {schema_name}")]
    SchemaChecksumMismatch { schema_name: String },

    #[error("schema initialization failed for {schema_name}: {message}")]
    SchemaExecution {
        schema_name: String,
        message: String,
    },

    #[error("the PostgreSQL runtime has already started")]
    AlreadyStarted,

    #[error("the PostgreSQL runtime is not running")]
    NotRunning,
}
