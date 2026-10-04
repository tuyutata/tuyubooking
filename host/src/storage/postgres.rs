use crate::storage::{ConnectionMode, PostgresRuntimeConfig, StorageError};
use tokio::task::JoinHandle;
use tokio_postgres::{Client, Config, NoTls};

pub struct PostgresConnection {
    pub client: Client,
    task: JoinHandle<()>,
}

impl PostgresConnection {
    pub async fn connect(
        runtime: &PostgresRuntimeConfig,
        password: &str,
    ) -> Result<Self, StorageError> {
        let mut config = Config::new();
        config
            .user(&runtime.username)
            .password(password)
            .dbname(&runtime.database)
            .port(runtime.connection_port());

        match &runtime.connection {
            ConnectionMode::UnixSocket { directory, .. } => {
                config.host_path(directory);
            }
            ConnectionMode::LoopbackTcp { .. } => {
                config.host("127.0.0.1");
            }
        }

        let (client, connection) = config.connect(NoTls).await?;
        let task = tokio::spawn(async move {
            let _ = connection.await;
        });

        Ok(Self { client, task })
    }
}

impl Drop for PostgresConnection {
    fn drop(&mut self) {
        self.task.abort();
    }
}
