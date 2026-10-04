use crate::core::{DomainError, DomainEvent};
use serde::{Deserialize, Serialize};

/// Stable key used to deduplicate a write command.
#[derive(Clone, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct CommandKey(String);

impl CommandKey {
    pub fn new(value: impl Into<String>) -> Result<Self, DomainError> {
        let value = value.into();
        if value.is_empty() || value.len() > 200 {
            Err(DomainError::InvalidCommandKey)
        } else {
            Ok(Self(value))
        }
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Value returned by a command together with durable events to persist.
#[derive(Clone, Debug, PartialEq)]
pub struct CommandResult<T> {
    pub value: T,
    pub events: Vec<DomainEvent>,
}

impl<T> CommandResult<T> {
    pub fn new(value: T, events: Vec<DomainEvent>) -> Self {
        Self { value, events }
    }
}
