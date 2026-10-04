use crate::storage::StorageError;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

#[cfg(unix)]
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ConnectionMode {
    UnixSocket { directory: PathBuf, port: u16 },
    LoopbackTcp { port: u16 },
}

#[derive(Clone, Debug)]
pub struct PostgresRuntimeConfig {
    pub bin_dir: PathBuf,
    pub installation_dir: PathBuf,
    pub data_dir: PathBuf,
    pub log_file: PathBuf,
    pub username: String,
    pub database: String,
    pub connection: ConnectionMode,
}

impl PostgresRuntimeConfig {
    pub fn validate(&self) -> Result<(), StorageError> {
        if self.data_dir.starts_with(&self.installation_dir) {
            return Err(StorageError::DataDirectoryInsideInstallation);
        }

        for executable in ["postgres", "initdb", "pg_ctl", "psql"] {
            let path = self.bin_dir.join(executable_name(executable));
            if !path.is_file() {
                return Err(StorageError::MissingExecutable(path));
            }
        }
        for input in ["postgres.bki", "postgresql.conf.sample"] {
            let path = self.share_dir().join(input);
            if !path.is_file() {
                return Err(StorageError::MissingExecutable(path));
            }
        }

        Ok(())
    }

    /// Shared initialization data is an explicit package-local dependency.
    /// Never fall back to a package manager path compiled into PostgreSQL.
    pub fn share_dir(&self) -> PathBuf {
        self.bin_dir
            .parent()
            .unwrap_or(&self.bin_dir)
            .join("share/postgresql")
    }

    pub fn server_options(&self) -> String {
        match &self.connection {
            ConnectionMode::UnixSocket { directory, port } => format!(
                "-c listen_addresses='' -c unix_socket_directories={} -p {} \
                 -c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap",
                directory.display(),
                port
            ),
            ConnectionMode::LoopbackTcp { port } => {
                format!(
                    "-c listen_addresses=127.0.0.1 -p {port} \
                     -c shared_memory_type=mmap -c dynamic_shared_memory_type=mmap"
                )
            }
        }
    }

    pub fn connection_host(&self) -> String {
        match &self.connection {
            ConnectionMode::UnixSocket { directory, .. } => {
                directory.to_string_lossy().into_owned()
            }
            ConnectionMode::LoopbackTcp { .. } => "127.0.0.1".to_owned(),
        }
    }

    pub const fn connection_port(&self) -> u16 {
        match &self.connection {
            ConnectionMode::UnixSocket { port, .. } | ConnectionMode::LoopbackTcp { port } => *port,
        }
    }
}

pub struct PostgresRuntime {
    config: PostgresRuntimeConfig,
    started: bool,
}

impl PostgresRuntime {
    pub fn new(config: PostgresRuntimeConfig) -> Result<Self, StorageError> {
        config.validate()?;
        Ok(Self {
            config,
            started: false,
        })
    }

    pub fn config(&self) -> &PostgresRuntimeConfig {
        &self.config
    }

    pub fn initialize(&self, password: &str) -> Result<(), StorageError> {
        self.prepare_runtime_directories()?;
        if self.config.data_dir.join("PG_VERSION").is_file() {
            self.configure_private_socket_authentication()?;
            return Ok(());
        }

        let mut initdb = self.command("initdb")?;
        let password_file = self
            .config
            .data_dir
            .parent()
            .unwrap_or(&self.config.data_dir)
            .join(format!(".tuyu-initdb-password-{}", std::process::id()));

        let mut password_options = OpenOptions::new();
        password_options.write(true).create_new(true);
        #[cfg(unix)]
        password_options.mode(0o600);

        let mut password_handle = password_options.open(&password_file)?;
        password_handle.write_all(password.as_bytes())?;
        password_handle.write_all(b"\n")?;
        password_handle.sync_all()?;
        drop(password_handle);

        let output_result = initdb
            .arg("--pgdata")
            .arg(&self.config.data_dir)
            .arg("--username")
            .arg(&self.config.username)
            .arg("--pwfile")
            .arg(&password_file)
            .arg("-L")
            .arg(self.config.share_dir())
            .arg("--set")
            .arg("shared_memory_type=mmap")
            .arg("--set")
            .arg("dynamic_shared_memory_type=mmap")
            .arg("--auth-local=scram-sha-256")
            .arg("--auth-host=scram-sha-256")
            .arg("--encoding=UTF8")
            .arg("--no-locale")
            // PostgreSQL has a built-in GMT definition, so bootstrap never
            // needs a package-manager timezone directory outside the app.
            .env("TZ", "GMT")
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .output();

        let removal_result = std::fs::remove_file(&password_file);
        let output = output_result?;
        removal_result?;
        let result = command_success("initdb", output);
        if let Err(error) = &result {
            append_runtime_diagnostic(&self.config.log_file, error);
        }
        result?;
        self.configure_private_socket_authentication()
    }

