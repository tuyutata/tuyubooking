#[cfg(test)]
mod tests {
    use serde::Deserialize;
    use std::{
        collections::BTreeSet,
        fs,
        path::{Path, PathBuf},
    };

    #[derive(Deserialize)]
    struct LockFile {
        schema_version: u32,
        dependency_mode: String,
        sources: Vec<Source>,
    }

    #[derive(Deserialize)]
    struct Source {
        id: String,
        domain: String,
        repository: String,
        revision: String,
        commit: String,
        module_manifest: String,
        license_source: String,
        license_copy: String,
        required_files: Vec<String>,
        #[serde(default)]
        nested_sources: Vec<NestedSource>,
    }

    #[derive(Deserialize)]
    struct NestedSource {
        path: String,
        repository: String,
        commit: String,
    }

    fn root() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .and_then(Path::parent)
            .expect("source intake crate must remain under test/source_intake")
            .to_path_buf()
    }

    #[test]
    fn fork_subtrees_are_pinned_and_licensed() {
        let lock: LockFile = serde_json::from_slice(
            &fs::read(root().join("tuyubooking.sources.json")).expect("read source lock"),
        )
        .expect("parse source lock");
        assert_eq!(lock.schema_version, 3);
        assert_eq!(lock.dependency_mode, "git_subtree");
        let gitmodules = fs::read_to_string(
            root().join(".gitmodules"),
        )
        .unwrap_or_default();
        let ids = lock
            .sources
            .iter()
            .map(|source| source.id.as_str())
            .collect::<BTreeSet<_>>();
        assert_eq!(
            ids,
            BTreeSet::from([
                "erpnext",
                "frappe",
                "hi_events",
                "hrms",
                "kamra",
                "ury",
                "voyant",
            ])
        );

        for source in lock.sources {
            assert!(["framework", "hotel", "restaurant", "tour", "ticket"]
                .contains(&source.domain.as_str()));
            // 按固定模块坐标核对现行来源，不把同一账号下任意仓库视为合法输入。
            let repository_name = match source.id.as_str() {
                "hi_events" => "Hi.Events",
                "kamra" => "kamra-pms",
                id => id,
            };
            assert_eq!(
                source.repository,
                format!("https://github.com/tuyutata/{repository_name}")
            );
            assert!(!["main", "develop", "latest"].contains(&source.revision.as_str()));
            assert!(source.commit.len() == 40 && source.commit.bytes().all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)));
            assert!(root().join(&source.module_manifest).is_file());

            let directory = root().join("upstream").join(&source.id);
            assert!(
                !directory.join(".git").exists(),
                "subtree must not retain nested Git metadata for {}",
                source.id
            );
            assert!(
                !gitmodules.contains(&format!("path = upstream/{}", source.id)),
                "subtree must not remain registered as a submodule for {}",
                source.id
            );
            for required in source.required_files {
                assert!(
                    directory.join(required).is_file(),
                    "missing required file for {}",
                    source.id
                );
            }
            for nested in source.nested_sources {
                assert!(nested.repository.starts_with("https://github.com/"));
                assert_eq!(nested.commit.len(), 40);
                assert!(directory.join(nested.path).is_dir());
            }
            assert_eq!(
                fs::read(root().join(source.license_source)).expect("read upstream license"),
                fs::read(root().join(source.license_copy)).expect("read copied license"),
                "license drift for {}",
                source.id
            );
        }

        assert!(
            walkdir::WalkDir::new(root().join("upstream"))
                .into_iter()
                .filter_map(Result::ok)
                .all(|entry| entry.file_name() != ".git"),
            "subtree source tree must not contain nested Git metadata"
        );

        // DMC 本机运行使用直接 PostgreSQL，合同禁止索引边界重新收窄到 Neon。
        let catalog_bridge = fs::read_to_string(
            root().join("upstream/voyant/templates/dmc/src/api/catalog-bridge.ts"),
        )
        .expect("read Voyant DMC catalog bridge");
        assert!(catalog_bridge.contains("import type { AnyDrizzleDb } from \"@voyantjs/db\""));
        assert!(catalog_bridge.contains("function buildIndexerContext(db: AnyDrizzleDb)"));
        assert!(!catalog_bridge.contains("NeonDatabase"));
    }

    #[test]
    fn source_module_and_runtime_pins_agree() {
        // 真实来源清单、模块声明与运行锁必须消费同一固定提交，禁止只检查字符串长度。
        let lock: LockFile = serde_json::from_slice(
            &fs::read(root().join("tuyubooking.sources.json")).expect("read source lock"),
        ).expect("parse source lock");
        let runtime: serde_json::Value = serde_json::from_slice(
            &fs::read(root().join("scripts/business-runtime/runtime.lock.json")).expect("read runtime lock"),
        ).expect("parse runtime lock");
        for source in lock.sources {
            let runtime_commit = match source.id.as_str() {
                "voyant" | "hi_events" => runtime[&source.id]["commit"].as_str(),
                id => runtime[format!("{id}_commit")].as_str(),
            };
            assert_eq!(runtime_commit, Some(source.commit.as_str()), "runtime source drift: {}", source.id);
            // ERPNext、HRMS是URY模块的依赖；其独立提交由运行锁校验，不冒充URY主源码。
            if ["erpnext", "hrms"].contains(&source.id.as_str()) { continue; }
            let manifest = fs::read_to_string(root().join(&source.module_manifest)).expect("read module source");
            let section = manifest.split("[source]").nth(1).expect("source section")
                .split("\n[").next().expect("source section body");
            for (key, expected) in [("repository", source.repository.as_str()), ("commit", source.commit.as_str())] {
                let values: Vec<_> = section.lines().filter_map(|line| {
                    let (name, value) = line.split_once('=')?;
                    (name.trim() == key).then(|| value.trim().trim_matches('"'))
                }).collect();
                assert_eq!(values, [expected], "module source missing, duplicated or stale: {}.{key}", source.id);
            }
        }
    }

}
