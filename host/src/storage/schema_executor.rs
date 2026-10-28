use crate::storage::{EmbeddedSchema, StorageError, CORE_SCHEMA};
use tokio_postgres::Client;

pub struct SchemaExecutor;

impl SchemaExecutor {
    pub async fn apply(client: &Client) -> Result<bool, StorageError> {
        if Self::is_current(client, &CORE_SCHEMA).await? {
            return Ok(false);
        }

        // 中文注释：DDL与完成标记属于同一事务，初始化中断不能留下已提交的半套结构。
        let result = async {
            client.batch_execute("BEGIN;").await?;
            client.batch_execute(CORE_SCHEMA.sql).await?;
            client
                .execute(
                    "INSERT INTO tuyu_core.baselines (schema_name, schema_hash) VALUES ($1, $2)",
                    &[&CORE_SCHEMA.schema_name, &CORE_SCHEMA.schema_hash],
                )
                .await?;
            client.batch_execute("COMMIT;").await?;
            Ok::<(), tokio_postgres::Error>(())
        }
        .await;

        if let Err(error) = result {
            let _ = client.batch_execute("ROLLBACK;").await;
            return Err(StorageError::SchemaExecution {
                schema_name: CORE_SCHEMA.schema_name.to_owned(),
                message: error.to_string(),
            });
        }

        Ok(true)
    }

    async fn is_current(client: &Client, schema: &EmbeddedSchema) -> Result<bool, StorageError> {
        let state_exists: bool = client
            .query_one("SELECT to_regclass('tuyu_core.baselines') IS NOT NULL", &[])
            .await?
            .get(0);

        if !state_exists {
            // 中文注释：没有基线只允许空的所属 Schema；旧结构不能旁建新表或自动重建。
            let occupied: bool = client.query_one(
                "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'tuyu_core')",
                &[],
            ).await?.get(0);
            if occupied {
                return Err(StorageError::SchemaChecksumMismatch {
                    schema_name: schema.schema_name.to_owned(),
                });
            }
            return Ok(false);
        }

        let row = client
            .query_opt(
                "SELECT schema_hash FROM tuyu_core.baselines WHERE schema_name = $1",
                &[&schema.schema_name],
            )
            .await?;

        match row {
            None => Err(StorageError::SchemaChecksumMismatch {
                schema_name: schema.schema_name.to_owned(),
            }),
            Some(row) => {
                let stored: String = row.get(0);
                if stored == schema.schema_hash {
                    Ok(true)
                } else {
                    Err(StorageError::SchemaChecksumMismatch {
                        schema_name: schema.schema_name.to_owned(),
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
