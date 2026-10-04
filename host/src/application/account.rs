//! 途遇商家端到全途遇账户模块的产品适配层。

use tuyu_account::{AdministratorState, AdministratorView, AuthenticatedSession, LoginResponse};

use super::{ApplicationContext, ApplicationError};
use crate::core::EntityId;

pub async fn administrator_state(
    context: &ApplicationContext,
) -> Result<AdministratorState, ApplicationError> {
    let database = context.database.lock().await;
    context
        .account
        .state(&database.client)
        .await
        .map_err(Into::into)
}

pub async fn initialize_administrator(
    context: &ApplicationContext,
    response: LoginResponse,
    name: Option<&str>,
) -> Result<AuthenticatedSession, ApplicationError> {
    let mut database = context.database.lock().await;
    context
        .account
        .initialize(&mut database.client, response, name)
        .await
        .map_err(Into::into)
}

pub async fn list_administrators(
    context: &ApplicationContext,
) -> Result<Vec<AdministratorView>, ApplicationError> {
    let database = context.database.lock().await;
    context
        .account
        .list(&database.client)
        .await
        .map_err(Into::into)
}

pub async fn add_administrator(
    context: &ApplicationContext,
    account_qr: &str,
    name: Option<&str>,
) -> Result<AdministratorView, ApplicationError> {
    let mut database = context.database.lock().await;
    context
        .account
        .add(&mut database.client, account_qr, name)
        .await
        .map_err(Into::into)
}

pub async fn rename_administrator(
    context: &ApplicationContext,
    administrator_id: EntityId,
    name: Option<&str>,
) -> Result<AdministratorView, ApplicationError> {
    let database = context.database.lock().await;
    context
        .account
        .rename(&database.client, administrator_id.into_uuid(), name)
        .await
        .map_err(Into::into)
}

pub async fn set_administrator_status(
    context: &ApplicationContext,
    administrator_id: EntityId,
    status: &str,
) -> Result<AdministratorView, ApplicationError> {
    let mut database = context.database.lock().await;
    context
        .account
        .set_status(&mut database.client, administrator_id.into_uuid(), status)
        .await
        .map_err(Into::into)
}

pub async fn delete_administrator(
    context: &ApplicationContext,
    administrator_id: EntityId,
) -> Result<(), ApplicationError> {
    let mut database = context.database.lock().await;
    context
        .account
        .delete(&mut database.client, administrator_id.into_uuid())
        .await
        .map_err(Into::into)
}

impl super::ApplicationServices {
    pub async fn administrator_state(&self) -> Result<AdministratorState, ApplicationError> {
        administrator_state(&self.context).await
    }

    pub async fn initialize_administrator(
        &self,
        response: LoginResponse,
        name: Option<&str>,
    ) -> Result<AuthenticatedSession, ApplicationError> {
        initialize_administrator(&self.context, response, name).await
    }

    pub async fn list_administrators(&self) -> Result<Vec<AdministratorView>, ApplicationError> {
        list_administrators(&self.context).await
    }

    pub async fn add_administrator(
        &self,
        account_qr: &str,
        name: Option<&str>,
    ) -> Result<AdministratorView, ApplicationError> {
        add_administrator(&self.context, account_qr, name).await
    }

    pub async fn rename_administrator(
        &self,
        administrator_id: EntityId,
        name: Option<&str>,
    ) -> Result<AdministratorView, ApplicationError> {
        rename_administrator(&self.context, administrator_id, name).await
    }

    pub async fn set_administrator_status(
        &self,
        administrator_id: EntityId,
        status: &str,
    ) -> Result<AdministratorView, ApplicationError> {
        set_administrator_status(&self.context, administrator_id, status).await
    }

    pub async fn delete_administrator(
        &self,
        administrator_id: EntityId,
    ) -> Result<(), ApplicationError> {
        delete_administrator(&self.context, administrator_id).await
    }
}
