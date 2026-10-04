use time::OffsetDateTime;
use tuyubooking_native::core::{Clock, DomainError, EntityId, FixedClock, Version};
use tuyubooking_native::storage::InMemoryRepository;

fn now() -> OffsetDateTime {
    OffsetDateTime::from_unix_timestamp(1_800_000_000).unwrap()
}

#[test]
fn fixed_clock_is_deterministic() {
    let clock = FixedClock::new(now());
    assert_eq!(clock.now(), now());
}

#[test]
fn in_memory_repository_enforces_optimistic_locking() {
    let repository = InMemoryRepository::default();
    let id = EntityId::new();

    assert_eq!(
        repository.save(id, "first".to_owned(), Version::INITIAL),
        Ok(Version::INITIAL)
    );
    assert_eq!(
        repository.save(id, "second".to_owned(), Version::INITIAL),
        Ok(Version::new(2).unwrap())
    );
    assert_eq!(
        repository.save(id, "stale".to_owned(), Version::INITIAL),
        Err(DomainError::VersionConflict)
    );
}
