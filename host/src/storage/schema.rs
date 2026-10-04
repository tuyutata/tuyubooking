use sha2::{Digest, Sha256};

/// 途遇商家端内置的唯一 SQL 结构基线，启动时以摘要确认本机结构与当前代码一致。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct EmbeddedSchema {
    pub name: &'static str,
    pub schema: &'static str,
    pub sql: &'static str,
    pub sha256: &'static str,
}

const CORE_SQL: &str = include_str!("../../../host/database/tuyu_core.sql");

/// Native owns platform tables only; upstream applications own business schemas.
pub const CORE_SCHEMA: EmbeddedSchema = EmbeddedSchema {
    name: "tuyu_core",
    schema: "tuyu_core",
    sql: CORE_SQL,
    sha256: "9eda6c2ee37e9e9a35aa021e2b63f750e9e766fe131cc45efca541808d43b311",
};

pub fn sha256_hex(sql: &str) -> String {
    let digest = Sha256::digest(sql.as_bytes());
    format!("{digest:x}")
}
