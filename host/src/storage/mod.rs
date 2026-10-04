//! PostgreSQL runtime、最终结构基线、仓储与持久化合同。

mod core_repository;
mod error;
mod memory;
mod postgres;
mod repository;
mod schema;
mod schema_executor;

pub use crate::runtime::{path_is_inside, ConnectionMode, PostgresRuntime, PostgresRuntimeConfig};
pub use core_repository::{BusinessModuleConfiguration, CoreRepository, IdempotencyClaim};
pub use error::StorageError;
pub use memory::InMemoryRepository;
pub use postgres::PostgresConnection;
pub use repository::AggregateRepository;
pub use schema::{sha256_hex, EmbeddedSchema, CORE_SCHEMA};
pub use schema_executor::SchemaExecutor;
