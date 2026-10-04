use thiserror::Error;

/// Errors shared by all TuyuBooking domain modules.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum DomainError {
    #[error("currency code must contain exactly three uppercase ASCII letters")]
    InvalidCurrencyCode,
    #[error("money values use different currencies")]
    CurrencyMismatch,
    #[error("the requested state transition is not allowed")]
    InvalidStateTransition,
    #[error("the optimistic-lock version overflowed")]
    VersionOverflow,
    #[error("the stored aggregate version differs from the expected version")]
    VersionConflict,
    #[error("the requested entity was not found")]
    NotFound,
    #[error("the command key is invalid")]
    InvalidCommandKey,
    #[error("the in-memory repository lock is unavailable")]
    RepositoryUnavailable,
}