    /// Process-scoped directories must be restored on every application start,
    /// including starts that reuse an existing PostgreSQL data directory.
    fn prepare_runtime_directories(&self) -> Result<(), StorageError> {
        std::fs::create_dir_all(&self.config.data_dir)?;
        if let ConnectionMode::UnixSocket { directory, .. } = &self.config.connection {
            std::fs::create_dir_all(directory)?;
            #[cfg(unix)]
            std::fs::set_permissions(directory, std::fs::Permissions::from_mode(0o700))?;
        }
        if let Some(parent) = self.config.log_file.parent() {
            std::fs::create_dir_all(parent)?;
        }
        Ok(())
    }

    /// Unix builds expose PostgreSQL only through a mode-0700 socket directory.
    /// That operating-system boundary avoids a user-visible database password
    /// and lets existing installations start without credential-store access.
    /// Windows loopback TCP authentication remains unchanged.
    fn configure_private_socket_authentication(&self) -> Result<(), StorageError> {
        #[cfg(unix)]
        if matches!(self.config.connection, ConnectionMode::UnixSocket { .. }) {
            const MARKER: &str = "# TuyuBooking private Unix socket\n";
            let path = self.config.data_dir.join("pg_hba.conf");
            let current = std::fs::read_to_string(&path)?;
            if !current.starts_with(MARKER) {
                let replacement = format!("{MARKER}local all all trust\n{current}");
                let temporary = self
                    .config
                    .data_dir
                    .join(format!(".pg_hba.conf-{}", std::process::id()));
                let mut options = OpenOptions::new();
                options.write(true).create_new(true);
                #[cfg(unix)]
                options.mode(0o600);
                let mut handle = options.open(&temporary)?;
                handle.write_all(replacement.as_bytes())?;
                handle.sync_all()?;
                drop(handle);
                std::fs::rename(temporary, path)?;
            }
        }
        Ok(())
    }

    pub fn start(&mut self) -> Result<(), StorageError> {
        if self.started {
            return Err(StorageError::AlreadyStarted);
        }

        let output = self.command("pg_ctl")?
            .arg("--pgdata")
            .arg(&self.config.data_dir)
            .arg("--log")
            .arg(&self.config.log_file)
            .arg("--options")
            .arg(self.config.server_options())
            .arg("--wait")
            .arg("start")
            .output()?;

        if let Err(error) = command_success("pg_ctl start", output) {
            append_runtime_diagnostic(&self.config.log_file, &error);
            return Err(error);
        }
        self.started = true;
        Ok(())
    }

