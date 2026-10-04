use crate::core::{DomainError, EntityId, Version};
use std::collections::HashMap;
use std::sync::RwLock;

/// Test-only style repository used to exercise optimistic-lock behavior before
/// the PostgreSQL adapter is introduced.
pub struct InMemoryRepository<Aggregate> {
    entries: RwLock<HashMap<EntityId, (Aggregate, Version)>>,
}

impl<Aggregate> Default for InMemoryRepository<Aggregate> {
    fn default() -> Self {
        Self {
            entries: RwLock::new(HashMap::new()),
        }
    }
}

impl<Aggregate> InMemoryRepository<Aggregate>
where
    Aggregate: Clone,
{
    pub fn load(&self, id: EntityId) -> Result<Option<(Aggregate, Version)>, DomainError> {
        let entries = self
            .entries
            .read()
            .map_err(|_| DomainError::RepositoryUnavailable)?;
        Ok(entries.get(&id).cloned())
    }

    pub fn save(
        &self,
        id: EntityId,
        aggregate: Aggregate,
        expected_version: Version,
    ) -> Result<Version, DomainError> {
        let mut entries = self
            .entries
            .write()
            .map_err(|_| DomainError::RepositoryUnavailable)?;

        match entries.get(&id) {
            None if expected_version == Version::INITIAL => {
                entries.insert(id, (aggregate, Version::INITIAL));
                Ok(Version::INITIAL)
            }
            Some((_, stored_version)) if *stored_version == expected_version => {
                let next = stored_version.next()?;
                entries.insert(id, (aggregate, next));
                Ok(next)
            }
            _ => Err(DomainError::VersionConflict),
        }
    }
}
