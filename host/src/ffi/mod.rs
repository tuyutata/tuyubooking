//! Stable C ABI used by the Flutter desktop shell.
//!
//! Business calls exchange JSON DTOs, never database handles or secret keys.
//! TuyuBooking never accepts or uses administrator private key material.

mod administrators;
mod qr_login;
pub use administrators::{
    tuyubooking_add_administrator, tuyubooking_administrator_state,
    tuyubooking_delete_administrator, tuyubooking_initialize_administrator,
    tuyubooking_list_administrators, tuyubooking_update_administrator_name,
    tuyubooking_update_administrator_status,
};
pub use qr_login::{tuyubooking_qr_login_challenge, tuyubooking_qr_login_complete};

use crate::application::{
    ApplicationBootstrap, ApplicationError, ApplicationRuntime, ApplicationServices,
};
use crate::core::EntityId;
use crate::runtime::{
    routes_for_ready_modules, BusinessModule, EmployeeGatewayConfig, EmployeeGatewayRuntime,
    ModuleRuntimeConfig, ModuleRuntimeSnapshot, ModuleRuntimeStatus,
};
use crate::storage::{ConnectionMode, PostgresRuntimeConfig};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::ffi::{c_char, CStr, CString};
use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};

struct NativeState {
    /// Owns the Tokio reactor that drives the retained PostgreSQL connection.
    /// Dropping this executor while keeping `services` makes every later
    /// account query fail even though the PostgreSQL child is still running.
    executor: Option<tokio::runtime::Runtime>,
    runtime: Option<ApplicationRuntime>,
    services: Option<ApplicationServices>,
    employee_gateway: Option<EmployeeGatewayRuntime>,
}

fn state() -> &'static Mutex<NativeState> {
    static STATE: OnceLock<Mutex<NativeState>> = OnceLock::new();
    STATE.get_or_init(|| {
        Mutex::new(NativeState {
            executor: None,
            runtime: None,
            services: None,
            employee_gateway: None,
        })
    })
}

#[derive(Serialize)]
struct Success<T> {
    ok: bool,
    data: T,
}

#[derive(Serialize)]
struct Failure {
    ok: bool,
    error: ApplicationError,
}

