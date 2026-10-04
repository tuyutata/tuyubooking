//! Shared domain primitives used by every TuyuBooking subsystem.

mod clock;
mod command;
mod error;
mod event;
mod id;
mod money;
mod version;

pub use clock::{Clock, FixedClock, SystemClock};
pub use command::{CommandKey, CommandResult};
pub use error::DomainError;
pub use event::{AuditActor, Domain, DomainEvent};
pub use id::EntityId;
pub use money::{CurrencyCode, Money};
pub use version::Version;

/// Validates a requested state transition without mutating the aggregate.
pub trait StateTransition: Sized + Copy {
    fn can_transition_to(self, next: Self) -> bool;

    fn transition_to(self, next: Self) -> Result<Self, DomainError> {
        if self.can_transition_to(next) {
            Ok(next)
        } else {
            Err(DomainError::InvalidStateTransition)
        }
    }
}
