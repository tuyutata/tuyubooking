use crate::storage::{EmbeddedSchema, StorageError, CORE_SCHEMA};
use tokio_postgres::Client;

pub struct SchemaExecutor;

impl SchemaExecutor {
    pub async fn apply(client: &Client) -> Result<bool, StorageError> {
        if Self::is_current(client, &CORE_SCHEMA).await? {
            return Ok(false);
        }

        // The schema and its completion marker are one database fact. Keeping
        // both operations in this transaction prevents a committed schema
        // without schema_state when startup is interrupted.
        let result = async {
            client.batch_execute("BEGIN;").await?;
            client.batch_execute(CORE_SCHEMA.sql).await?;
            client
                .execute(
                    "INSERT INTO tuyu_core.schema_state (schema_name, checksum_sha256) VALUES ($1, $2)",
                    &[&CORE_SCHEMA.name, &CORE_SCHEMA.sha256],
                )
                .await?;
            client.batch_execute("COMMIT;").await?;
            Ok::<(), tokio_postgres::Error>(())
        }
        .await;

        if let Err(error) = result {
            let _ = client.batch_execute("ROLLBACK;").await;
            return Err(StorageError::SchemaExecution {
                schema_name: CORE_SCHEMA.name.to_owned(),
                message: error.to_string(),
            });
        }

        Ok(true)
    }

    async fn is_current(client: &Client, schema: &EmbeddedSchema) -> Result<bool, StorageError> {
        let state_exists: bool = client
            .query_one(
                "SELECT to_regclass('tuyu_core.schema_state') IS NOT NULL",
                &[],
            )
            .await?
            .get(0);

        if !state_exists {
            return Ok(false);
        }

        let row = client
            .query_opt(
                "SELECT checksum_sha256 FROM tuyu_core.schema_state WHERE schema_name = $1",
                &[&schema.name],
            )
            .await?;

        match row {
            None => Ok(false),
            Some(row) => {
                let stored: String = row.get(0);
                if stored == schema.sha256 {
                    Ok(true)
                } else {
                    Err(StorageError::SchemaChecksumMismatch {
                        schema_name: schema.name.to_owned(),
                    })
                }
            }
        }
    }

    pub async fn execute_transactional_probe(
        client: &Client,
        sql: &str,
    ) -> Result<(), StorageError> {
        if let Err(error) = client.batch_execute(sql).await {
            let _ = client.batch_execute("ROLLBACK;").await;
            return Err(StorageError::SchemaExecution {
                schema_name: "transactional_probe".to_owned(),
                message: error.to_string(),
            });
        }
        Ok(())
    }
}
