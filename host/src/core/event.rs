use crate::core::EntityId;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use time::OffsetDateTime;

/// Logical owner of a domain event.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Domain {
    Core,
    Hotel,
    Restaurant,
    Tour,
    Ticket,
}

/// Actor recorded in audit and state-transition events.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AuditActor {
    pub staff_id: EntityId,
    pub tuyu_id: String,
}

/// Durable event emitted by a domain aggregate.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DomainEvent {
    pub event_id: EntityId,
    pub domain_name: Domain,
    pub aggregate_type: String,
    pub aggregate_id: EntityId,
    pub event_type: String,
    pub event_data: Value,
    pub occurred_at: OffsetDateTime,
}

impl DomainEvent {
    pub fn new(
        domain_name: Domain,
        aggregate_type: impl Into<String>,
        aggregate_id: EntityId,
        event_type: impl Into<String>,
        event_data: Value,
        occurred_at: OffsetDateTime,
    ) -> Self {
        Self {
            event_id: EntityId::new(),
            domain_name,
            aggregate_type: aggregate_type.into(),
            aggregate_id,
            event_type: event_type.into(),
            event_data,
            occurred_at,
        }
    }
}
