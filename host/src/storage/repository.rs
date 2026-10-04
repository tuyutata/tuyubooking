use crate::core::{DomainError, EntityId, Version};
use async_trait::async_trait;

/// Persistence boundary implemented later by the single PostgreSQL adapter.
#[async_trait]
pub trait AggregateRepository<Aggregate>: Send + Sync
where
    Aggregate: Send + Sync,
{
    async fn load(&self, id: EntityId) -> Result<Option<Aggregate>, DomainError>;

    async fn save(
        &self,
        aggregate: &Aggregate,
        expected_version: Version,
    ) -> Result<Version, DomainError>;
}