#[derive(Serialize)]
struct ContractDocument {
    product: &'static str,
    product_code: &'static str,
    contract_version: u16,
    locales: [&'static str; 2],
    subsystems: [&'static str; 4],
    identity_algorithm: &'static str,
    private_key_fields_allowed: bool,
    runtime_controls: [&'static str; 6],
    login_protocol: &'static str,
    administrator_min_active: u8,
    administrator_max_total: u8,
    administrator_public_key_mutable: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct StartRequest {
    bin_dir: String,
    installation_dir: String,
    data_dir: String,
    log_file: String,
    socket_dir: Option<String>,
    port: u16,
    username: String,
    database: String,
    database_password: String,
    installation_name: String,
    merchant_name: String,
    timezone: String,
    currency_code: String,
    business_runtime_dir: String,
    business_data_root: String,
    business_log_root: String,
    available_modules: Vec<String>,
    public_hostname: String,
    hotel_administrator_password: String,
    restaurant_administrator_password: String,
}

#[derive(Serialize)]
struct RuntimeSnapshot {
    ready: bool,
    schemas: Vec<&'static str>,
    business_ready: bool,
    module_configuration_complete: bool,
    enabled_modules: Vec<&'static str>,
    https_origin: String,
    modules: Vec<ModuleRuntimeSnapshot>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ModuleRuntimeRequest {
    module: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ModuleConfigurationRequest {
    modules: Vec<String>,
}

pub fn contract_document() -> String {
    success(ContractDocument {
        product: "TuyuBooking",
        product_code: "TuyuBooking",
        contract_version: 8,
        locales: ["zh", "en"],
        subsystems: ["hotel", "restaurant", "tour", "ticket"],
        identity_algorithm: "sr25519",
        private_key_fields_allowed: false,
        runtime_controls: [
            "snapshot",
            "restart_module",
            "configure_modules",
            "employee_gateway_snapshot",
            "enable_employee_gateway",
            "disable_employee_gateway",
        ],
        login_protocol: "TUYU",
        administrator_min_active: 1,
        administrator_max_total: 99,
        administrator_public_key_mutable: false,
    })
}

#[no_mangle]
pub extern "C" fn tuyubooking_contract() -> *mut c_char {
    into_pointer(contract_document())
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_start(input: *const c_char) -> *mut c_char {
    guard(|| start(read_input(input)?))
}

#[no_mangle]
pub extern "C" fn tuyubooking_runtime_snapshot() -> *mut c_char {
    guard(runtime_status)
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_restart_module(input: *const c_char) -> *mut c_char {
    guard(|| restart_module(read_input(input)?))
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_configure_modules(input: *const c_char) -> *mut c_char {
    guard(|| configure_modules(read_input(input)?))
}

#[no_mangle]
pub extern "C" fn tuyubooking_administrator_assertion() -> *mut c_char {
    guard(administrator_assertion)
}

#[no_mangle]
pub extern "C" fn tuyubooking_employee_gateway_snapshot() -> *mut c_char {
    guard(employee_gateway_snapshot)
}

#[no_mangle]
pub extern "C" fn tuyubooking_enable_employee_gateway() -> *mut c_char {
    guard(enable_employee_gateway)
}

#[no_mangle]
pub extern "C" fn tuyubooking_disable_employee_gateway() -> *mut c_char {
    guard(disable_employee_gateway)
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_stop() -> *mut c_char {
    guard(stop)
}

#[no_mangle]
pub unsafe extern "C" fn tuyubooking_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}

fn start(input: &str) -> Result<String, ApplicationError> {
    let request: StartRequest = serde_json::from_str(input).map_err(invalid_request)?;
    if request.database_password.is_empty() || request.port == 0 {
        return Err(invalid_request("missing runtime credential or port"));
    }
    let available_modules = parse_modules(&request.available_modules)?;
    if available_modules != BusinessModule::ALL.into_iter().collect() {
        return Err(invalid_request(
            "all packaged business modules must be declared",
        ));
    }
    if available_modules.contains(&BusinessModule::Hotel)
        && request.hotel_administrator_password.is_empty()
    {
        return Err(invalid_request("missing hotel administrator credential"));
    }
    if available_modules.contains(&BusinessModule::Restaurant)
        && request.restaurant_administrator_password.is_empty()
    {
        return Err(invalid_request(
            "missing restaurant administrator credential",
        ));
    }

    let mut guard = state().lock().map_err(|_| internal_error())?;
    if guard.runtime.is_some() {
        let NativeState { executor, runtime, .. } = &mut *guard;
        return Ok(success(runtime_snapshot(
            runtime.as_mut().ok_or_else(startup_required)?,
            executor.as_ref().ok_or_else(startup_required)?,
        )?));
    }

    let module_configs = BusinessModule::ALL
        .into_iter()
        .map(|module| module_config(&request, module, false))
        .collect();
    let employee_gateway = EmployeeGatewayRuntime::new(EmployeeGatewayConfig {
        installation_dir: PathBuf::from(&request.installation_dir),
        runtime_dir: PathBuf::from(&request.business_runtime_dir),
        data_dir: PathBuf::from(&request.business_data_root).join("employee_gateway"),
        log_file: PathBuf::from(&request.business_log_root).join("employee_gateway.log"),
        public_hostname: request.public_hostname.clone(),
        merchant_name: request.merchant_name.clone(),
        https_port: 58_460,
    })
    .map_err(employee_gateway_error)?;

    let connection = match request.socket_dir {
        Some(directory) => ConnectionMode::UnixSocket {
            directory: PathBuf::from(directory),
            port: request.port,
        },
        None => ConnectionMode::LoopbackTcp { port: request.port },
    };
    let config = PostgresRuntimeConfig {
        bin_dir: PathBuf::from(request.bin_dir),
        installation_dir: PathBuf::from(&request.installation_dir),
        data_dir: PathBuf::from(request.data_dir),
        log_file: PathBuf::from(request.log_file),
        username: request.username,
        database: request.database,
        connection,
    };
    let bootstrap = ApplicationBootstrap {
        installation_id: EntityId::new(),
        installation_name: request.installation_name,
        merchant_id: EntityId::new(),
        merchant_name: request.merchant_name,
        timezone: request.timezone,
        currency_code: request.currency_code,
    };
    let executor = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .map_err(|_| internal_error())?;
    let mut runtime = executor.block_on(ApplicationRuntime::start_with_modules(
        config,
        &request.database_password,
        bootstrap,
        module_configs,
    ))?;
    let services = runtime.services();
    let snapshot = runtime_snapshot(&mut runtime, &executor)?;
    guard.executor = Some(executor);
    guard.services = Some(services);
    guard.runtime = Some(runtime);
    guard.employee_gateway = Some(employee_gateway);
    synchronize_employee_gateway(&mut guard, &snapshot)?;
    Ok(success(snapshot))
}

fn runtime_status() -> Result<String, ApplicationError> {
    let mut guard = state().lock().map_err(|_| internal_error())?;
    let snapshot = {
        let NativeState { executor, runtime, .. } = &mut *guard;
        let runtime = runtime.as_mut().ok_or_else(startup_required)?;
        runtime_snapshot(runtime, executor.as_ref().ok_or_else(startup_required)?)?
    };
    synchronize_employee_gateway(&mut guard, &snapshot)?;
    Ok(success(snapshot))
}

fn configure_modules(input: &str) -> Result<String, ApplicationError> {
    let request: ModuleConfigurationRequest =
        serde_json::from_str(input).map_err(invalid_request)?;
    let modules = parse_modules(&request.modules)?;
    if modules.is_empty() {
        return Err(invalid_request("at least one business module is required"));
    }
    let mut guard = state().lock().map_err(|_| internal_error())?;
    guard
        .services
        .as_ref()
        .ok_or_else(startup_required)?
        .require_authenticated_administrator()?;
    let snapshot = {
        let NativeState {
            executor, runtime, ..
        } = &mut *guard;
        let executor = executor.as_ref().ok_or_else(startup_required)?;
        let runtime = runtime.as_mut().ok_or_else(startup_required)?;
        executor.block_on(runtime.configure_business_modules(modules))?;
        runtime_snapshot(runtime, executor)?
    };
    synchronize_employee_gateway(&mut guard, &snapshot)?;
    Ok(success(snapshot))
}

fn restart_module(input: &str) -> Result<String, ApplicationError> {
    let request: ModuleRuntimeRequest = serde_json::from_str(input).map_err(invalid_request)?;
    let module = BusinessModule::parse(&request.module).map_err(invalid_request)?;
    let mut guard = state().lock().map_err(|_| internal_error())?;
    let snapshot = {
        let NativeState { executor, runtime, .. } = &mut *guard;
        let runtime = runtime.as_mut().ok_or_else(startup_required)?;
        runtime.restart_business_module(module)?;
        runtime_snapshot(runtime, executor.as_ref().ok_or_else(startup_required)?)?
    };
    if guard
        .employee_gateway
        .as_ref()
        .is_some_and(EmployeeGatewayRuntime::is_enabled)
    {
        let routes = routes_for_ready_modules(&snapshot.modules);
        guard
            .employee_gateway
            .as_mut()
            .ok_or_else(startup_required)?
            .start(routes)
            .map_err(employee_gateway_error)?;
    }
    Ok(success(snapshot))
}

fn administrator_assertion() -> Result<String, ApplicationError> {
    let guard = state().lock().map_err(|_| internal_error())?;
    let services = guard.services.as_ref().ok_or_else(startup_required)?;
    let executor = guard.executor.as_ref().ok_or_else(startup_required)?;
    Ok(success(create_administrator_assertion(services, executor)?))
}

fn create_administrator_assertion(
    services: &ApplicationServices,
    executor: &tokio::runtime::Runtime,
) -> Result<impl Serialize, ApplicationError> {
    executor.block_on(services.create_administrator_assertion())
}

fn employee_gateway_snapshot() -> Result<String, ApplicationError> {
    let mut guard = state().lock().map_err(|_| internal_error())?;
    let services = guard.services.as_ref().ok_or_else(startup_required)?;
    let executor = guard.executor.as_ref().ok_or_else(startup_required)?;
    let _ = create_administrator_assertion(services, executor)?;
    let gateway = guard
        .employee_gateway
        .as_mut()
        .ok_or_else(startup_required)?;
    Ok(success(gateway.snapshot()))
}

fn enable_employee_gateway() -> Result<String, ApplicationError> {
    let mut guard = state().lock().map_err(|_| internal_error())?;
    let services = guard.services.as_ref().ok_or_else(startup_required)?;
    let executor = guard.executor.as_ref().ok_or_else(startup_required)?;
    let _ = create_administrator_assertion(services, executor)?;
    let routes = {
        let runtime = guard.runtime.as_mut().ok_or_else(startup_required)?;
        routes_for_ready_modules(&runtime.business_snapshots())
    };
    let gateway = guard
        .employee_gateway
        .as_mut()
        .ok_or_else(startup_required)?;
    gateway.start(routes).map_err(employee_gateway_error)?;
    Ok(success(gateway.snapshot()))
}

fn disable_employee_gateway() -> Result<String, ApplicationError> {
    let mut guard = state().lock().map_err(|_| internal_error())?;
    let services = guard.services.as_ref().ok_or_else(startup_required)?;
    let executor = guard.executor.as_ref().ok_or_else(startup_required)?;
    let _ = create_administrator_assertion(services, executor)?;
    let gateway = guard
        .employee_gateway
        .as_mut()
        .ok_or_else(startup_required)?;
    gateway.disable().map_err(employee_gateway_error)?;
    Ok(success(gateway.snapshot()))
}

fn stop() -> Result<String, ApplicationError> {
    let mut guard = state().lock().map_err(|_| internal_error())?;
    guard.services = None;
    if let Some(gateway) = guard.employee_gateway.as_mut() {
        gateway.stop().map_err(employee_gateway_error)?;
    }
    guard.employee_gateway = None;
    let stop_result = guard
        .runtime
        .take()
        .map(ApplicationRuntime::stop)
        .transpose();
    // Keep the reactor alive through PostgreSQL shutdown, then release all of
    // its worker threads before reporting the host runtime as stopped.
    guard.executor = None;
    stop_result?;
    Ok(success(serde_json::json!({"stopped": true})))
}

fn parse_modules(values: &[String]) -> Result<BTreeSet<BusinessModule>, ApplicationError> {
    let modules = values
        .iter()
        .map(|value| BusinessModule::parse(value).map_err(invalid_request))
        .collect::<Result<BTreeSet<_>, _>>()?;
    if modules.len() != values.len() {
        return Err(invalid_request("duplicate business module"));
    }
    Ok(modules)
}

fn module_config(
    request: &StartRequest,
    module: BusinessModule,
    enabled: bool,
) -> ModuleRuntimeConfig {
    let (https_port, site_name, administrator_password) = match module {
        BusinessModule::Hotel => (
            58_443,
            Some("hotel.localhost".to_owned()),
            Some(request.hotel_administrator_password.clone()),
        ),
        BusinessModule::Restaurant => (
            58_450,
            Some("restaurant.localhost".to_owned()),
            Some(request.restaurant_administrator_password.clone()),
        ),
        BusinessModule::Tour => (58_444, None, None),
        BusinessModule::Ticket => (58_446, None, None),
    };
    ModuleRuntimeConfig {
        module,
        enabled,
        installation_dir: PathBuf::from(&request.installation_dir),
        runtime_dir: PathBuf::from(&request.business_runtime_dir),
        data_dir: PathBuf::from(&request.business_data_root).join(module.as_str()),
        log_file: PathBuf::from(&request.business_log_root)
            .join(format!("{}.log", module.as_str())),
        public_hostname: "127.0.0.1".to_owned(),
        merchant_name: request.merchant_name.clone(),
        https_port,
        site_name,
        administrator_password,
    }
}

fn runtime_snapshot(
    runtime: &mut ApplicationRuntime,
    executor: &tokio::runtime::Runtime,
) -> Result<RuntimeSnapshot, ApplicationError> {
    // 每次返回就绪状态前查询核心数据库；业务模块失败不等于数据库失败，反之亦然。
    let ready = executor.block_on(runtime.core_is_ready());
    if !ready {
        return Err(ApplicationError::internal(
            "startup.database_unavailable",
            "本地数据库暂不可用，请检查本机数据服务后重试",
            "The local database is unavailable. Check the local data service and retry",
        ));
    }
    let enabled_modules = runtime.enabled_business_modules();
    let modules = runtime.business_snapshots();
    let business_ready = modules
        .iter()
        .filter(|module| {
            enabled_modules
                .iter()
                .any(|enabled| enabled.as_str() == module.id)
        })
        .all(|module| module.status == ModuleRuntimeStatus::Ready);
    let https_origin = modules
        .iter()
        .find(|module| module.status.is_available())
        .and_then(|module| module.https_origin.clone())
        .unwrap_or_default();
    let mut schemas = vec!["tuyu_core"];
    schemas.extend(enabled_modules.iter().map(|module| module.schema()));
    Ok(RuntimeSnapshot {
        ready,
        schemas,
        business_ready,
        module_configuration_complete: runtime.module_configuration_complete(),
        enabled_modules: enabled_modules
            .iter()
            .map(|module| module.as_str())
            .collect(),
        https_origin,
        modules,
    })
}

fn synchronize_employee_gateway(
    state: &mut NativeState,
    snapshot: &RuntimeSnapshot,
) -> Result<(), ApplicationError> {
    let gateway = state
        .employee_gateway
        .as_mut()
        .ok_or_else(startup_required)?;
    if !gateway.was_enabled() {
        return Ok(());
    }
    let routes = routes_for_ready_modules(&snapshot.modules);
    if routes.is_empty() {
        if gateway.is_enabled() {
            gateway.stop().map_err(employee_gateway_error)?;
        }
    } else if !gateway.serves_routes(&routes) {
        gateway.start(routes).map_err(employee_gateway_error)?;
    }
    Ok(())
}

unsafe fn read_input<'a>(input: *const c_char) -> Result<&'a str, ApplicationError> {
    if input.is_null() {
        return Err(invalid_request("null input"));
    }
    CStr::from_ptr(input).to_str().map_err(invalid_request)
}

fn success<T: Serialize>(data: T) -> String {
    serde_json::to_string(&Success { ok: true, data })
        .unwrap_or_else(|_| "{\"ok\":false}".to_owned())
}

fn failure(error: ApplicationError) -> String {
    serde_json::to_string(&Failure { ok: false, error })
        .unwrap_or_else(|_| "{\"ok\":false}".to_owned())
}

fn guard(operation: impl FnOnce() -> Result<String, ApplicationError>) -> *mut c_char {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(operation));
    into_pointer(match result {
        Ok(Ok(value)) => value,
        Ok(Err(error)) => failure(error),
        Err(_) => failure(internal_error()),
    })
}

fn into_pointer(value: String) -> *mut c_char {
    CString::new(value)
        .unwrap_or_else(|_| CString::new("{\"ok\":false}").expect("static JSON has no NUL"))
        .into_raw()
}

fn invalid_request(_error: impl std::fmt::Display) -> ApplicationError {
    ApplicationError::internal(
        "ffi.invalid_request",
        "桌面端请求格式无效",
        "The desktop request is invalid",
    )
}

fn startup_required() -> ApplicationError {
    ApplicationError::internal(
        "ffi.startup_required",
        "本地数据服务尚未启动",
        "The local data service has not started",
    )
}

fn employee_gateway_error(_error: impl std::fmt::Display) -> ApplicationError {
    ApplicationError::internal(
        "ffi.employee_gateway",
        "员工局域网 HTTPS 服务不可用",
        "The employee LAN HTTPS service is unavailable",
    )
}

fn internal_error() -> ApplicationError {
    ApplicationError::internal(
        "ffi.internal",
        "途遇商家端本地服务不可用",
        "The TuyuBooking native service is unavailable",
    )
}