    pub fn ensure_application_database(&self, password: &str) -> Result<(), StorageError> {
        if !self.started {
            return Err(StorageError::NotRunning);
        }
        if !self
            .config
            .database
            .chars()
            .all(|character| character.is_ascii_alphanumeric() || character == '_')
        {
            return Err(StorageError::RuntimeCommand(
                "invalid PostgreSQL application database name".to_owned(),
            ));
        }
        let mut check = self.command("psql")?;
        check
            .arg("--host")
            .arg(self.config.connection_host())
            .arg("--port")
            .arg(self.config.connection_port().to_string())
            .arg("--username")
            .arg(&self.config.username)
            .arg("--dbname")
            .arg("postgres")
            .arg("--set")
            .arg("ON_ERROR_STOP=1")
            .arg("--tuples-only")
            .arg("--no-align")
            .arg("--command")
            .arg(format!(
                "SELECT 1 FROM pg_database WHERE datname = '{}';",
                self.config.database
            ))
            .env("PGPASSWORD", password)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let output = check.output()?;
        command_success("check application database", output.clone())?;
        if !String::from_utf8_lossy(&output.stdout).trim().is_empty() {
            return Ok(());
        }

        let mut create = self.command("psql")?;
        create
            .arg("--host")
            .arg(self.config.connection_host())
            .arg("--port")
            .arg(self.config.connection_port().to_string())
            .arg("--username")
            .arg(&self.config.username)
            .arg("--dbname")
            .arg("postgres")
            .arg("--set")
            .arg("ON_ERROR_STOP=1")
            .arg("--command")
            .arg(format!("CREATE DATABASE \"{}\";", self.config.database))
            .env("PGPASSWORD", password)
            .stdout(Stdio::null())
            .stderr(Stdio::piped());
        command_success("create application database", create.output()?)
    }

    pub fn stop(&mut self) -> Result<(), StorageError> {
        if !self.started {
            return Err(StorageError::NotRunning);
        }

        let output = self.command("pg_ctl")?
            .arg("--pgdata")
            .arg(&self.config.data_dir)
            .arg("--mode")
            .arg("fast")
            .arg("--wait")
            .arg("stop")
            .output()?;

        command_success("pg_ctl stop", output)?;
        self.started = false;
        Ok(())
    }


    /// PL/Perl只读取同运行包的模块，清除宿主注入；其它平台沿用自己的运行包合同。
    fn command(&self, name: &str) -> Result<Command, StorageError> {
        let mut command = Command::new(self.executable(name));
        command.env_remove("PERL5OPT").env_remove("PERL5LIB").env_remove("PERLLIB");
        #[cfg(target_os = "macos")]
        {
            let core = self.config.bin_dir.parent().ok_or_else(|| {
                StorageError::RuntimeCommand("PostgreSQL运行包根不存在".to_owned())
            })?.join("share/perl");
            for path in [core.join("pure/strict.pm"), core.join("arch/Config.pm")] {
                if !path.is_file() {
                    return Err(StorageError::MissingExecutable(path));
                }
            }
            let paths = std::env::join_paths([core.join("pure"), core.join("arch")]).map_err(|_| {
                StorageError::RuntimeCommand("PL/Perl运行模块路径不能编码".to_owned())
            })?;
            command.env("PERL5LIB", paths);
        }
        Ok(command)
    }

    fn executable(&self, name: &str) -> PathBuf {
        self.config.bin_dir.join(executable_name(name))
    }
}

impl Drop for PostgresRuntime {
    fn drop(&mut self) {
        if self.started {
            let _ = self.stop();
        }
    }
}

fn command_success(name: &str, output: std::process::Output) -> Result<(), StorageError> {
    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(StorageError::RuntimeCommand(format!(
            "{name} exited with {}: {}",
            output.status,
            stderr.trim()
        )))
    }
}

/// Preserve the actionable local runtime error without exposing it through the
/// localized FFI response or risking database credentials in application UI.
fn append_runtime_diagnostic(log_file: &Path, error: &StorageError) {
    if let Some(parent) = log_file.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(mut log) = OpenOptions::new().create(true).append(true).open(log_file) {
        let _ = writeln!(log, "{error}");
    }
}

fn executable_name(name: &str) -> String {
    if cfg!(windows) {
        format!("{name}.exe")
    } else {
        name.to_owned()
    }
}

pub fn path_is_inside(path: &Path, parent: &Path) -> bool {
    path.starts_with(parent)
}
