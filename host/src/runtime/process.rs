use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use serde_json::{Map, Value};

use crate::runtime::postgres::PostgresRuntimeConfig;
use crate::storage::StorageError;

use super::{
    EmployeeGatewayConfig, EmployeeGatewayRouteSnapshot, EmployeeGatewaySnapshot,
    EmployeeGatewayStatus, GatewayRoute, ModuleRuntimeConfig, ModuleRuntimeSnapshot,
    ModuleRuntimeStatus,
};

// ERPNext performs a large first-run DocType migration. Keep monitoring child
// failure continuously, but allow enough time for that one-time initialization
// on merchant hardware before declaring the subsystem unavailable.
const BUSINESS_STARTUP_TIMEOUT: Duration = Duration::from_secs(600);
// Supervisors handle SIGTERM by stopping and reaping every child, including
// PHP-FPM processes that create their own process group. Retain SIGKILL only
// as a bounded fallback for a supervisor that cannot finish graceful cleanup.
const BUSINESS_SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(12);
const EMPLOYEE_GATEWAY_STARTUP_TIMEOUT: Duration = Duration::from_secs(15);


// 就绪必须完成本模块证书的TLS1.3握手和主机名校验，开放TCP端口不能证明HTTPS可用。
const TLS_READINESS_PROBE: &str = r#"
import pathlib, socket, ssl, sys
try:
    certificate = pathlib.Path(sys.argv[1])
    hostname = sys.argv[2]
    port = int(sys.argv[3])
    if (not certificate.is_absolute() or certificate.resolve(strict=True) != certificate
        or not certificate.is_file() or not 0 < certificate.stat().st_size <= 1024 * 1024
        or not hostname or any(character in hostname for character in '\x00\r\n/')
        or not 0 < port <= 65535):
        raise ValueError('invalid TLS readiness input')
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.minimum_version = ssl.TLSVersion.TLSv1_3
    context.load_verify_locations(cafile=str(certificate))
    with socket.create_connection(('127.0.0.1', port), timeout=0.5) as raw:
        with context.wrap_socket(raw, server_hostname=hostname) as connection:
            if connection.version() != 'TLSv1.3':
                raise ValueError('invalid TLS readiness version')
except Exception:
    sys.exit(1)
"#;

fn tls_listener_is_reachable(
    runtime_dir: &std::path::Path,
    data_dir: &std::path::Path,
    hostname: &str,
    port: u16,
) -> bool {
    let python = runtime_executable(runtime_dir.join("python/bin/python3"));
    let certificate = data_dir.join("tls/localhost.crt");
    let Ok(mut probe) = Command::new(python)
        .arg("-I")
        .arg("-c")
        .arg(TLS_READINESS_PROBE)
        .arg(certificate)
        .arg(hostname)
        .arg(port.to_string())
        .env("PYTHONHOME", runtime_dir.join("python"))
        .env("PYTHONNOUSERSITE", "1")
        .env("PYTHONDONTWRITEBYTECODE", "1")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    else {
        return false;
    };
    // 解释器异常或被取消不得阻塞运行时轮询；超时杀死并回收本次探针，按不可用处理。
    let deadline = Instant::now() + Duration::from_secs(2);
    while Instant::now() < deadline {
        match probe.try_wait() {
            Ok(Some(status)) => return status.success(),
            Ok(None) => thread::sleep(Duration::from_millis(10)),
            Err(_) => break,
        }
    }
    let _ = probe.kill();
    let _ = probe.wait();
    false
}

pub(crate) struct ModuleLaunchSpec {
    pub script: &'static str,
    pub required_paths: Vec<PathBuf>,
    pub extra_config: Map<String, Value>,
}

pub(crate) struct ProcessModuleRuntime {
    config: ModuleRuntimeConfig,
    launch: ModuleLaunchSpec,
    child: Option<Child>,
    status: ModuleRuntimeStatus,
    error: Option<String>,
    startup_deadline: Option<Instant>,
}

