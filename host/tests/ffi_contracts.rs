use std::ffi::{CStr, CString};
use tuyubooking_native::ffi::{
    contract_document, tuyubooking_administrator_state, tuyubooking_configure_modules,
    tuyubooking_initialize_administrator, tuyubooking_qr_login_challenge,
    tuyubooking_qr_login_complete, tuyubooking_restart_module, tuyubooking_runtime_snapshot,
    tuyubooking_string_free,
};

#[test]
fn contract_exposes_one_app_and_all_four_subsystems() {
    let contract: serde_json::Value = serde_json::from_str(&contract_document()).unwrap();
    assert_eq!(contract["data"]["product"], "TuyuBooking");
    assert_eq!(contract["data"]["product_code"], "TuyuBooking");
    assert_eq!(
        contract["data"]["subsystems"],
        serde_json::json!(["hotel", "restaurant", "tour", "ticket"])
    );
    assert_eq!(contract["data"]["private_key_fields_allowed"], false);
    assert_eq!(contract["data"]["contract_version"], 8);
    assert_eq!(contract["data"]["administrator_min_active"], 1);
    assert_eq!(contract["data"]["administrator_max_total"], 99);
    assert_eq!(contract["data"]["administrator_public_key_mutable"], false);
    assert_eq!(contract["data"]["login_protocol"], "TUYU");
    assert_eq!(
        contract["data"]["runtime_controls"],
        serde_json::json!([
            "snapshot",
            "restart_module",
            "configure_modules",
            "employee_gateway_snapshot",
            "enable_employee_gateway",
            "disable_employee_gateway"
        ])
    );
}

#[test]
fn runtime_controls_require_the_unified_runtime_to_be_started() {
    let snapshot_pointer = tuyubooking_runtime_snapshot();
    let snapshot = unsafe { CStr::from_ptr(snapshot_pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(snapshot_pointer) };
    let snapshot: serde_json::Value = serde_json::from_str(&snapshot).unwrap();
    assert_eq!(snapshot["error"]["message"]["key"], "ffi.startup_required");

    let input = CString::new(r#"{"module":"hotel"}"#).unwrap();
    let restart_pointer = unsafe { tuyubooking_restart_module(input.as_ptr()) };
    let restart = unsafe { CStr::from_ptr(restart_pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(restart_pointer) };
    let restart: serde_json::Value = serde_json::from_str(&restart).unwrap();
    assert_eq!(restart["error"]["message"]["key"], "ffi.startup_required");

    let input = CString::new(r#"{"modules":["restaurant"]}"#).unwrap();
    let configure_pointer = unsafe { tuyubooking_configure_modules(input.as_ptr()) };
    let configure = unsafe { CStr::from_ptr(configure_pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(configure_pointer) };
    let configure: serde_json::Value = serde_json::from_str(&configure).unwrap();
    assert_eq!(configure["error"]["message"]["key"], "ffi.startup_required");
}

#[test]
fn qr_login_dto_rejects_private_key_material() {
    let input = CString::new(
        serde_json::json!({
            "p": "TUYU",
            "v": 1,
            "k": 2,
            "i": "challenge",
            "e": 2_000_000_000,
            "b": {"u": "public-key", "s": "signature"},
            "private_key": "must-never-cross-the-business-ffi"
        })
        .to_string(),
    )
    .unwrap();
    let pointer = unsafe { tuyubooking_qr_login_complete(input.as_ptr()) };
    let response = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(pointer) };
    let json: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(json["ok"], false);
    assert_eq!(json["error"]["message"]["key"], "ffi.invalid_request");
}

#[test]
fn qr_login_challenge_requires_the_unified_runtime_to_be_started() {
    let pointer = tuyubooking_qr_login_challenge();
    let response = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(pointer) };
    let json: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(json["error"]["message"]["key"], "ffi.startup_required");
}

#[test]
fn administrator_state_requires_the_unified_runtime_to_be_started() {
    let pointer = tuyubooking_administrator_state();
    let response = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(pointer) };
    let json: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(json["error"]["message"]["key"], "ffi.startup_required");
}

#[test]
fn administrator_initialization_dto_rejects_extra_identity_material() {
    let input = CString::new(
        serde_json::json!({
            "response": {
                "p": "TUYU",
                "v": 1,
                "k": 2,
                "i": "tyc_00112233445566778899aabbccddeeff",
                "e": 2_000_000_000_000_i64,
                "b": {
                    "u": format!("0x{}", "11".repeat(32)),
                    "s": format!("0x{}", "22".repeat(64))
                }
            },
            "name": "管理员",
            "private_key": "forbidden"
        })
        .to_string(),
    )
    .unwrap();
    let pointer = unsafe { tuyubooking_initialize_administrator(input.as_ptr()) };
    let response = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .unwrap()
        .to_owned();
    unsafe { tuyubooking_string_free(pointer) };
    let json: serde_json::Value = serde_json::from_str(&response).unwrap();
    assert_eq!(json["error"]["message"]["key"], "ffi.invalid_request");
}

#[test]
fn production_ffi_contains_no_private_key_signing_entrypoint() {
    let ffi = concat!(
        include_str!("../src/ffi/mod.rs"),
        include_str!("../src/ffi/qr_login.rs"),
        include_str!("../src/ffi/administrators.rs")
    );
    assert!(!ffi.contains("MiniSecretKey"));
    assert!(!ffi.contains("sr25519_sign"));
    assert!(!ffi.contains("sr25519_public_key"));
    assert!(!ffi.contains("server_session_token"));
}
