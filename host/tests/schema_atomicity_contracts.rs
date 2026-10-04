#[test]
fn core_schema_and_completion_marker_share_one_executor_transaction() {
    let schema = include_str!("../database/tuyu_core.sql");
    let executor = include_str!("../src/storage/schema_executor.rs");

    assert!(!schema.lines().any(|line| line.trim() == "BEGIN;"));
    assert!(!schema.lines().any(|line| line.trim() == "COMMIT;"));

    let begin = executor.find("batch_execute(\"BEGIN;\")").expect("BEGIN");
    let schema_execution = executor
        .find("batch_execute(CORE_SCHEMA.sql)")
        .expect("schema execution");
    let completion_marker = executor
        .find("INSERT INTO tuyu_core.schema_state")
        .expect("schema completion marker");
    let commit = executor.find("batch_execute(\"COMMIT;\")").expect("COMMIT");

    assert!(begin < schema_execution);
    assert!(schema_execution < completion_marker);
    assert!(completion_marker < commit);
    assert!(executor.contains("client.batch_execute(\"ROLLBACK;\")"));
}
