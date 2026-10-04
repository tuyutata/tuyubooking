#[cfg(test)]
mod tests {
    use std::{collections::BTreeSet, fs, path::Path};
    use tuyubooking_native::subsystems::{
        ModuleRegistry, PlatformAccountPolicy, DATABASE_NAME,
    };

    #[test]
    fn modules_share_one_database_and_isolate_schemas() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .and_then(Path::parent)
            .expect("module contract crate must remain under test/module_contract");
        let module_root = root.join("modules");
        assert!(fs::read_dir(&module_root)
            .expect("flat module directory")
            .all(|entry| entry.expect("module entry").path().is_file()));
        let registry = ModuleRegistry::load(module_root).expect("valid module registry");
        assert_eq!(registry.modules().len(), 4);
        assert!(registry
            .modules()
            .iter()
            .all(|module| module.database.database == DATABASE_NAME));
        let schemas = registry
            .modules()
            .iter()
            .map(|module| module.database.schema.as_str())
            .collect::<BTreeSet<_>>();
        assert_eq!(schemas.len(), 4);
        assert!(schemas.iter().all(|schema| schema.starts_with("module_")));
        let kamra = registry
            .modules()
            .iter()
            .find(|module| module.id == "kamra")
            .expect("Kamra module");
        let ury = registry
            .modules()
            .iter()
            .find(|module| module.id == "ury")
            .expect("URY module");
        assert_ne!(kamra.database.schema, ury.database.schema);
        assert_eq!(ury.database.schema, "module_ury");

        let policy = PlatformAccountPolicy::default();
        assert!(policy.administrators_have_equal_access);
        assert_eq!(policy.authentication, "tuyu_sr25519");
    }
    #[test]
    fn source_registry_rejects_wrong_owner_path_commit_and_duplicate_modules() {
        use std::time::{SystemTime, UNIX_EPOCH};
        struct Temporary(std::path::PathBuf);
        impl Drop for Temporary {
            fn drop(&mut self) { let _ = fs::remove_dir_all(&self.0); }
        }
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap().parent().unwrap();
        let source = fs::read_to_string(root.join("modules/hi_events.module.toml")).unwrap();
        let temporary = Temporary(std::env::temp_dir().join(format!(
            "tuyubooking-module-source-{}-{}", std::process::id(),
            SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos()
        )));
        fs::create_dir(&temporary.0).unwrap();
        let manifest = temporary.0.join("hi_events.module.toml");
        fs::write(&manifest, &source).unwrap();
        assert!(ModuleRegistry::load(&temporary.0).is_ok());
        // 每项修改从同一正确清单出发，必须由真正的来源校验器拒绝。
        for (from, to) in [
            ("https://github.com/tuyutata/Hi.Events", "https://github.com/unregistered-owner/hi.events"),
            ("https://github.com/tuyutata/Hi.Events", "http://github.com/tuyutata/Hi.Events"),
            ("https://github.com/tuyutata/Hi.Events", "https://github.com/tuyutata/Hi.Events?branch=main"),
            ("upstream/hi_events", "upstream/../hi_events"),
            ("048243e2a99a65c8e77fc6f3cb44de158169855e", "main"),
            ("id = \"hi_events\"", "id = \"unknown\""),
        ] {
            assert!(source.contains(from), "fixture mutation must hit the real declaration");
            fs::write(&manifest, source.replace(from, to)).unwrap();
            assert!(ModuleRegistry::load(&temporary.0).is_err(), "{to}");
        }
        fs::write(&manifest, &source).unwrap();
        fs::write(temporary.0.join("duplicate.module.toml"), &source).unwrap();
        assert!(ModuleRegistry::load(&temporary.0).is_err());
        fs::remove_file(&manifest).unwrap();
        fs::remove_file(temporary.0.join("duplicate.module.toml")).unwrap();
        assert!(ModuleRegistry::load(&temporary.0).is_err());
    }

}