impl ProcessModuleRuntime {
    pub fn new(
        config: ModuleRuntimeConfig,
        launch: ModuleLaunchSpec,
    ) -> Result<Self, StorageError> {
        config.validate()?;
        let missing = launch
            .required_paths
            .iter()
            .find(|relative| !payload_path_exists(&config.runtime_dir, relative));
        let (status, error) = if !config.enabled {
            (ModuleRuntimeStatus::Disabled, None)
        } else if let Some(path) = missing {
            (
                ModuleRuntimeStatus::PayloadMissing,
                Some(format!(
                    "{} payload is missing: {}",
                    config.module.as_str(),
                    config.runtime_dir.join(path).display()
                )),
            )
        } else {
            (ModuleRuntimeStatus::Installed, None)
        };
        Ok(Self {
            config,
            launch,
            child: None,
            status,
            error,
            startup_deadline: None,
        })
    }

    pub fn is_enabled(&self) -> bool {
        self.config.enabled
    }

    pub fn enable(&mut self) {
        self.config.enabled = true;
        if self.child.is_some() {
            return;
        }
        if let Some(path) = self
            .launch
            .required_paths
            .iter()
            .find(|relative| !payload_path_exists(&self.config.runtime_dir, relative))
        {
            self.status = ModuleRuntimeStatus::PayloadMissing;
            self.error = Some(format!(
                "{} payload is missing: {}",
                self.config.module.as_str(),
                self.config.runtime_dir.join(path).display()
            ));
        } else {
            self.status = ModuleRuntimeStatus::Installed;
            self.error = None;
        }
    }

    pub fn disable(&mut self) -> Result<(), StorageError> {
        self.stop()?;
        self.config.enabled = false;
        self.status = ModuleRuntimeStatus::Disabled;
        self.error = None;
        self.startup_deadline = None;
        Ok(())
    }

    pub fn start(&mut self, postgres: &PostgresRuntimeConfig, password: &str) {
        if !matches!(
            self.status,
            ModuleRuntimeStatus::Installed
                | ModuleRuntimeStatus::Stopped
                | ModuleRuntimeStatus::Failed
                | ModuleRuntimeStatus::Degraded
        ) {
            return;
        }
        if let Err(error) = self.try_start(postgres, password) {
            self.fail(error.to_string());
        }
    }

