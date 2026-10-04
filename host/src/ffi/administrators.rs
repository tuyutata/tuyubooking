use super::{guard, internal_error, invalid_request, read_input, state, success};
use crate::application::{ApplicationError, AuthenticatedSession, QrLoginResponse};
use crate::core::EntityId;
use serde::{Deserialize, Serialize};
use std::ffi::c_char;
use uuid::Uuid;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AddRequest {
    public_key_qr: String,
    name: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct InitializeRequest {
    response: QrLoginResponse,
    name: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RenameRequest {
    administrator_id: String,
    name: Option<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct StatusRequest {
    administrator_id: String,
    status: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct DeleteRequest {
    administrator_id: String,
}

#[derive(Serialize)]
struct SessionSnapshot {
    session_id: String,
    administrator_id: String,
    administrator_name: Option<String>,
    public_key_fingerprint: String,
}

#[no_mangle]
pub extern "C" fn tuyubooking_administrator_state() -> *mut c_char {
    guard(|| with_services(|services, executor| executor.block_on(services.administrator_state())))
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_initialize_administrator(input: *const c_char) -> *mut c_char {
    guard(|| initialize(read_input(input)?))
}

#[no_mangle]
pub extern "C" fn tuyubooking_list_administrators() -> *mut c_char {
    guard(|| with_services(|services, executor| executor.block_on(services.list_administrators())))
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_add_administrator(input: *const c_char) -> *mut c_char {
    guard(|| add(read_input(input)?))
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_update_administrator_name(
    input: *const c_char,
) -> *mut c_char {
    guard(|| rename(read_input(input)?))
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_update_administrator_status(
    input: *const c_char,
) -> *mut c_char {
    guard(|| set_status(read_input(input)?))
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_delete_administrator(input: *const c_char) -> *mut c_char {
    guard(|| delete(read_input(input)?))
}

fn initialize(input: &str) -> Result<String, ApplicationError> {
    let request: InitializeRequest = serde_json::from_str(input).map_err(invalid_request)?;
    with_services(|services, executor| {
        let session = executor.block_on(
            services.initialize_administrator(request.response, request.name.as_deref()),
        )?;
        Ok(SessionSnapshot::from(session))
    })
}

fn add(input: &str) -> Result<String, ApplicationError> {
    let request: AddRequest = serde_json::from_str(input).map_err(invalid_request)?;
    with_services(|services, executor| {
        executor
            .block_on(services.add_administrator(&request.public_key_qr, request.name.as_deref()))
    })
}

fn rename(input: &str) -> Result<String, ApplicationError> {
    let request: RenameRequest = serde_json::from_str(input).map_err(invalid_request)?;
    let administrator_id = parse_id(&request.administrator_id)?;
    with_services(|services, executor| {
        executor.block_on(services.rename_administrator(administrator_id, request.name.as_deref()))
    })
}

fn set_status(input: &str) -> Result<String, ApplicationError> {
    let request: StatusRequest = serde_json::from_str(input).map_err(invalid_request)?;
    let administrator_id = parse_id(&request.administrator_id)?;
    with_services(|services, executor| {
        executor.block_on(services.set_administrator_status(administrator_id, &request.status))
    })
}

fn delete(input: &str) -> Result<String, ApplicationError> {
    let request: DeleteRequest = serde_json::from_str(input).map_err(invalid_request)?;
    let administrator_id = parse_id(&request.administrator_id)?;
    with_services(|services, executor| {
        executor.block_on(services.delete_administrator(administrator_id))?;
        Ok(serde_json::json!({"deleted": true}))
    })
}

fn with_services<T: Serialize>(
    operation: impl FnOnce(
        &crate::application::ApplicationServices,
        &tokio::runtime::Runtime,
    ) -> Result<T, ApplicationError>,
) -> Result<String, ApplicationError> {
    let guard = state().lock().map_err(|_| internal_error())?;
    let services = guard
        .services
        .as_ref()
        .ok_or_else(super::startup_required)?;
    let executor = guard
        .executor
        .as_ref()
        .ok_or_else(super::startup_required)?;
    Ok(success(operation(services, executor)?))
}

fn parse_id(value: &str) -> Result<EntityId, ApplicationError> {
    Uuid::parse_str(value)
        .map(EntityId::from_uuid)
        .map_err(invalid_request)
}

impl From<AuthenticatedSession> for SessionSnapshot {
    fn from(value: AuthenticatedSession) -> Self {
        Self {
            session_id: value.id.to_string(),
            administrator_id: value.administrator_id.to_string(),
            administrator_name: value.administrator_name,
            public_key_fingerprint: value.public_key_fingerprint,
        }
    }
}
