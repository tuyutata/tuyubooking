use std::path::PathBuf;

use schnorrkel::{signing_context, Keypair};
use tuyu_account::{login_signing_digest, LoginResponseBody, TUYU_PROTOCOL, TUYU_VERSION};
use tuyubooking_native::application::{
    ApplicationServices, AuthenticatedSession, QrLoginChallenge, QrLoginResponse,
};

pub fn postgres_bin_dir() -> PathBuf {
    let configured = std::env::var_os("TUYU_POSTGRES_BIN")
        .expect("TUYU_POSTGRES_BIN must name the verified source-external PostgreSQL bin directory");
    checked_postgres_bin_dir(&PathBuf::from(configured))
        .expect("TUYU_POSTGRES_BIN must contain the complete source-external PostgreSQL runtime")
}

// 集成测试只接收调用方完成物化与验真的真实目录；不查找PATH或产品源码内的旧发行件。
fn checked_postgres_bin_dir(bin: &std::path::Path) -> Result<PathBuf, &'static str> {
    if !bin.is_absolute() || !bin.is_dir() {
        return Err("PostgreSQL bin directory must be an absolute existing directory");
    }
    let canonical = bin.canonicalize().map_err(|_| "cannot canonicalize PostgreSQL bin directory")?;
    let source = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent().ok_or("native crate must belong to the product")?
        .canonicalize().map_err(|_| "cannot canonicalize product source")?;
    if canonical != bin || canonical.starts_with(&source) || source.starts_with(&canonical) {
        return Err("PostgreSQL runtime must be outside the product source and contain no path aliases");
    }
    for name in ["postgres", "initdb", "pg_ctl", "psql"] {
        let executable = if cfg!(windows) { format!("{name}.exe") } else { name.to_owned() };
        let path = canonical.join(executable);
        let metadata = path.symlink_metadata().map_err(|_| "PostgreSQL executable is missing")?;
        if !metadata.is_file() || metadata.file_type().is_symlink()
            || path.canonicalize().map_err(|_| "cannot canonicalize PostgreSQL executable")? != path {
            return Err("PostgreSQL executable must be a regular unaliased file");
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            if metadata.permissions().mode() & 0o111 == 0 {
                return Err("PostgreSQL executable has no execute permission");
            }
        }
    }
    Ok(canonical)
}

// 直接验证消费边界，避免环境变量互斥和真假数据库测试互相污染。
#[test]
fn postgres_test_input_requires_complete_external_runtime() {
    let temp = tempfile::TempDir::new().unwrap();
    let bin = temp.path().canonicalize().unwrap().join("bin");
    std::fs::create_dir(&bin).unwrap();
    assert!(checked_postgres_bin_dir(std::path::Path::new("relative/bin")).is_err());
    assert!(checked_postgres_bin_dir(&bin).is_err());
    for name in ["postgres", "initdb", "pg_ctl", "psql"] {
        let path = bin.join(if cfg!(windows) { format!("{name}.exe") } else { name.to_owned() });
        std::fs::write(&path, b"test runtime input").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700)).unwrap();
        }
    }
    assert_eq!(checked_postgres_bin_dir(&bin).unwrap(), bin);
    assert!(checked_postgres_bin_dir(&PathBuf::from(env!("CARGO_MANIFEST_DIR"))).is_err());
    #[cfg(unix)]
    {
        let alias = temp.path().join("alias");
        std::os::unix::fs::symlink(&bin, &alias).unwrap();
        assert!(checked_postgres_bin_dir(&alias).is_err());
        let executable = bin.join("postgres");
        std::fs::remove_file(&executable).unwrap();
        std::os::unix::fs::symlink(bin.join("psql"), &executable).unwrap();
        assert!(checked_postgres_bin_dir(&bin).is_err());
    }
}

pub fn signed_response(challenge: &QrLoginChallenge, pair: &Keypair) -> QrLoginResponse {
    let public_key = pair.public.to_bytes();
    let digest = login_signing_digest(challenge, &public_key).unwrap();
    let signature = pair.sign(signing_context(b"substrate").bytes(&digest));
    QrLoginResponse {
        p: TUYU_PROTOCOL.to_owned(),
        v: TUYU_VERSION,
        k: 2,
        i: challenge.i.clone(),
        e: challenge.e,
        b: LoginResponseBody {
            u: canonical_hex(&public_key),
            s: canonical_hex(&signature.to_bytes()),
        },
    }
}

pub async fn initialize_administrator(
    services: &ApplicationServices,
    pair: &Keypair,
    name: Option<&str>,
) -> AuthenticatedSession {
    let challenge = services.create_qr_login_challenge().await.unwrap();
    services
        .initialize_administrator(signed_response(&challenge, pair), name)
        .await
        .unwrap()
}

fn canonical_hex(bytes: &[u8]) -> String {
    format!(
        "0x{}",
        bytes
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>()
    )
}