    fn try_start(
        &mut self,
        postgres: &PostgresRuntimeConfig,
        password: &str,
    ) -> Result<(), StorageError> {
        fs::create_dir_all(&self.config.data_dir)?;
        if let Some(parent) = self.config.log_file.parent() {
            fs::create_dir_all(parent)?;
        }

        let mut config = Map::from_iter([
            (
                "module".to_owned(),
                Value::String(self.config.module.as_str().to_owned()),
            ),
            (
                "runtime_dir".to_owned(),
                Value::String(self.config.runtime_dir.display().to_string()),
            ),
            (
                "data_dir".to_owned(),
                Value::String(self.config.data_dir.display().to_string()),
            ),
            (
                "public_hostname".to_owned(),
                Value::String(self.config.public_hostname.clone()),
            ),
            ("https_port".to_owned(), Value::from(self.config.https_port)),
            (
                "database_host".to_owned(),
                Value::String(postgres.connection_host()),
            ),
            (
                "database_port".to_owned(),
                Value::from(postgres.connection_port()),
            ),
            (
                "database_name".to_owned(),
                Value::String(postgres.database.clone()),
            ),
            (
                "database_superuser".to_owned(),
                Value::String(postgres.username.clone()),
            ),
            (
                "database_superuser_password".to_owned(),
                Value::String(password.to_owned()),
            ),
            (
                "database_role".to_owned(),
                Value::String(self.config.module.database_role().to_owned()),
            ),
            (
                "database_schema".to_owned(),
                Value::String(self.config.module.schema().to_owned()),
            ),
        ]);
        if let Some(site_name) = &self.config.site_name {
            config.insert("site_name".to_owned(), Value::String(site_name.clone()));
        }
        if let Some(administrator_password) = &self.config.administrator_password {
            config.insert(
                "administrator_password".to_owned(),
                Value::String(administrator_password.clone()),
            );
        }
        config.extend(self.launch.extra_config.clone());

        let config_path = self.config.data_dir.join("supervisor.json");
        let temporary_path = config_path.with_extension("json.tmp");
        let serialized = serde_json::to_vec_pretty(&Value::Object(config))
            .map_err(|error| StorageError::InvalidData(error.to_string()))?;
        let mut file = OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .open(&temporary_path)?;
        file.write_all(&serialized)?;
        file.sync_all()?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&temporary_path, fs::Permissions::from_mode(0o600))?;
        }
        fs::rename(temporary_path, &config_path)?;

        let log = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.config.log_file)?;
        let stderr = log.try_clone()?;
        let python = runtime_executable(self.config.runtime_dir.join("python/bin/python3"));
        let python_home = self.config.runtime_dir.join("python");
        let script = self.config.runtime_dir.join(self.launch.script);
        self.status = ModuleRuntimeStatus::Starting;
        self.error = None;
        let mut command = Command::new(&python);
        command
            .arg(&script)
            .arg("--config")
            .arg(&config_path)
            .current_dir(&self.config.runtime_dir)
            .env("PYTHONHOME", &python_home)
            .env("PYTHONNOUSERSITE", "1")
            // The signed application bundle is immutable. Supervisors and
            // all inherited Python workers must keep bytecode caches in
            // merchant data directories rather than beside packaged code.
            .env("PYTHONDONTWRITEBYTECODE", "1")
            .stdin(Stdio::null())
            .stdout(Stdio::from(log))
            .stderr(Stdio::from(stderr));
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            // Every module owns a process group so stopping the supervisor also
            // terminates Gunicorn, Nitro, PHP-FPM, Nginx and proxy descendants.
            command.process_group(0);
        }
        self.child = Some(command.spawn()?);
        self.startup_deadline = Some(Instant::now() + BUSINESS_STARTUP_TIMEOUT);
        Ok(())
    }

    pub fn refresh(&mut self) {
        let mut child_is_running = false;
        if let Some(child) = self.child.as_mut() {
            match child.try_wait() {
                Ok(Some(status)) => {
                    self.child = None;
                    self.fail(format!(
                        "{} runtime exited with {status}",
                        self.config.module.as_str()
                    ));
                }
                Ok(None) => child_is_running = true,
                Err(error) => self.fail(error.to_string()),
            }
        }
        if child_is_running && self.status == ModuleRuntimeStatus::Starting {
            if self.https_listener_is_reachable() {
                self.status = ModuleRuntimeStatus::Ready;
                self.error = None;
                self.startup_deadline = None;
            } else if self
                .startup_deadline
                .is_some_and(|deadline| Instant::now() >= deadline)
            {
                self.fail(format!(
                    "{} runtime did not become ready before timeout",
                    self.config.module.as_str()
                ));
                return;
            }
        }
        if child_is_running
            && matches!(
                self.status,
                ModuleRuntimeStatus::Ready | ModuleRuntimeStatus::Degraded
            )
        {
            if self.https_listener_is_reachable() {
                self.status = ModuleRuntimeStatus::Ready;
                self.error = None;
            } else {
                self.status = ModuleRuntimeStatus::Degraded;
                self.error = Some(format!(
                    "{} HTTPS listener is unavailable on {}:{}",
                    self.config.module.as_str(),
                    self.config.public_hostname,
                    self.config.https_port
                ));
            }
        }
    }

    fn https_listener_is_reachable(&self) -> bool {
        tls_listener_is_reachable(
            &self.config.runtime_dir,
            &self.config.data_dir,
            &self.config.public_hostname,
            self.config.https_port,
        )
    }

    pub fn snapshot(&mut self) -> ModuleRuntimeSnapshot {
        self.refresh();
        ModuleRuntimeSnapshot {
            id: self.config.module.as_str(),
            status: self.status,
            schema: self.config.module.schema(),
            https_origin: self
                .status
                .is_available()
                .then(|| self.config.https_origin()),
            error: self.error.clone(),
        }
    }

    pub fn stop(&mut self) -> Result<(), StorageError> {
        if matches!(
            self.status,
            ModuleRuntimeStatus::Disabled | ModuleRuntimeStatus::PayloadMissing
        ) {
            return Ok(());
        }
        self.status = ModuleRuntimeStatus::Stopping;
        if let Some(mut child) = self.child.take() {
            terminate_child_tree(&mut child)?;
        }
        self.status = ModuleRuntimeStatus::Stopped;
        self.error = None;
        self.startup_deadline = None;
        Ok(())
    }

    fn fail(&mut self, message: String) {
        if let Some(mut child) = self.child.take() {
            let _ = terminate_child_tree(&mut child);
        }
        self.status = ModuleRuntimeStatus::Failed;
        self.error = Some(message);
        self.startup_deadline = None;
    }
}

