use std::{fs, path::PathBuf};

fn product_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

#[test]
fn frappe_postcss_entry_points_are_confined_to_the_plugin_temp_directory() {
    let script = fs::read_to_string(
        product_root().join("scripts/business-runtime/build_frappe_assets.sh"),
    )
    .expect("read Frappe asset build script");

    assert!(script.contains("@frappe/esbuild-plugin-postcss2/dist/index.js"));
    assert!(script.contains("tmpDirPath, uniqueId()"));
    assert!(script.contains("postcss2 entry-point temp-path contract drifted"));
    assert!(script.contains("if (count !== 1)"));
}
