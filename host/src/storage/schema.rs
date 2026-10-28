use sha2::{Digest, Sha256};

/// 途遇商家端内置的唯一 SQL 结构基线，启动时以摘要确认本机结构与当前代码一致。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct EmbeddedSchema {
    pub schema_name: &'static str,
    pub sql: &'static str,
    pub schema_hash: &'static str,
}

const CORE_SQL: &str = include_str!("../../../host/database/tuyu_core.sql");

/// Native owns platform tables only; upstream applications own business schemas.
pub const CORE_SCHEMA: EmbeddedSchema = EmbeddedSchema {
    schema_name: "tuyu_core",
    sql: CORE_SQL,
    schema_hash: "72b2598a01cc186e041cd90b6dcd82df03979f0a65c80f68eb9efdbac39a324d",
};

pub fn sha256_hex(sql: &str) -> String {
    let digest = Sha256::digest(sql.as_bytes());
    format!("{digest:x}")
}