fn terminate_child_tree(child: &mut Child) -> Result<(), StorageError> {
    if child.try_wait()?.is_some() {
        return Ok(());
    }
    #[cfg(unix)]
    {
        let process_group = -(child.id() as i32);
        // SAFETY: the child was created as the leader of its own process group,
        // and the negative PID targets only that module-owned group.
        let result = unsafe { libc::kill(process_group, libc::SIGTERM) };
        if result != 0 {
            let error = std::io::Error::last_os_error();
            if error.raw_os_error() != Some(libc::ESRCH) {
                return Err(error.into());
            }
        }
        let deadline = Instant::now() + BUSINESS_SHUTDOWN_TIMEOUT;
        while Instant::now() < deadline {
            if child.try_wait()?.is_some() {
                return Ok(());
            }
            thread::sleep(Duration::from_millis(50));
        }
        // SAFETY: this is the same dedicated process group, used only after
        // the supervisor exceeded the bounded graceful-shutdown period.
        let result = unsafe { libc::kill(process_group, libc::SIGKILL) };
        if result != 0 {
            let error = std::io::Error::last_os_error();
            if error.raw_os_error() != Some(libc::ESRCH) {
                return Err(error.into());
            }
        }
    }
    #[cfg(not(unix))]
    child.kill()?;
    child.wait()?;
    Ok(())
}

fn payload_path_exists(runtime_dir: &std::path::Path, relative: &std::path::Path) -> bool {
    let path = runtime_dir.join(relative);
    path.exists()
        || (cfg!(windows)
            && (path.with_extension("exe").exists()
                || (relative == std::path::Path::new("python/bin/python3")
                    && runtime_dir.join("python/python.exe").exists())))
}

fn runtime_executable(path: PathBuf) -> PathBuf {
    if cfg!(windows) {
        let executable = path.with_extension("exe");
        if executable.is_file() {
            return executable;
        }
        if path.ends_with("python/bin/python3") {
            if let Some(runtime_dir) = path.ancestors().nth(3) {
                let python = runtime_dir.join("python/python.exe");
                if python.is_file() {
                    return python;
                }
            }
        }
    }
    path
}

impl Drop for ProcessModuleRuntime {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

/// Owns the administrator-enabled LAN HTTPS endpoint. Business modules remain
/// loopback-only and retain their original employee authentication systems.
pub(crate) struct EmployeeGatewayRuntime {
    config: EmployeeGatewayConfig,
    child: Option<Child>,
    status: EmployeeGatewayStatus,
    routes: Vec<GatewayRoute>,
    error: Option<String>,
}

impl EmployeeGatewayRuntime {
    pub fn new(config: EmployeeGatewayConfig) -> Result<Self, StorageError> {
        config.validate()?;
        Ok(Self {
            config,
            child: None,
            status: EmployeeGatewayStatus::Disabled,
            routes: Vec::new(),
            error: None,
        })
    }

