//! Single application-service boundary used by the future Flutter FFI layer.

mod account;
mod command;
mod module_access_service;
mod response;
mod startup;

pub use account::{
    add_administrator, administrator_state, delete_administrator, initialize_administrator,
    list_administrators, rename_administrator, set_administrator_status,
};
pub use command::{AppLocale, CommandCoordinator, CommandDisposition, CommandEnvelope};
pub use module_access_service::ModuleAccessService;
pub use response::{ApplicationError, CommandResponse, ErrorCode, EventSummary, LocalizedMessage};
pub use startup::{ApplicationBootstrap, ApplicationRuntime};
pub use tuyu_account::{
    AdministratorAssertion, AdministratorState, AdministratorView, AuthenticatedSession,
    LoginChallenge as QrLoginChallenge, LoginResponse as QrLoginResponse,
    VerifiedAdministrator as VerifiedLocalAdministrator, MAXIMUM_ADMINISTRATORS,
    MINIMUM_ACTIVE_ADMINISTRATORS,
};

use crate::core::EntityId;
use crate::storage::PostgresConnection;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Subsystem {
    Hotel,
    Restaurant,
    Tour,
    Ticket,
}

impl Subsystem {
    pub const ALL: [Self; 4] = [Self::Hotel, Self::Restaurant, Self::Tour, Self::Ticket];

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Hotel => "hotel",
            Self::Restaurant => "restaurant",
            Self::Tour => "tour",
            Self::Ticket => "ticket",
        }
    }
}

#[derive(Clone)]
pub struct ApplicationContext {
    pub(crate) database: Arc<Mutex<PostgresConnection>>,
    pub(crate) account: Arc<tuyu_account::AccountService>,
}

impl ApplicationContext {
    fn authorize(&self, session_id: EntityId) -> Result<AuthenticatedSession, ApplicationError> {
        let session = self.account.require_session()?;
        if session.id != session_id.into_uuid() {
            return Err(ApplicationError::new(
                ErrorCode::SessionMismatch,
                LocalizedMessage::new(
                    "session.mismatch",
                    "会话不匹配",
                    "The session does not match",
                ),
            ));
        }
        Ok(session)
    }

    fn service_access(&self, subsystem: Subsystem) -> Result<ServiceAccess, ApplicationError> {
        let session = self.account.require_session()?;
        Ok(ServiceAccess {
            subsystem,
            session_id: EntityId::from_uuid(session.id),
            administrator_id: EntityId::from_uuid(session.administrator_id),
        })
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ServiceAccess {
    pub subsystem: Subsystem,
    pub session_id: EntityId,
    pub administrator_id: EntityId,
}

#[derive(Clone)]
pub struct ApplicationServices {
    context: ApplicationContext,
    pub hotel: ModuleAccessService,
    pub restaurant: ModuleAccessService,
    pub tour: ModuleAccessService,
    pub ticket: ModuleAccessService,
}

impl ApplicationServices {
    fn new(context: ApplicationContext) -> Self {
        Self {
            hotel: ModuleAccessService::new(context.clone(), Subsystem::Hotel),
            restaurant: ModuleAccessService::new(context.clone(), Subsystem::Restaurant),
            tour: ModuleAccessService::new(context.clone(), Subsystem::Tour),
            ticket: ModuleAccessService::new(context.clone(), Subsystem::Ticket),
            context,
        }
    }

    pub fn login_local_administrator(
        &self,
        identity: VerifiedLocalAdministrator,
    ) -> Result<AuthenticatedSession, ApplicationError> {
        self.context
            .account
            .login_verified(identity)
            .map_err(Into::into)
    }

    pub fn logout(&self) -> Result<(), ApplicationError> {
        self.context.account.logout().map_err(Into::into)
    }

    pub fn require_authenticated_administrator(&self) -> Result<(), ApplicationError> {
        self.context.account.require_session()?;
        Ok(())
    }

    pub async fn create_qr_login_challenge(&self) -> Result<QrLoginChallenge, ApplicationError> {
        let database = self.context.database.lock().await;
        self.context
            .account
            .create_administrator_challenge(&database.client)
            .await
            .map_err(Into::into)
    }

    pub async fn complete_qr_login(
        &self,
        response: QrLoginResponse,
    ) -> Result<AuthenticatedSession, ApplicationError> {
        let database = self.context.database.lock().await;
        self.context
            .account
            .complete_login(&database.client, response)
            .await
            .map_err(Into::into)
    }

    /// Creates a short-lived, one-time assertion for the local HTTPS business
    /// runtime. The current verified Tuyu administrator session is the only
    /// authority allowed to mint this browser hand-off token.
    pub async fn create_administrator_assertion(
        &self,
    ) -> Result<AdministratorAssertion, ApplicationError> {
        let database = self.context.database.lock().await;
        self.context
            .account
            .assertion(&database.client)
            .await
            .map_err(Into::into)
    }

    pub const fn available_subsystems(&self) -> [Subsystem; 4] {
        Subsystem::ALL
    }

    pub fn context(&self) -> &ApplicationContext {
        &self.context
    }
}
