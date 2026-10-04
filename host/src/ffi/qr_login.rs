use super::{guard, internal_error, invalid_request, read_input, state, success};
use crate::application::{ApplicationError, QrLoginResponse};
use serde::Serialize;
use std::ffi::c_char;

#[derive(Serialize)]
struct LoginSnapshot {
    session_id: String,
    administrator_id: String,
    administrator_name: Option<String>,
    public_key_fingerprint: String,
    subsystems: [&'static str; 4],
}

#[no_mangle]
pub extern "C" fn tuyubooking_qr_login_challenge() -> *mut c_char {
    guard(|| {
        let guard = state().lock().map_err(|_| internal_error())?;
        let services = guard
            .services
            .as_ref()
            .ok_or_else(super::startup_required)?;
        let executor = guard
            .executor
            .as_ref()
            .ok_or_else(super::startup_required)?;
        Ok(success(
            executor.block_on(services.create_qr_login_challenge())?,
        ))
    })
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_qr_login_complete(input: *const c_char) -> *mut c_char {
    guard(|| complete(read_input(input)?))
}

fn complete(input: &str) -> Result<String, ApplicationError> {
    let response: QrLoginResponse = serde_json::from_str(input).map_err(invalid_request)?;
    let guard = state().lock().map_err(|_| internal_error())?;
    let services = guard
        .services
        .as_ref()
        .ok_or_else(super::startup_required)?;
    let executor = guard
        .executor
        .as_ref()
        .ok_or_else(super::startup_required)?;
    let session = executor.block_on(services.complete_qr_login(response))?;
    Ok(success(LoginSnapshot {
        session_id: session.id.to_string(),
        administrator_id: session.administrator_id.to_string(),
        administrator_name: session.administrator_name,
        public_key_fingerprint: session.public_key_fingerprint,
        subsystems: ["hotel", "restaurant", "tour", "ticket"],
    }))
}