    pub fn is_enabled(&self) -> bool {
        self.status != EmployeeGatewayStatus::Disabled
    }

    pub fn serves_routes(&self, routes: &[GatewayRoute]) -> bool {
        matches!(
            self.status,
            EmployeeGatewayStatus::Starting | EmployeeGatewayStatus::Ready
        ) && self.routes == routes
    }

    pub fn start(&mut self, routes: Vec<GatewayRoute>) -> Result<(), StorageError> {
        if routes.is_empty() {
            return Err(StorageError::InvalidData(
                "employee gateway requires at least one ready business module".to_owned(),
            ));
        }
        self.stop()?;
        fs::create_dir_all(&self.config.data_dir)?;
        if let Some(parent) = self.config.log_file.parent() {
            fs::create_dir_all(parent)?;
        }
        let log = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.config.log_file)?;
        let stderr = log.try_clone()?;
        let python = runtime_executable(self.config.runtime_dir.join("python/bin/python3"));
        let mut command = Command::new(python);
        command
            .arg(self.config.runtime_dir.join("tuyu_https_proxy.py"))
            .arg("--listen-host")
            .arg("0.0.0.0")
            .arg("--listen-port")
            .arg(self.config.https_port.to_string())
            .arg("--runtime-root")
            .arg(&self.config.runtime_dir)
            .arg("--data-dir")
            .arg(&self.config.data_dir)
            .arg("--hostname")
            .arg(&self.config.public_hostname)
            .arg("--merchant-name")
            .arg(&self.config.merchant_name)
            .current_dir(&self.config.runtime_dir)
            .env("PYTHONHOME", self.config.runtime_dir.join("python"))
            .env("PYTHONNOUSERSITE", "1")
            .env("PYTHONDONTWRITEBYTECODE", "1")
            .stdin(Stdio::null())
            .stdout(Stdio::from(log))
            .stderr(Stdio::from(stderr));
        for route in &routes {
            let module_data_root = self.config.data_dir.parent().ok_or_else(|| {
                StorageError::InvalidData("employee gateway data root is missing".to_owned())
            })?;
            let certificate = module_data_root
                .join(route.module)
                .join("tls")
                .join("localhost.crt");
            if !certificate.is_file() {
                return Err(StorageError::InvalidData(
                    "ready business module TLS certificate is missing".to_owned(),
                ));
            }
            // 受信来源为同一安装内准确模块的公开证书，禁止跳过TLS校验。
            command
                .arg("--route")
                .arg(format!("/{}={}", route.module, route.https_origin))
                .arg("--ca")
                .arg(certificate);
        }
        #[cfg(unix)]
        {
            use std::os::unix::process::CommandExt;
            command.process_group(0);
        }
        self.status = EmployeeGatewayStatus::Starting;
        self.error = None;
        self.routes = routes;
        match command.spawn() {
            Ok(child) => self.child = Some(child),
            Err(error) => {
                self.status = EmployeeGatewayStatus::Failed;
                self.error = Some(error.to_string());
                return Err(error.into());
            }
        }

        let deadline = Instant::now() + EMPLOYEE_GATEWAY_STARTUP_TIMEOUT;
        while Instant::now() < deadline {
            self.refresh();
            if self.status == EmployeeGatewayStatus::Failed {
                return Err(StorageError::RuntimeCommand(
                    self.error
                        .clone()
                        .unwrap_or_else(|| "employee gateway exited".to_owned()),
                ));
            }
            let reachable = tls_listener_is_reachable(
                &self.config.runtime_dir,
                &self.config.data_dir,
                &self.config.public_hostname,
                self.config.https_port,
            );
            if reachable {
                self.status = EmployeeGatewayStatus::Ready;
                fs::write(self.config.data_dir.join("enabled"), b"1")?;
                return Ok(());
            }
            thread::sleep(Duration::from_millis(200));
        }
        self.status = EmployeeGatewayStatus::Failed;
        self.error = Some("employee gateway did not become ready before timeout".to_owned());
        Err(StorageError::RuntimeCommand(
            self.error.clone().expect("gateway timeout error is set"),
        ))
    }

