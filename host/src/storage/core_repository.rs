use crate::core::{DomainEvent, EntityId};
use crate::storage::StorageError;
use serde_json::Value;
use std::collections::BTreeSet;
use time::OffsetDateTime;
use tokio_postgres::GenericClient;

#[derive(Clone, Debug, PartialEq)]
pub enum IdempotencyClaim {
    Acquired,
    InProgress,
    Completed {
        response_status: i32,
        response_body: Value,
    },
}

pub struct CoreRepository;

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct BusinessModuleConfiguration {
    pub configured: bool,
    pub enabled_modules: BTreeSet<String>,
}

impl CoreRepository {
    pub async fn business_module_configuration(
        client: &impl GenericClient,
        installation_id: EntityId,
    ) -> Result<BusinessModuleConfiguration, StorageError> {
        let rows = client
            .query(
                "SELECT module_key, is_enabled
                 FROM tuyu_core.modules
                 WHERE installation_id = $1
                 ORDER BY module_key",
                &[&installation_id.into_uuid()],
            )
            .await?;
        let enabled_modules = rows
            .iter()
            .filter(|row| row.get::<_, bool>("is_enabled"))
            .map(|row| row.get::<_, String>("module_key"))
            .collect();
        Ok(BusinessModuleConfiguration {
            configured: !rows.is_empty(),
            enabled_modules,
        })
    }

    /// 只更新四个模块的启用状态；上游业务记录仍由各模块拥有。
    pub async fn set_business_modules(
        client: &impl GenericClient,
        installation_id: EntityId,
        enabled_modules: &BTreeSet<String>,
    ) -> Result<(), StorageError> {
        let enabled_modules = enabled_modules.iter().cloned().collect::<Vec<_>>();
        client
            .execute(
                "INSERT INTO tuyu_core.modules
                     (installation_id, module_key, is_enabled)
                 SELECT $1, module_key, module_key = ANY($2)
                 FROM unnest(ARRAY['hotel', 'restaurant', 'tour', 'ticket']::text[])
                      AS module_key
                 ON CONFLICT (installation_id, module_key) DO UPDATE
                 SET is_enabled = EXCLUDED.is_enabled",
                &[&installation_id.into_uuid(), &enabled_modules],
            )
            .await?;
        Ok(())
    }

    /// 幂等记录直接使用安装实例、请求作用域和请求键，不另造记录标识。
    pub async fn claim_idempotency(
        client: &impl GenericClient,
        installation_id: EntityId,
        request_scope: &str,
        request_key: &str,
        request_hash: &str,
        expires_at: OffsetDateTime,
    ) -> Result<IdempotencyClaim, StorageError> {
        let inserted = client
            .execute(
                "INSERT INTO tuyu_core.requests
                 (installation_id, request_scope, request_key, request_hash, expires_at)
                 VALUES ($1, $2, $3, $4, $5)
                 ON CONFLICT (installation_id, request_scope, request_key) DO NOTHING",
                &[
                    &installation_id.into_uuid(),
                    &request_scope,
                    &request_key,
                    &request_hash,
                    &expires_at,
                ],
            )
            .await?;

        if inserted == 1 {
            return Ok(IdempotencyClaim::Acquired);
        }

        let row = client
            .query_one(
                "SELECT response_status, response_body
                 FROM tuyu_core.requests
                 WHERE installation_id = $1 AND request_scope = $2 AND request_key = $3",
                &[&installation_id.into_uuid(), &request_scope, &request_key],
            )
            .await?;

        let status: Option<i32> = row.get(0);
        let body: Option<Value> = row.get(1);
        match (status, body) {
            (Some(response_status), Some(response_body)) => Ok(IdempotencyClaim::Completed {
                response_status,
                response_body,
            }),
            _ => Ok(IdempotencyClaim::InProgress),
        }
    }

    pub async fn complete_idempotency(
        client: &impl GenericClient,
        installation_id: EntityId,
        request_scope: &str,
        request_key: &str,
        response_status: i32,
        response_body: &Value,
    ) -> Result<(), StorageError> {
        client
            .execute(
                "UPDATE tuyu_core.requests
                 SET response_status = $4, response_body = $5, updated_at = CURRENT_TIMESTAMP,
                     row_version = row_version + 1
                 WHERE installation_id = $1 AND request_scope = $2 AND request_key = $3",
                &[
                    &installation_id.into_uuid(),
                    &request_scope,
                    &request_key,
                    &response_status,
                    response_body,
                ],
            )
            .await?;
        Ok(())
    }

    pub async fn append_event(
        client: &(impl GenericClient + Sync),
        installation_id: EntityId,
        event: &DomainEvent,
    ) -> Result<(), StorageError> {
        client
            .execute(
                "INSERT INTO tuyu_core.events
                 (event_id, installation_id, domain_name, aggregate_type, aggregate_id, event_type,
                  event_data, occurred_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
                &[
                    &event.event_id.into_uuid(),
                    &installation_id.into_uuid(),
                    &domain_name(event),
                    &event.aggregate_type,
                    &event.aggregate_id.into_uuid(),
                    &event.event_type,
                    &event.event_data,
                    &event.occurred_at,
                ],
            )
            .await?;
        Ok(())
    }

    pub async fn append_audit(
        client: &(impl GenericClient + Sync),
        installation_id: EntityId,
        actor_id: Option<EntityId>,
        domain_name: &str,
        audit_action: &str,
        object_type: &str,
        object_id: EntityId,
        audit_reason: Option<&str>,
        occurred_at: OffsetDateTime,
    ) -> Result<(), StorageError> {
        let audit_id = EntityId::new();
        let actor_uuid = actor_id.map(EntityId::into_uuid);
        client
            .execute(
                "INSERT INTO tuyu_core.audits
                 (audit_id, installation_id, actor_id, domain_name, audit_action, object_type, object_id,
                  audit_reason, occurred_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
                &[
                    &audit_id.into_uuid(),
                    &installation_id.into_uuid(),
                    &actor_uuid,
                    &domain_name,
                    &audit_action,
                    &object_type,
                    &object_id.into_uuid(),
                    &audit_reason,
                    &occurred_at,
                ],
            )
            .await?;
        Ok(())
    }
}

fn domain_name(event: &DomainEvent) -> &'static str {
    match event.domain_name {
        crate::core::Domain::Core => "core",
        crate::core::Domain::Hotel => "hotel",
        crate::core::Domain::Restaurant => "restaurant",
        crate::core::Domain::Tour => "tour",
        crate::core::Domain::Ticket => "ticket",
    }
}
