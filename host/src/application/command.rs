use crate::application::{
    ApplicationContext, ApplicationError, AuthenticatedSession, ErrorCode, LocalizedMessage,
    Subsystem,
};
use crate::core::{CommandKey, EntityId};
use crate::storage::{CoreRepository, IdempotencyClaim};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use time::{Duration, OffsetDateTime};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum AppLocale {
    #[serde(rename = "zh-CN")]
    ZhCn,
    #[serde(rename = "en-US")]
    EnUs,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CommandEnvelope<T> {
    pub command_id: EntityId,
    pub idempotency_key: CommandKey,
    pub session_id: EntityId,
    pub subsystem: Subsystem,
    pub command_type: String,
    pub payload: T,
    pub client_time: OffsetDateTime,
    pub locale: AppLocale,
}

#[derive(Clone, Debug, PartialEq)]
pub enum CommandDisposition {
    Acquired,
    InProgress,
    Completed {
        response_status: i32,
        response_body: Value,
    },
}

pub struct CommandCoordinator;

impl CommandCoordinator {
    pub async fn begin<T>(
        context: &ApplicationContext,
        envelope: &CommandEnvelope<T>,
        request_hash: &str,
    ) -> Result<(AuthenticatedSession, CommandDisposition), ApplicationError> {
        if envelope.command_type.is_empty() || request_hash.len() != 64 {
            return Err(ApplicationError::new(
                ErrorCode::InvalidCommand,
                LocalizedMessage::new("command.invalid", "命令格式无效", "The command is invalid"),
            ));
        }

        let session = context.authorize(envelope.session_id)?;
        let database = context.database.lock().await;
        let claim = CoreRepository::claim_idempotency(
            &database.client,
            EntityId::from_uuid(session.installation_id),
            EntityId::new(),
            envelope.subsystem.as_str(),
            envelope.idempotency_key.as_str(),
            request_hash,
            envelope.client_time + Duration::minutes(10),
        )
        .await?;

        let disposition = match claim {
            IdempotencyClaim::Acquired => CommandDisposition::Acquired,
            IdempotencyClaim::InProgress => CommandDisposition::InProgress,
            IdempotencyClaim::Completed {
                response_status,
                response_body,
            } => CommandDisposition::Completed {
                response_status,
                response_body,
            },
        };
        drop(database);
        Ok((session, disposition))
    }

    pub async fn complete<T>(
        context: &ApplicationContext,
        envelope: &CommandEnvelope<T>,
        response_status: i32,
        response_body: &Value,
    ) -> Result<(), ApplicationError> {
        let session = context.authorize(envelope.session_id)?;
        let database = context.database.lock().await;
        CoreRepository::complete_idempotency(
            &database.client,
            EntityId::from_uuid(session.installation_id),
            envelope.subsystem.as_str(),
            envelope.idempotency_key.as_str(),
            response_status,
            response_body,
        )
        .await?;
        Ok(())
    }
}