    pub fn snapshot(&mut self) -> EmployeeGatewaySnapshot {
        self.refresh();
        let fingerprint =
            fs::read_to_string(self.config.data_dir.join("tls").join("certificate.sha256"))
                .ok()
                .map(|value| value.trim().to_owned())
                .filter(|value| !value.is_empty());
        EmployeeGatewaySnapshot {
            enabled: self.is_enabled(),
            status: self.status,
            https_origin: self.config.https_origin(),
            certificate_fingerprint: fingerprint,
            routes: self
                .routes
                .iter()
                .map(|route| EmployeeGatewayRouteSnapshot {
                    module: route.module,
                    path: format!("/{}", route.module),
                })
                .collect(),
            error: self.error.clone(),
        }
    }

    pub fn stop(&mut self) -> Result<(), StorageError> {
        if let Some(mut child) = self.child.take() {
            self.status = EmployeeGatewayStatus::Stopping;
            terminate_child_tree(&mut child)?;
        }
        self.status = EmployeeGatewayStatus::Disabled;
        self.routes.clear();
        self.error = None;
        Ok(())
    }

    pub fn was_enabled(&self) -> bool {
        self.config.data_dir.join("enabled").is_file()
    }

    pub fn disable(&mut self) -> Result<(), StorageError> {
        self.stop()?;
        let marker = self.config.data_dir.join("enabled");
        if marker.is_file() {
            fs::remove_file(marker)?;
        }
        Ok(())
    }

    fn refresh(&mut self) {
        if let Some(child) = self.child.as_mut() {
            match child.try_wait() {
                Ok(Some(status)) => {
                    self.child = None;
                    self.status = EmployeeGatewayStatus::Failed;
                    self.error = Some(format!("employee gateway exited with {status}"));
                }
                Ok(None) => {}
                Err(error) => {
                    self.status = EmployeeGatewayStatus::Failed;
                    self.error = Some(error.to_string());
                }
            }
        }
    }
}

impl Drop for EmployeeGatewayRuntime {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::{terminate_child_tree, BUSINESS_SHUTDOWN_TIMEOUT, BUSINESS_STARTUP_TIMEOUT};
    use std::fs;
    use std::process::{Command, Stdio};
    use std::thread;
    use std::time::Duration;

    #[test]
    fn startup_timeout_covers_large_first_run_migrations() {
        assert!(BUSINESS_STARTUP_TIMEOUT >= Duration::from_secs(300));
    }

    #[cfg(unix)]
    #[test]
    fn stopping_a_module_gracefully_terminates_its_process_group() {
        use std::os::unix::process::CommandExt;

        assert!(BUSINESS_SHUTDOWN_TIMEOUT > Duration::from_secs(10));
        let temporary = tempfile::TempDir::new().expect("create shutdown fixture");
        let marker = temporary.path().join("graceful-shutdown");
        let mut command = Command::new("/bin/sh");
        command
            .arg("-c")
            .arg(
                "trap 'printf graceful > \"$TUYU_SHUTDOWN_MARKER\"; exit 0' TERM; \
                 while :; do sleep 1; done",
            )
            .env("TUYU_SHUTDOWN_MARKER", &marker)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .process_group(0);
        let mut child = command.spawn().expect("spawn process group fixture");
        let process_group = -(child.id() as i32);
        thread::sleep(Duration::from_millis(100));
        terminate_child_tree(&mut child).expect("terminate process group");
        assert_eq!(
            fs::read_to_string(marker).expect("graceful shutdown marker"),
            "graceful"
        );

        // SAFETY: signal 0 only checks whether the dedicated group still exists.
        let result = unsafe { libc::kill(process_group, 0) };
        assert_eq!(result, -1);
        assert_eq!(
            std::io::Error::last_os_error().raw_os_error(),
            Some(libc::ESRCH)
        );
    }
}
