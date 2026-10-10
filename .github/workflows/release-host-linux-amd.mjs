#!/usr/bin/env node
import {bookingRelease} from './release-client-android.mjs';
// 本仓本目标的完整自动化只由同名Workflow调用；版本与产物均在GitHub生成。
import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import { appendFileSync, copyFileSync, createReadStream, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const owner = Object.freeze({
  "product": "tuyubooking",
  "platform": "host-linux-amd",
  "repository": "tuyutata/tuyubooking",
  "version_source": {
    "kind": "pubspec",
    "path": "app/pubspec.yaml"
  },
  "required_assets": [],
  "asset_locations": [
    "$RELEASE_DIR",
    "$RUNNER_TEMP/tuyubooking-host-release"
  ],
  "asset_patterns": [
    "*.tgz",
    "*.zip",
    "*.ipa",
    "*.apk",
    "*.aab",
    "*.json",
    "SHA256SUMS",
    "TuyuBookingHost-LinuxAMD.deb"
  ],
  "required_patterns": [
    "TuyuBookingHost-LinuxAMD.deb",
    "release-manifest.json",
    "SHA256SUMS"
  ]
});
const commands = Object.freeze({
  "4": {
    "shell": "bash",
    "source": "set -euo pipefail\nexport TUYUBOOKING_SHELL_BIN=\"$(node -e 'process.stdout.write(require(\"node:fs\").realpathSync(process.argv[1]))' \"$BASH\")\"\n\nnode \"$GITHUB_WORKSPACE/.github/workflows/release-host-linux-amd.mjs\" action package build-release"
  },
  "2": {
    "shell": "bash",
    "source": "# 安装后先验真，再统一准备目标平台缓存与受控修订。\nflutter --version --machine >/dev/null\nplatform=\"linux-amd\"\nflutter --version >/dev/null"
  },
  "3": {
    "shell": "bash",
    "source": "sudo apt-get update && sudo apt-get install -y clang ninja-build pkg-config libgtk-3-dev liblzma-dev binutils file patchelf dpkg-dev"
  },
  "1": {
    "shell": "bash",
    "source": "printf 'version=3.47.2\n' >> \"$GITHUB_OUTPUT\""
  }
});
const actions = Object.freeze({
  "package": {
    "source": "#!/usr/bin/env node\nimport { execFileSync, spawnSync } from 'node:child_process';\nimport { createHash } from 'node:crypto';\nimport { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';\nimport { join } from 'node:path';\nconst identity = Object.freeze({ product: 'tuyubooking', platform: 'host-linux-amd', prefix: 'tuyubooking-host-linux-amd-v',   artifact: 'TuyuBookingHost-LinuxAMD.deb' });\nconst root = process.cwd(); const output = join(process.env.RUNNER_TEMP || '/tmp', 'tuyubooking-host-release');\nfunction required(value, message) { if (!value) throw new Error(message); }\n\n\nfunction run(file, args, cwd = root, extraEnv = {}) { execFileSync(file, args, { cwd, stdio: 'inherit', env: { ...process.env, ...extraEnv } }); }\nfunction hash(path) { return createHash('sha256').update(readFileSync(path)).digest('hex'); }\nfunction inputs() { return {repository:process.env.GITHUB_REPOSITORY,source:process.env.SOURCE_SHA,sourceSHA:process.env.SOURCE_SHA,version:process.env.SOFTWARE_VERSION,tag:process.env.VERSION_TAG,runID:process.env.GITHUB_RUN_ID,runId:process.env.GITHUB_RUN_ID}; }\nfunction verify(value) { if (execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim() !== process.env.SOURCE_SHA) throw new Error('本仓源码提交不一致'); }\n\nfunction manifest(value) { const asset = join(output, identity.artifact); required(existsSync(asset), 'Linux 正式资产不存在'); const body = { product_id: identity.product, platform: identity.platform, software_version: value.version, git_commit_sha: value.source, producer_run_id: Number(value.runID), assets: [{ name: identity.artifact, sha256: hash(asset) }] }; const manifestPath = join(output, 'release-manifest.json'); writeFileSync(manifestPath, `${JSON.stringify(body, null, 2)}\\n`); writeFileSync(join(output, 'SHA256SUMS'), `${[`${hash(asset)}  ${identity.artifact}`, `${hash(manifestPath)}  release-manifest.json`].sort().join('\\n')}\\n`); }\nfunction build(value) { verify(value); mkdirSync(output); run('git', ['submodule', 'status', '--recursive']); run(process.execPath, [join(root, '.github/workflows/release-host-linux-amd.mjs'), 'action', 'sourcecheck'], root); run(process.execPath, [join(root, '.github/workflows/release-host-linux-amd.mjs'), 'action', 'assemble'], root, { TUYUBOOKING_WORK_DIR: join(output, 'work'), TUYU_SERVE_URL: 'https://serve.tuyulove.com', TUYU_BOOKING_VERSION: value.version }); const source = join(output, 'work', 'TuyuBooking-LinuxAMD.deb'); required(existsSync(source), 'Linux AMD64 Debian 正式包未生成'); run('dpkg-deb', ['--field', source, 'Architecture']); required(execFileSync('dpkg-deb', ['--field', source, 'Architecture'], { encoding: 'utf8' }).trim() === 'amd64', 'Linux 正式包不是 AMD64'); cpSync(source, join(output, identity.artifact)); manifest(value); }\n\n\nconst command=process.argv[2];\nif(command==='build-release'){await build({...inputs(),build:process.env.GITHUB_RUN_NUMBER});}else{throw new Error('本仓组包动作无效');}\n",
    "shell": "node"
  },
  "assemble": {
    "source": "#!/usr/bin/env bash\nset -euo pipefail\n\nROOT=\"${GITHUB_WORKSPACE:?缺少本仓检出根}\"\nSCRIPT_DIR=\"$ROOT/.github/workflows\"\n# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。\nPRODUCT_TARGET_TEMP_ROOT=\"${RUNNER_TEMP:?缺少Runner临时根}\"\nexport TMPDIR=\"$PRODUCT_TARGET_TEMP_ROOT\"\nWORK_DIR=\"${TUYUBOOKING_WORK_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/linux-amd}\"\nmkdir -p \"$WORK_DIR\"\nWORK_DIR=\"$(cd \"$WORK_DIR\" && pwd -P)\"\nDESKTOP=\"$(node \"$ROOT/app/scripts/project.mjs\" create --source-root \"$ROOT/app\" --work-root \"$WORK_DIR\" --platform linux-amd)\"\nRUNTIME=\"$WORK_DIR/runtime/postgresql/linux-amd\"\nexport TUYUBOOKING_ROOT=\"$ROOT\"\nexport CARGO_TARGET_DIR=\"${CARGO_TARGET_DIR:-$WORK_DIR/cargo}\"\nBUSINESS_SOURCE=\"${TUYU_BUSINESS_RUNTIME_SOURCE:-$ROOT/host/runtime/business/linux-amd}\"\nTUYU_SERVE_URL=\"${TUYU_SERVE_URL:?TUYU_SERVE_URL must be an HTTPS origin}\"\n\nif [ \"$(uname -s)\" != Linux ]; then\n  echo \"Linux package building requires a Linux release host\" >&2\n  exit 1\nfi\ncase \"$(uname -m)\" in\n  x86_64|amd64) ;;\n  *) echo \"Linux package building requires an AMD64 release host\" >&2; exit 1 ;;\nesac\ncase \"$TUYU_SERVE_URL\" in\n  https://*) ;;\n  *) echo \"TUYU_SERVE_URL must use HTTPS\" >&2; exit 1 ;;\nesac\n\nfor command_name in flutter cargo dpkg-deb readelf patchelf sha256sum; do\n  command -v \"$command_name\" >/dev/null || {\n    echo \"missing release-host command: $command_name\" >&2\n    exit 1\n  }\ndone\n\nTUYU_POSTGRES_DEST=\"$RUNTIME\" \"${NODE:-node}\" \"$ROOT/.github/workflows/release-host-linux-amd.mjs\" action runtime\n(\n  cd \"$DESKTOP\"\n  flutter pub get --enforce-lockfile\n  node \"$ROOT/app/scripts/project.mjs\" native --source-root \"$ROOT/app\" \\\n    --work-root \"$WORK_DIR\" --output \"$DESKTOP\" --platform linux-amd >/dev/null\n  flutter test\n  flutter build linux --release --target lib/main_host.dart \\\n    --dart-define=\"TUYU_SERVE_URL=$TUYU_SERVE_URL\"\n)\n(\n  cd \"$ROOT\"\n  TUYU_POSTGRES_BIN=\"$RUNTIME/bin\" cargo test --workspace --locked\n  cargo build --release --locked --target x86_64-unknown-linux-gnu -p tuyubooking-native\n)\n\nmapfile -t bundles < <(find \"$DESKTOP/build/linux\" -type d -path '*/release/bundle' -print)\nif [ \"${#bundles[@]}\" -ne 1 ]; then\n  echo \"expected one Flutter Linux release bundle, found ${#bundles[@]}\" >&2\n  exit 1\nfi\nbundle=\"${bundles[0]}\"\nnative=\"$CARGO_TARGET_DIR/x86_64-unknown-linux-gnu/release/libtuyubooking_native.so\"\ntest -f \"$native\" || { echo \"missing Rust Linux library: $native\" >&2; exit 1; }\n\nversion=\"${TUYU_BOOKING_VERSION:-$(awk '/^version:/ {print $2; exit}' \"$DESKTOP/pubspec.yaml\")}\"\nstage=\"$(mktemp -d \"$WORK_DIR/package-stage.XXXXXX\")\"\ntemporary_package=\"$WORK_DIR/TuyuBooking-LinuxAMD.deb.partial\"\npackage=\"$WORK_DIR/TuyuBooking-LinuxAMD.deb\"\ntrap 'find \"$stage\" -depth -delete 2>/dev/null || true; find \"$temporary_package\" -delete 2>/dev/null || true' EXIT\n\napp=\"$stage/opt/tuyubooking\"\nmkdir -p \"$app/lib\" \"$stage/DEBIAN\" \"$stage/usr/bin\" \\\n  \"$stage/usr/share/applications\" \"$stage/usr/share/icons/hicolor/256x256/apps\"\ncp -a \"$bundle/.\" \"$app/\"\ncp \"$native\" \"$app/lib/libtuyubooking_native.so\"\ncp -a \"$RUNTIME\" \"$app/postgresql\"\n\"${NODE:-node}\" \"$ROOT/.github/workflows/release-host-linux-amd.mjs\" action materialize \"$BUSINESS_SOURCE\" \"$app/business\"\ncp \"$ROOT/host/tuyubooking.desktop\" \"$stage/usr/share/applications/com.tuyulove.tuyubooking.host.desktop\"\ncp \"$DESKTOP/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png\" \\\n  \"$stage/usr/share/icons/hicolor/256x256/apps/com.tuyulove.tuyubooking.host.png\"\nln -s /opt/tuyubooking/tuyubooking \"$stage/usr/bin/tuyubooking\"\nsed \"s/@VERSION@/$version/g\" \"$ROOT/host/database/control-linux-amd.template\" > \"$stage/DEBIAN/control\"\n\n# Every packaged application ELF uses a location relative to itself. The\n# PostgreSQL runtime already has its own verified RPATH and is left untouched.\nwhile IFS= read -r elf_file; do\n  case \"$elf_file\" in\n    \"$app/postgresql/\"*|\"$app/business/\"*) continue ;;\n    \"$app/tuyubooking\") runtime_path='$ORIGIN/lib' ;;\n    \"$app/lib/\"*) runtime_path='$ORIGIN' ;;\n    *) runtime_path='$ORIGIN' ;;\n  esac\n  patchelf --set-rpath \"$runtime_path\" \"$elf_file\"\ndone < <(find \"$app\" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do readelf -h \"$candidate\" >/dev/null 2>&1 && printf '%s\\n' \"$candidate\"; done)\n\"${NODE:-node}\" \"$ROOT/.github/workflows/release-host-linux-amd.mjs\" action verify-bundle \"$stage\"\ndpkg-deb --build --root-owner-group \"$stage\" \"$temporary_package\"\ndpkg-deb --field \"$temporary_package\" Architecture | grep -qx amd64\nmv \"$temporary_package\" \"$package\"\nhash=\"$(sha256sum \"$package\" | awk '{print $1}')\"\nprintf '%s *%s\\n' \"$hash\" \"$(basename \"$package\")\" > \"$package.sha256\"\necho \"built TuyuBooking Linux AMD64 package: $package\"\n",
    "shell": "bash"
  },
  "runtime": {
    "source": "#!/usr/bin/env bash\nset -euo pipefail\n\nROOT=\"${GITHUB_WORKSPACE:?缺少本仓检出根}\"\nSCRIPT_DIR=\"$ROOT/.github/workflows\"\nLOCK=\"$ROOT/host/database/postgresql-linux-amd.lock.json\"\n# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。\nPRODUCT_TARGET_TEMP_ROOT=\"${RUNNER_TEMP:?缺少Runner临时根}\"\nexport TMPDIR=\"$PRODUCT_TARGET_TEMP_ROOT\"\nDEST=\"${TUYU_POSTGRES_DEST:-${TUYUBOOKING_ARTIFACT_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/artifacts}/postgresql/linux-amd}\"\nDEPENDENCY_DIR=\"${TUYUBOOKING_DEPENDENCY_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/dependencies}\"\nBUILD_PARENT=\"${TUYUBOOKING_BUILD_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/build}\"\n\nif [ \"$(uname -s)\" != Linux ]; then\n  echo \"Linux PostgreSQL scripts requires a Linux release host\" >&2\n  exit 1\nfi\ncase \"$(uname -m)\" in\n  x86_64|amd64) ;;\n  *) echo \"Linux PostgreSQL scripts requires an AMD64 release host\" >&2; exit 1 ;;\nesac\n\nfor command_name in python3 node curl sha256sum tar make gcc readelf patchelf ldd dpkg-query; do\n  command -v \"$command_name\" >/dev/null || {\n    echo \"missing release-host command: $command_name\" >&2\n    exit 1\n  }\ndone\n\nlock_values=\"$(python3 - \"$LOCK\" <<'PY'\nimport json\nimport sys\n\nwith open(sys.argv[1], encoding=\"utf-8\") as source:\n    lock = json.load(source)\nprint(\"\\t\".join((lock[\"version\"], lock[\"source_url\"], lock[\"source_sha256\"], lock[\"install_prefix\"])))\nPY\n)\"\nIFS=$'\\t' read -r version source_url source_sha install_prefix <<< \"$lock_values\"\ncase \"$source_url\" in\n  https://*) ;;\n  *) echo \"PostgreSQL source URL must use HTTPS\" >&2; exit 1 ;;\nesac\n\nmkdir -p \"$DEPENDENCY_DIR/archives\" \"$BUILD_PARENT\"\narchive=\"${POSTGRES_SOURCE_ARCHIVE:-$DEPENDENCY_DIR/archives/postgresql-$version.tar.bz2}\"\nif [ ! -f \"$archive\" ]; then\n  pending=\"$archive.pending.$$\"\n  for attempt in 1 2 3; do\n    rm -f -- \"$pending\"\n    if curl --fail --location --silent --show-error --output \"$pending\" \"$source_url\" \\\n      && printf '%s  %s\\n' \"$source_sha\" \"$pending\" | sha256sum --check --status -; then\n      mv \"$pending\" \"$archive\"; break\n    fi\n  done\n  rm -f -- \"$pending\"\nfi\ntest -f \"$archive\" && test ! -L \"$archive\" || { echo 'PostgreSQL原件不存在或是符号链接' >&2; exit 1; }\nprintf '%s  %s\\n' \"$source_sha\" \"$archive\" | sha256sum --check --status - || {\n  echo \"PostgreSQL source checksum mismatch\" >&2\n  exit 1\n}\n\nwork=\"$(mktemp -d \"$BUILD_PARENT/postgresql-linux-amd.XXXXXX\")\"\ntrap 'find \"$work\" -depth -delete 2>/dev/null || true' EXIT\ntar -xjf \"$archive\" -C \"$work\"\nsource_root=\"$work/postgresql-$version\"\nbuild_root=\"$work/build\"\ninstall_root=\"$work/install\"\nmkdir -p \"$build_root\" \"$install_root\"\n\n(\n  cd \"$build_root\"\n  \"$source_root/configure\" --prefix=\"$install_prefix\" --without-readline\n  make -j \"${BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN)}\"\n  make DESTDIR=\"$install_root\" install\n)\n\ninstalled=\"$install_root$install_prefix\"\nmkdir -p \"$DEST/bin\" \"$DEST/lib\" \"$DEST/share\" \"$DEST/licenses\"\nfind \"$DEST/bin\" \"$DEST/lib\" \"$DEST/share\" \"$DEST/licenses\" -mindepth 1 -delete\ncp -a \"$installed/bin/.\" \"$DEST/bin/\"\ncp -a \"$installed/lib/.\" \"$DEST/lib/\"\ncp -a \"$installed/share/.\" \"$DEST/share/\"\ncp \"$source_root/COPYRIGHT\" \"$DEST/licenses/PostgreSQL-COPYRIGHT\"\n\nis_elf() {\n  readelf -h \"$1\" >/dev/null 2>&1\n}\n\nis_system_runtime() {\n  case \"$(basename \"$1\")\" in\n    ld-linux-x86-64.so.*|libc.so.*|libdl.so.*|libm.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|libutil.so.*) return 0 ;;\n    *) return 1 ;;\n  esac\n}\n\ncomponent_file=\"$work/components.txt\"\n: > \"$component_file\"\nwhile :; do\n  added=0\n  while IFS= read -r elf_file; do\n    while IFS= read -r dependency; do\n      [ -n \"$dependency\" ] || continue\n      is_system_runtime \"$dependency\" && continue\n      resolved=\"$(readlink -f \"$dependency\")\"\n      destination=\"$DEST/lib/$(basename \"$resolved\")\"\n      if [ ! -f \"$destination\" ]; then\n        cp \"$resolved\" \"$destination\"\n        chmod u+w \"$destination\"\n        added=1\n      fi\n      dependency_name=\"$(basename \"$dependency\")\"\n      if [ \"$dependency_name\" != \"$(basename \"$resolved\")\" ] && [ ! -e \"$DEST/lib/$dependency_name\" ]; then\n        ln -s \"$(basename \"$resolved\")\" \"$DEST/lib/$dependency_name\"\n        added=1\n      fi\n      package_spec=\"$(dpkg-query -S \"$dependency\" 2>/dev/null | head -1 | cut -d: -f1 || true)\"\n      if [ -z \"$package_spec\" ]; then\n        echo \"cannot identify Debian package for bundled dependency: $dependency\" >&2\n        exit 1\n      fi\n      package_version=\"$(dpkg-query -W -f='${Version}' \"$package_spec\")\"\n      [ -n \"$package_version\" ] || {\n        echo \"cannot identify package version for bundled dependency: $package_spec\" >&2\n        exit 1\n      }\n      copyright_source=\"/usr/share/doc/$package_spec/copyright\"\n      [ -f \"$copyright_source\" ] || {\n        echo \"missing Debian copyright file for bundled dependency: $package_spec\" >&2\n        exit 1\n      }\n      printf '%s\\t%s\\n' \"$package_spec\" \"$package_version\" >> \"$component_file\"\n      mkdir -p \"$DEST/licenses/$package_spec\"\n      cp \"$copyright_source\" \"$DEST/licenses/$package_spec/copyright\"\n    done < <(ldd \"$elf_file\" | awk '/=> \\// {print $3} /^\\// {print $1}')\n  done < <(find \"$DEST/bin\" \"$DEST/lib\" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do is_elf \"$candidate\" && printf '%s\\n' \"$candidate\"; done)\n  [ \"$added\" -eq 1 ] || break\ndone\n\nwhile IFS= read -r elf_file; do\n  case \"$elf_file\" in\n    \"$DEST/bin/\"*) runtime_path='$ORIGIN/../lib' ;;\n    \"$DEST/lib/postgresql/\"*) runtime_path='$ORIGIN/..:$ORIGIN' ;;\n    \"$DEST/lib/\"*) runtime_path='$ORIGIN' ;;\n    *) echo \"unsupported Linux ELF location: $elf_file\" >&2; exit 1 ;;\n  esac\n  patchelf --set-rpath \"$runtime_path\" \"$elf_file\"\n  readelf -h \"$elf_file\" | grep -q 'Machine:.*X86-64' || {\n    echo \"non-X86-64 ELF in runtime: $elf_file\" >&2\n    exit 1\n  }\ndone < <(find \"$DEST/bin\" \"$DEST/lib\" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do is_elf \"$candidate\" && printf '%s\\n' \"$candidate\"; done)\n\n{\n  printf 'postgresql\\t%s\\n' \"$version\"\n  LC_ALL=C sort -u \"$component_file\"\n} > \"$DEST/THIRD_PARTY_COMPONENTS.txt\"\n\n\"$DEST/bin/postgres\" --version | grep -F 'PostgreSQL) 17.11' >/dev/null\n(\n  cd \"$DEST\"\n  find . -type f ! -name MANIFEST.sha256 -print | LC_ALL=C sort |\n    while IFS= read -r file_path; do sha256sum \"$file_path\"; done > MANIFEST.sha256\n)\necho \"packaged PostgreSQL Linux AMD64 runtime: $DEST\"\n",
    "shell": "bash"
  },
  "materialize": {
    "source": "#!/bin/bash\nset -euo pipefail\n\nROOT=\"${GITHUB_WORKSPACE:?缺少本仓检出根}\"\nMODULE_DIR=\"$ROOT/modules\"\nSOURCE=\"${1:?usage: release-host-linux action materialize SOURCE DESTINATION}\"\nDESTINATION=\"${2:?usage: release-host-linux action materialize SOURCE DESTINATION}\"\n\nrequire_file() { test -f \"$1\" || { echo \"missing runtime file: $1\" >&2; exit 1; }; }\nrequire_dir() { test -d \"$1\" || { echo \"missing runtime directory: $1\" >&2; exit 1; }; }\nrequire_executable() { test -x \"$1\" || { echo \"missing runtime executable: $1\" >&2; exit 1; }; }\n\nrequire_executable \"$SOURCE/python/bin/python3\"\n\"$SOURCE/python/bin/python3\" --version 2>&1 | grep -q '^Python 3\\.14\\.'\nrequire_executable \"$SOURCE/node/bin/node\"\n# 组装再次读取TuyuBooking产品锁中的Node版本。\nNODE_VERSION=\"$(node --input-type=module - \"$MODULE_DIR/runtime.lock.json\" <<'NODE_TOOL'\nimport { readFileSync } from 'node:fs';\nconst lock = JSON.parse(readFileSync(process.argv[2], 'utf8'));\nif (!lock.tools?.node?.version) throw new Error('TuyuBooking产品锁缺少Node版本');\nprocess.stdout.write(lock.tools.node.version);\nNODE_TOOL\n)\"\ntest \"$(\"$SOURCE/node/bin/node\" --version)\" = \"v$NODE_VERSION\"\nrequire_executable \"$SOURCE/php/bin/php\"\n\"$SOURCE/php/bin/php\" --version | grep -q '^PHP 8\\.4\\.'\nrequire_executable \"$SOURCE/php/sbin/php-fpm\"\nrequire_executable \"$SOURCE/nginx/sbin/nginx\"\nrequire_executable \"$SOURCE/openssl/bin/openssl\"\n\nfor app in frappe erpnext hrms kamra ury; do require_dir \"$SOURCE/bench/apps/$app\"; done\nrequire_file \"$SOURCE/bench/sites/assets/assets.json\"\nrequire_file \"$SOURCE/voyant/operator/.output/server/index.mjs\"\nrequire_file \"$SOURCE/voyant/operator/.output/migration/migrate.mjs\"\nrequire_file \"$SOURCE/voyant/operator/migrations/0000_baseline.sql\"\nrequire_file \"$SOURCE/hi_events/backend/vendor/autoload.php\"\nrequire_file \"$SOURCE/hi_events/frontend/server.js\"\nrequire_file \"$SOURCE/hi_events/frontend/dist/client/index.html\"\nrequire_file \"$SOURCE/hi_events/frontend/dist/server/entry.server.js\"\nrequire_dir \"$SOURCE/hi_events/frontend/node_modules\"\nrequire_file \"$SOURCE/sbom.spdx.json\"\nrequire_file \"$SOURCE/bundle.manifest.json\"\n\nif test -n \"$(find \"$SOURCE/bench/apps\" -name .git -print -quit)\"; then\n  echo \"business runtime still contains version-control metadata; complete the owning Workflow asset stage\" >&2\n  exit 1\nfi\nif test -n \"$(find \"$SOURCE/bench/apps\" -type d -name node_modules -print -quit)\"; then\n  echo \"business runtime still contains Frappe build dependencies; complete the owning Workflow asset stage\" >&2\n  exit 1\nfi\n\nif [ -e \"$DESTINATION\" ]; then find \"$DESTINATION\" -depth -delete; fi\nmkdir -p \"$DESTINATION\"\n\ncopy_tree() {\n  local source=\"$1\" destination=\"$2\"\n  mkdir -p \"$destination\"\n  # Runtime trees contain generated assets and many relative symlinks. rsync's\n  # archive contract copies the complete directory contents deterministically;\n  # ditto can omit entries when merging these large generated trees.\n  rsync -a --delete \"$source/\" \"$destination/\"\n}\n\nfor directory in python node php nginx openssl bench voyant hi_events licenses; do\n  copy_tree \"$SOURCE/$directory\" \"$DESTINATION/$directory\"\ndone\n# Homebrew exposes its global PECL directory through an absolute symlink. The\n# product runtime may use only extensions explicitly embedded in this bundle.\nif [ -L \"$DESTINATION/php/pecl\" ]; then\n  rm \"$DESTINATION/php/pecl\"\n  mkdir -p \"$DESTINATION/php/pecl\"\nfi\ncp \"$SOURCE/sbom.spdx.json\" \"$DESTINATION/sbom.spdx.json\"\ncp \"$SOURCE/bundle.manifest.json\" \"$DESTINATION/bundle.manifest.json\"\n\nfor script in tuyu_runtime_common.py tuyu_https_proxy.py tuyu_frappe_runtime.py tuyu_frappe_worker.py tuyu_frappe_wsgi.py tuyu_voyant_runtime.py tuyu_voyant_https.mjs tuyu_hi_events_runtime.py; do\n  require_file \"$MODULE_DIR/$script\"\n  cp \"$MODULE_DIR/$script\" \"$DESTINATION/$script\"\n  chmod 0755 \"$DESTINATION/$script\"\ndone\ncp \"$MODULE_DIR/runtime.lock.json\" \"$DESTINATION/runtime.lock.json\"\nrequire_file \"$DESTINATION/bench/sites/assets/assets.json\"\n\nwhile IFS= read -r link; do\n  case \"$(readlink \"$link\")\" in\n    /*) echo \"business runtime contains an absolute symlink: $link\" >&2; exit 1 ;;\n  esac\ndone < <(find \"$DESTINATION\" -type l -print)\n\nif [ \"$(uname -s)\" = Darwin ]; then\n  echo \"Linux自动化不执行macOS运行件重定位\" >&2; exit 1\nfi\n\necho \"materialized TuyuBooking business runtime: $DESTINATION\"\n",
    "shell": "bash"
  },
  "verify-bundle": {
    "source": "#!/usr/bin/env bash\nset -euo pipefail\n\nif [ \"$#\" -ne 1 ]; then\n  echo \"usage: Workflow verify-bundle <debian-staging-root>\" >&2\n  exit 2\nfi\nif [ \"$(uname -s)\" != Linux ]; then\n  echo \"Linux bundle verification requires a Linux host\" >&2\n  exit 1\nfi\ncase \"$(uname -m)\" in\n  x86_64|amd64) ;;\n  *) echo \"Linux bundle verification requires an AMD64 host\" >&2; exit 1 ;;\nesac\n\nstage=\"$(cd \"$1\" && pwd)\"\napp=\"$stage/opt/tuyubooking\"\nruntime=\"$app/postgresql\"\nnative=\"$app/lib/libtuyubooking_native.so\"\nbusiness=\"$app/business\"\n\nfor required in \\\n  \"$app/tuyubooking\" \\\n  \"$native\" \\\n  \"$runtime/bin/postgres\" \\\n  \"$runtime/bin/initdb\" \\\n  \"$runtime/bin/pg_ctl\" \\\n  \"$runtime/MANIFEST.sha256\" \\\n  \"$business/python/bin/python3\" \\\n  \"$business/node/bin/node\" \\\n  \"$business/php/bin/php\" \\\n  \"$business/php/sbin/php-fpm\" \\\n  \"$business/nginx/sbin/nginx\" \\\n  \"$business/voyant/operator/.output/server/index.mjs\" \\\n  \"$business/voyant/operator/.output/migration/migrate.mjs\" \\\n  \"$business/voyant/operator/.output/migrations/meta/_journal.json\" \\\n  \"$business/tuyu_frappe_runtime.py\" \\\n  \"$business/tuyu_runtime_common.py\" \\\n  \"$business/tuyu_voyant_runtime.py\" \\\n  \"$business/tuyu_hi_events_runtime.py\" \\\n  \"$business/tuyu_https_proxy.py\" \\\n  \"$business/hi_events/backend/vendor/autoload.php\" \\\n  \"$business/hi_events/frontend/dist/server/entry.server.js\" \\\n  \"$business/runtime.lock.json\" \\\n  \"$business/bench/apps/frappe/LICENSE\" \\\n  \"$business/bench/apps/erpnext/license.txt\" \\\n  \"$business/bench/apps/hrms/license.txt\" \\\n  \"$business/bench/apps/kamra/license.txt\" \\\n  \"$business/bench/apps/ury/license.txt\" \\\n  \"$stage/DEBIAN/control\" \\\n  \"$stage/usr/share/applications/com.tuyulove.tuyubooking.desktop\"; do\n  test -e \"$required\" || { echo \"missing Linux bundle file: $required\" >&2; exit 1; }\ndone\n\n\"$business/python/bin/python3\" --version 2>&1 | grep -q '^Python 3\\.14\\.'\n\"$business/node/bin/node\" --version 2>&1 | grep -q '^v24\\.'\n\"$business/php/bin/php\" --version 2>&1 | grep -q '^PHP 8\\.4\\.'\ngrep -q '\"network_install_allowed\": false' \"$business/runtime.lock.json\"\ngrep -q '\"database_name\": \"tuyubooking\"' \"$business/runtime.lock.json\"\n\nwhile IFS= read -r elf_file; do\n  readelf -h \"$elf_file\" | grep -q 'Machine:.*X86-64' || {\n    echo \"non-X86-64 ELF in package: $elf_file\" >&2\n    exit 1\n  }\n  ldd \"$elf_file\" | grep -q 'not found' && {\n    echo \"unresolved Linux dependency: $elf_file\" >&2\n    exit 1\n  }\n  patchelf --print-rpath \"$elf_file\" | grep -qE '^\\$ORIGIN' || {\n    echo \"non-relative Linux RPATH: $elf_file\" >&2\n    exit 1\n  }\ndone < <(find \"$app\" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do readelf -h \"$candidate\" >/dev/null 2>&1 && printf '%s\\n' \"$candidate\"; done)\n\nnm -D \"$native\" | grep -q ' tuyubooking_contract$'\nnm -D \"$native\" | grep -q ' tuyubooking_start$'\n\"$runtime/bin/postgres\" --version | grep -F 'PostgreSQL) 17.11' >/dev/null\n(\n  cd \"$runtime\"\n  sha256sum --check --status MANIFEST.sha256\n)\ngrep -q '^Architecture: amd64$' \"$stage/DEBIAN/control\"\ngrep -q '^Exec=/opt/tuyubooking/tuyubooking$' \"$stage/usr/share/applications/com.tuyulove.tuyubooking.desktop\"\necho \"verified TuyuBooking Linux AMD64 staging bundle: $stage\"\n",
    "shell": "bash"
  },
  "sourcecheck": {
    "source": "#!/usr/bin/env node\nimport {existsSync,readFileSync,lstatSync} from 'node:fs';\nimport {join} from 'node:path';\nconst root=process.env.GITHUB_WORKSPACE,platform='linux-amd';\nif(!root)throw Error('缺少本仓检出根');\nfor(const name of ['app/linux/CMakeLists.txt','app/linux/runner/my_application.cc',\n `host/database/postgresql-${platform}.lock.json`,`host/database/control-${platform}.template`,\n 'host/tuyubooking.desktop']){const file=join(root,name);if(!existsSync(file)||!lstatSync(file).isFile())throw Error('Linux自动化来源缺失：'+name);}\nconst lock=JSON.parse(readFileSync(join(root,`host/database/postgresql-${platform}.lock.json`),'utf8'));\nif(lock.architecture!==platform||lock.version!=='17.11'||!lock.source_url?.startsWith('https://')||!/^[a-f0-9]{64}$/u.test(lock.source_sha256||''))throw Error('Linux自动化来源锁无效');\nconst control=readFileSync(join(root,`host/database/control-${platform}.template`),'utf8');\nif(!control.includes('Architecture: amd64'))throw Error('Linux自动化包架构错误');\nif(!readFileSync(join(root,'app/linux/CMakeLists.txt'),'utf8').includes('$ORIGIN/lib'))throw Error('Linux自动化原生加载路径错误');\n",
    "shell": "node"
  }
});
const shaPattern = /^[0-9a-f]{40}$/u;
const fail = message => { throw new Error(message); };
const root = fileURLToPath(new URL('../../', import.meta.url));
const workflowPath = `.github/workflows/release-${owner.platform}.yml`;
const prefix = `${owner.product}-${owner.platform}-v`;

export function context(environment = process.env) {
  const number = name => {
    const value = environment[name];
    if (!/^[1-9][0-9]*$/u.test(value || '') || !Number.isSafeInteger(Number(value))) fail('GitHub运行坐标无效');
    return Number(value);
  };
  if (environment.GITHUB_ACTIONS !== 'true' || environment.GITHUB_REPOSITORY !== owner.repository
    || environment.GITHUB_REF !== 'refs/heads/main' || environment.GITHUB_EVENT_NAME !== 'workflow_dispatch'
    || !shaPattern.test(environment.GITHUB_SHA || '')
    || environment.GITHUB_WORKFLOW_REF !== `${owner.repository}/${workflowPath}@refs/heads/main`) fail('所属GitHub运行身份无效');
  return { repository: owner.repository, product_id: owner.product, platform: owner.platform,
    source_sha: environment.GITHUB_SHA, run_id: number('GITHUB_RUN_ID'),
    run_number: number('GITHUB_RUN_NUMBER'), run_attempt: number('GITHUB_RUN_ATTEMPT'), workflow: workflowPath };
}

export async function request(path, { method = 'GET', body, raw = false, size, fetch: send = globalThis.fetch } = {}) {
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  if (!token || /[\s\u0000-\u001f\u007f]/u.test(token)) fail('缺少GitHub任务令牌');
  const url = path.startsWith('https://') ? new URL(path) : new URL(`https://api.github.com/repos/${owner.repository}/${path}`);
  if (!['api.github.com', 'uploads.github.com'].includes(url.hostname) || url.protocol !== 'https:' || url.username || url.password || !url.pathname.startsWith(`/repos/${owner.repository}/`)) fail('GitHub接口地址无效');
  const headers = { Authorization: `Bearer ${token}`, Accept: raw ? 'application/octet-stream' : 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2026-03-10', 'User-Agent': owner.product };
  if (body !== undefined) headers['Content-Type'] = body?.pipe ? 'application/octet-stream' : 'application/json';
  if(body?.pipe){if(!Number.isSafeInteger(size)||size<=0)fail('资产上传长度无效');headers['Content-Length']=String(size);}
  let response = await send(url, { method, headers, redirect: raw ? 'manual' : 'error', signal: AbortSignal.timeout(300_000),
    ...(body === undefined ? {} : { body: body?.pipe ? body : JSON.stringify(body), ...(body?.pipe ? { duplex: 'half' } : {}) }) });
  if(raw&&response.status===302){
    const location=new URL(response.headers.get('location'));
    if(location.protocol!=='https:'||location.username||location.password)fail('正式资产回读地址无效');
    response=await send(location,{method:'GET',redirect:'error',credentials:'omit',signal:AbortSignal.timeout(300_000)});
  }
  if (response.status === 404) return null;
  if (!response.ok) fail(`GitHub接口失败：${response.status}，操作未确认`);
  if (raw) return response;
  return response.status === 204 ? {} : response.json();
}

export async function pages(path, field = null, api = request) {
  const rows = [];
  for (let page = 1; ; page++) {
    const data = await api(`${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
    const values = field ? data?.[field] : data;
    if (!Array.isArray(values)) fail('GitHub分页数据无效');
    rows.push(...values);
    if (values.length < 100) return rows;
  }
}

function seedVersion() {
  const source = owner.version_source;
  if (source.kind === 'sequence') return '0.0.0';
  const text = readFileSync(join(root, source.path), 'utf8');
  if (source.kind === 'json') return String(JSON.parse(text).version);
  if (source.kind === 'spec') {
    const matches = [...text.matchAll(/^\s*spec_version:\s*(\d+)\s*,\s*$/gm)];
    if (matches.length !== 1) fail('Runtime版本真源不唯一');
    return matches[0][1];
  }
  if (source.kind === 'cargo') {
    const value = /^\[package\][\s\S]*?^version\s*=\s*"(\d+\.\d+\.\d+)"/mu.exec(text)?.[1];
    if (!value) fail('本仓Cargo版本真源无效');
    return value;
  }
  const value = /^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$/mu.exec(text)?.[1];
  if (!value) fail('本仓软件版本真源无效');
  return value;
}

export function nextVersion(seed, versions, protocol = false, runNumber = 1) {
  if (protocol) {
    if (!/^\d+$/u.test(seed) || versions.some(value => !/^\d+$/u.test(value))) fail('协议版本无效');
    const value = Math.max(Number(seed), ...versions.map(Number)) + (versions.length ? 1 : 0);
    if (!Number.isSafeInteger(value) || value < 1 || value > 0xffffffff) fail('协议版本越界');
    return String(value);
  }
  const parse = value => {
    const match = /^(0|[1-9]\d*)\.(0|[1-9]\d?)\.(0|[1-9]\d?)$/u.exec(value);
    if (!match) fail('软件版本无效');
    const parts=match.slice(1).map(Number);if(parts.some(value=>!Number.isSafeInteger(value)))fail('软件版本越界');return parts;
  };
  const values = [seed, ...versions].map(parse).sort((a,b) => a[0]-b[0] || a[1]-b[1] || a[2]-b[2]);
  let [major, minor, patch] = values.at(-1);
  if (versions.length) { if (++patch > 99) { patch = 0; if (++minor > 99) { minor = 0; major++; } } }
  if(!Number.isSafeInteger(runNumber)||runNumber<1)fail('版本运行序号无效');
  const initial=parse(seed),floor=BigInt(initial[0])*10000n+BigInt(initial[1])*100n+BigInt(initial[2])+BigInt(runNumber-1);
  const historical=BigInt(major)*10000n+BigInt(minor)*100n+BigInt(patch);
  if(floor>historical){major=Number(floor/10000n);minor=Number(floor/100n%100n);patch=Number(floor%100n);}
  if(![major,minor,patch].every(Number.isSafeInteger))fail('软件版本越界');
  return `${major}.${minor}.${patch}`;
}

function output(name, value, file = process.env.GITHUB_OUTPUT) {
  if (!file || /[\r\n]/u.test(String(value))) fail('GitHub步骤输出无效');
  appendFileSync(file, `${name}=${value}\n`);
}

export async function prepare() {
  const identity = context();
  const releases = await pages('releases');
  const versions = [];
  for (const release of releases) {
    if (release.draft || release.prerelease || !String(release.tag_name).startsWith(prefix)) continue;
    const notes = (await bookingRelease(release,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))));
    if (!notes || notes.platform !== owner.platform) continue;
    const run = await request(`actions/runs/${notes.run_id}`);
    if (run?.status === 'completed' && run.conclusion === 'success' && run.path === workflowPath) versions.push(notes.version);
  }
  const version = nextVersion(seedVersion(), versions, owner.version_source.kind === 'spec', identity.run_number);
  const tag = `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`;
  for (const [name,value] of Object.entries({version, tag, source_sha:identity.source_sha,
    run_id:identity.run_id, run_attempt:identity.run_attempt, run_number:identity.run_number})) output(name,value);
}

function runVersion() {
  const identity = context();
  const version = process.env.RELEASE_VERSION;
  const tag = process.env.RELEASE_TAG;
  nextVersion(version, [], owner.version_source.kind === 'spec');
  if (tag !== `${prefix}${version}-r${identity.run_id}-a${identity.run_attempt}`) fail('本次版本与Tag不一致');
  return {...identity, version, tag};
}

export function job() {
  const identity = runVersion();
  if (execFileSync('git', ['rev-parse','HEAD'], {cwd:root,encoding:'utf8'}).trim() !== identity.source_sha) fail('检出源码不符');
  const work = join(process.env.RUNNER_TEMP, owner.product, owner.platform, String(identity.run_id), String(identity.run_attempt), process.env.GITHUB_JOB);
  mkdirSync(work,{recursive:true});
  const variables = {RELEASE_WORK:work, RELEASE_ASSETS_DIR:join(work,'assets'), SOURCE_SHA:identity.source_sha,
    SOFTWARE_VERSION:identity.version, VERSION_TAG:identity.tag, BUILD_NUMBER:String(identity.run_number),
    CARGO_HOME:join(work,'cargo-home'), CARGO_TARGET_DIR:join(work,'cargo'), PUB_CACHE:join(work,'pub'),
    GRADLE_USER_HOME:join(work,'gradle'), npm_config_cache:join(work,'npm'), XDG_CACHE_HOME:join(work,'cache'),
    TMPDIR:join(work,'tmp'), TMP:join(work,'tmp'), TEMP:join(work,'tmp')};
  for (const path of ['cargo-home','cargo','pub','gradle','npm','cache','tmp','assets']) mkdirSync(join(work,path),{recursive:true});
  for (const [name,value] of Object.entries(variables)) { process.env[name]=value; output(name,value,process.env.GITHUB_ENV); }
}

export function step(key) {
  runVersion();
  const value = commands[key];
  if (!value || !['bash','pwsh'].includes(value.shell)) fail('本目标构建步骤无效');
  const directory = join(process.env.RELEASE_WORK,'commands');mkdirSync(directory,{recursive:true});
  const file = join(directory, value.shell === 'pwsh' ? 'step.ps1' : 'step.sh');
  writeFileSync(file, value.shell === 'bash' ? 'set -euo pipefail\n'+value.source : "$ErrorActionPreference = 'Stop'\n"+value.source,{mode:0o700});
  const result = spawnSync(value.shell === 'pwsh' ? 'pwsh' : 'bash', value.shell === 'pwsh' ? ['-NoProfile','-File',file] : [file],
    {cwd:process.cwd(),env:process.env,stdio:'inherit'});
  rmSync(file,{force:true});
  if (result.error || result.status !== 0) fail(`本仓构建步骤失败：${key}`);
}

export function action(name, args) {
  runVersion();
  const value = actions[name];if (!value) fail('本目标动作无效');
  const directory = join(process.env.RELEASE_WORK,'commands');mkdirSync(directory,{recursive:true});
  const file = join(directory,`action-${name}-${process.pid}.${value.shell==='bash'?'sh':'mjs'}`);
  const source=value.source.replace(/__PRODUCT_URL__([^'"\s]+)__END_URL__/gu,(_,path)=>pathToFileURL(join(root,path)).href);
  writeFileSync(file,source,{mode:0o700,flag:'wx'});
  let result;
  try{result=spawnSync(value.shell==='bash'?'bash':process.execPath,[file,...args],{cwd:root,env:process.env,stdio:'inherit'});}
  finally{rmSync(file,{force:true});}
  if(result.error||result.status!==0)fail(`本仓动作失败：${name}`);
}

function regular(path) {
  const stat=lstatSync(path);if(!stat.isFile()||stat.isSymbolicLink()||stat.size<=0)fail('正式产物不是非空普通文件');return stat;
}
async function digestFile(path) { const hash=createHash('sha256');for await(const bytes of createReadStream(path))hash.update(bytes);return hash.digest('hex'); }
function assetName(name) { if(!name||name!==basename(name)||/[\u0000-\u001f\u007f]/u.test(name))fail('正式资产文件名无效');return name; }

export async function collect(paths) {
  const identity=runVersion(),destination=process.env.RELEASE_ASSETS_DIR;
  if(!destination||!paths.length)fail('本仓没有完整产物');mkdirSync(destination,{recursive:true});
  const files=[];
  for(const path of paths){const file=resolve(path),stat=regular(file),name=assetName(basename(file));
    if(files.some(row=>row.name===name))fail('正式资产重名');
    const target=join(destination,name);if(file!==target)copyFileSync(file,target);
    files.push({name,size:stat.size,sha256:await digestFile(target)});
  }
  if(owner.required_assets.some(name=>!files.some(row=>row.name===name)))fail('本目标必要产物缺失');
  const metadata={schema:1,...identity,assets:files};
  writeFileSync(join(destination,'automation.json'),JSON.stringify(metadata,null,2)+'\n');
  output('assets',destination);return metadata;
}

export async function collectProduced() {
  const paths=[],seen=new Set();
  const expand=value=>value.replace(/\$\{([A-Z_]+)\}|\$([A-Z_]+)/gu,(_,a,b)=>process.env[a||b]||'');
  for(const location of owner.asset_locations){
    const path=expand(location);if(!path||!existsSync(path))continue;
    const candidates=lstatSync(path).isDirectory()?readdirSync(path).map(name=>join(path,name)):[path];
    for(const candidate of candidates){if(!lstatSync(candidate).isFile()||seen.has(resolve(candidate)))continue;
      const name=basename(candidate);if(!owner.asset_patterns.some(pattern=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(name)))continue;
      seen.add(resolve(candidate));paths.push(candidate);
    }
  }
  if(owner.required_patterns.some(pattern=>!paths.some(path=>new RegExp('^'+pattern.replace(/[.+?^${}()|[\]\\]/gu,'\\$&').replaceAll('*','.*')+'$','u').test(basename(path)))))fail('本目标完整正式资产缺失');
  return collect(paths);
}



export async function publish(directory) {
  const identity=runVersion();const metadata=JSON.parse(readFileSync(join(directory,'automation.json'),'utf8'));
  if(Object.entries(identity).some(([key,value])=>metadata[key]!==value)||!Array.isArray(metadata.assets)||!metadata.assets.length)fail('完整产物身份无效');
  const files=metadata.assets;
  if(readdirSync(directory).sort().join('\0')!==[...files.map(value=>value.name),'automation.json'].sort().join('\0'))fail('产物目录与完整资产集合不符');
  for(const file of files){const path=join(directory,assetName(file.name));if(regular(path).size!==file.size||await digestFile(path)!==file.sha256)fail('正式产物在交付前改变');}
  if(await request(`git/ref/tags/${encodeURIComponent(identity.tag)}`)!==null)fail('本次Tag已经存在');
  await request('git/refs',{method:'POST',body:{ref:`refs/tags/${identity.tag}`,sha:identity.source_sha}});
  const release=await request('releases',{method:'POST',body:{tag_name:identity.tag,target_commitish:identity.source_sha,
    name:`${owner.product} · ${owner.platform} · ${identity.version}`,draft:false,prerelease:false,make_latest:'false',
    body:`${owner.product} · ${owner.platform} · ${identity.version}\nSource: ${identity.source_sha}\nRun: ${identity.run_id} / ${identity.run_attempt}`}});
  if(!Number.isSafeInteger(release?.id)||!release.upload_url)fail('正式Release创建未确认');
  for(const file of files){const url=new URL(release.upload_url.replace(/\{.*$/u,''));url.searchParams.set('name',file.name);
    const asset=await request(url.href,{method:'POST',body:createReadStream(join(directory,file.name)),size:file.size});
    if(asset?.name!==file.name||asset.size!==file.size||asset.state!=='uploaded')fail('正式资产上传未确认');
    const response=await request(asset.url,{raw:true});if(!response?.body)fail('正式资产回读失败');
    const hash=createHash('sha256');let size=0;for await(const bytes of response.body){hash.update(bytes);size+=bytes.length;if(size>file.size)fail('正式资产回读超过声明大小');}
    if(size!==file.size||hash.digest('hex')!==file.sha256)fail('GitHub资产逐件回读不一致');
  }
  const readback=await request(`releases/${release.id}`);if((await bookingRelease(readback,owner.platform,tag=>request('git/ref/tags/'+encodeURIComponent(tag))))?.run_id!==identity.run_id||readback.draft||readback.prerelease
    ||readback.assets?.length!==files.length)fail('完整正式Release回查失败');
  for(const file of files){const asset=readback.assets.find(value=>value.name===file.name);if(!asset||asset.state!=='uploaded'||asset.size!==file.size||asset.digest!==`sha256:${file.sha256}`)fail('完整正式资产证明回查失败');}
  output('verified','true');output('release_id',release.id);output('tag',identity.tag);
}

function ownedRun(run) {
  // 每个目标只处理自身现行Workflow；文件缺失不能证明历史任务归属。
  return Number.isSafeInteger(run?.id)&&run.id>0&&run.path===workflowPath
    &&run.head_branch==='main'&&run.event==='workflow_dispatch'
    &&(!run.repository||run.repository.full_name===owner.repository);
}

export function cleanupPlan(runs,current,result) {
  if(!['success','failed'].includes(result)||!ownedRun(current)||!Number.isFinite(Date.parse(current.created_at)))fail('清理所属任务身份无效');
  const earlier=run=>Date.parse(run.created_at)<Date.parse(current.created_at)
    ||Date.parse(run.created_at)===Date.parse(current.created_at)&&run.id<current.id;
  return runs.filter(run=>ownedRun(run)&&run.id!==current.id&&run.status==='completed'&&earlier(run)
    &&(run.conclusion==='success'?'success':'failed')===result).sort((a,b)=>a.id-b.id);
}

async function remove(path,api) { await api(path,{method:'DELETE'});const readPath=path.replace(/^git\/refs\//u,'git/ref/');if(await api(readPath)!==null)fail('删除回查仍存在，清理失败'); }
async function removeRunRelease(run,releases,api) {
  for(const release of releases){
    const metadata=(await bookingRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(!metadata||metadata.run_id!==run.id)continue;
    if(metadata.source_sha!==run.head_sha)fail('正式Release与所属Run不一致');
    const tag=metadata.tag;
    const again=await api(`actions/runs/${run.id}`);
    if(again&&again.id!==Number(process.env.GITHUB_RUN_ID)
      &&(again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`releases/${release.id}`,api);
    const beforeTag=await api(`actions/runs/${run.id}`);
    if(beforeTag&&beforeTag.id!==Number(process.env.GITHUB_RUN_ID)
      &&(beforeTag.status!=='completed'||beforeTag.run_attempt!==run.run_attempt||beforeTag.conclusion!==run.conclusion))fail('所属任务已变化，停止清理');
    await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
  }
}
export async function cleanup(result,identity=context(),api=request) {
  const current=await api(`actions/runs/${identity.run_id}`);
  const plan=cleanupPlan(await pages('actions/runs','workflow_runs',api),current,result);
  const releases=await pages('releases',null,api),removed=[];
  for(const row of plan){const run=await api(`actions/runs/${row.id}`);if(!run){removed.push(row.id);continue;}
    if(run.run_attempt!==row.run_attempt||cleanupPlan([run],current,result).length!==1)continue;
    await removeRunRelease(run,releases,api);
    // 失败若只形成Tag也按它的准确Run坐标处理，不能留下同类孤立产物。
    const tags=await api(`git/matching-refs/tags/${prefix}`);
    if(!Array.isArray(tags))fail('所属Tag集合无效');
    for(const reference of tags){
      const tag=String(reference.ref||'').slice('refs/tags/'.length);
      if(!String(reference.ref||'').startsWith('refs/tags/'+prefix)
        ||!new RegExp(`-r${run.id}-a[1-9][0-9]*$`,'u').test(tag)||Number(tag.slice(tag.lastIndexOf('-a')+2))>run.run_attempt)continue;
      if(reference.object?.type!=='commit'||reference.object.sha!==run.head_sha)fail('所属Tag来源已改变，停止清理');
      const again=await api(`actions/runs/${run.id}`);
      if(!again||cleanupPlan([again],current,result).length!==1)fail('所属任务已改变，停止清理');
      await remove(`git/refs/tags/${encodeURIComponent(tag)}`,api);
    }
    for(const asset of await pages(`actions/runs/${run.id}/artifacts`,'artifacts',api)){
      if(!Number.isSafeInteger(asset.id)||asset.id<=0)fail('所属Artifact坐标无效');
      const again=await api(`actions/runs/${run.id}`);if(!again||again.status!=='completed'||again.run_attempt!==run.run_attempt||again.conclusion!==run.conclusion)fail('历史任务已变化，停止清理');
      await remove(`actions/artifacts/${asset.id}`,api);
    }
    const final=await api(`actions/runs/${run.id}`);
    if(final&&(final.run_attempt!==run.run_attempt||cleanupPlan([final],current,result).length!==1))fail('历史任务状态改变，停止清理');
    if(final)await remove(`actions/runs/${run.id}`,api);removed.push(run.id);
  }
  return removed;
}

export function precedingResult(needs) {
  if(!needs||typeof needs!=='object'||Array.isArray(needs)||!Object.keys(needs).length)fail('前置任务结果缺失');
  return Object.values(needs).every(value=>value?.result==='success')?'success':'failed';
}
async function discardCurrent(identity,api) {
  for(const release of await pages('releases',null,api)){
    const metadata=(await bookingRelease(release,owner.platform,tag=>api('git/ref/tags/'+encodeURIComponent(tag))));
    if(metadata?.run_id===identity.run_id&&metadata.run_attempt===identity.run_attempt)
      await removeRunRelease({id:identity.run_id,head_sha:identity.source_sha},[release],api);
  }
  const tag=process.env.RELEASE_TAG;
  if(tag&&tag.startsWith(prefix)&&tag.endsWith(`-r${identity.run_id}-a${identity.run_attempt}`)){
    const path=`git/refs/tags/${encodeURIComponent(tag)}`;
    if(await api(path.replace(/^git\/refs\//u,'git/ref/'))!==null)await remove(path,api);
  }
}
export async function finish(needs=JSON.parse(process.env.RELEASE_NEEDS||'null'),api=request,identity=context()) {
  const result=precedingResult(needs),errors=[];
  const attempt=async action=>{try{return await action();}catch(error){errors.push(error);return null;}};
  let removed;
  if(result==='success') {
    removed=await attempt(()=>cleanup('success',identity,api));
    if(errors.length) {
      await attempt(()=>discardCurrent(identity,api));
      await attempt(()=>cleanup('failed',identity,api));
    }
  } else {
    // 本次撤销失败也必须尝试清理同目标旧失败；各项真实错误均保留。
    await attempt(()=>discardCurrent(identity,api));
    removed=await attempt(()=>cleanup('failed',identity,api));
  }
  if(errors.length)throw new AggregateError(errors,'本目标最后处理失败：'+errors.map(error=>error.message).join('；'));
  if(process.env.GITHUB_STEP_SUMMARY)appendFileSync(process.env.GITHUB_STEP_SUMMARY,`本目标${result==='success'?'成功':'失败'}；已清理同类旧Run：${removed.join('、')||'无'}。\n`);
  if(result==='failed')fail('前置任务未全部成功');
}

// 本目标实际构建与组包接口。
async function productCommand() { return false; }

const direct=process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url);
const testing=direct&&Boolean(process.env.NODE_TEST_CONTEXT)&&process.argv.length===2;
if(direct&&!testing){
  try{const [command,...args]=process.argv.slice(2);
    if(command==='prepare')await prepare();else if(command==='job')job();else if(command==='step')step(args[0]);
    else if(command==='action')action(args[0],args.slice(1));else if(command==='collect')await collect(args);
    else if(command==='collect-produced')await collectProduced();else if(command==='publish')await publish(args[0]);else if(command==='finish')await finish();
    else if(!await productCommand(command,args))fail('自动化命令无效');
  }catch(error){console.error(error.message);process.exitCode=1;}
}

if(testing){
  const {default:assert}=await import('node:assert/strict');const {default:test}=await import('node:test');

  test('旧入口不能成为任一现行平台的清理归属证明',()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    const old={...current,id:1,status:'completed',conclusion:'success',created_at:'2026-01-01T00:00:00Z'};
    for(const path of ['.github/workflows/release.yml',`.github/workflows/${owner.product}-${owner.platform}-ci.yml`,'.github/workflows/deleted.yml'])
      assert.deepEqual(cleanupPlan([{...old,path}],current,'success'),[]);
  });
  test('撤销当前产物失败仍处理旧失败且最终失败',async()=>{
    const current={id:9,path:workflowPath,head_branch:'main',event:'workflow_dispatch',created_at:'2026-01-02T00:00:00Z'};
    let releases=0,history=0;
    const api=async path=>{
      if(path.startsWith('releases?')){if(++releases===1)throw Error('撤销中断');return [];}
      if(path==='actions/runs/9')return current;
      if(path.startsWith('actions/runs?')){history++;return {workflow_runs:[]};}
      throw Error('未声明请求');
    };
    await assert.rejects(finish({build:{result:'failure'}},api,{run_id:9}),/撤销中断/);
    assert.equal(history,1);assert.equal(releases,2);
  });
  test('清理旧失败Run同时回收其多个Attempt的准确孤立Tag',async()=>{
    const old={id:2,run_attempt:2,path:workflowPath,head_branch:'main',event:'workflow_dispatch',head_sha:'a'.repeat(40),status:'completed',conclusion:'failure',created_at:'2026-01-01T00:00:00Z'},current={...old,id:9,status:'in_progress',created_at:'2026-01-02T00:00:00Z'};
    const deleted=new Set(),tags=[1,2].map(attempt=>({ref:`refs/tags/${prefix}1.0.0-r2-a${attempt}`,object:{type:'commit',sha:old.head_sha}}));
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){deleted.add(path);return {};}
      if(deleted.has(path)||deleted.has(path.replace('git/ref/','git/refs/')))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:[old,current]};
      if(path.startsWith('releases?')||path.includes('/artifacts?'))return path.includes('/artifacts?')?{artifacts:[]}:[];
      if(path.startsWith('git/matching-refs/'))return tags;
      if(path==='actions/runs/2')return old;if(path==='actions/runs/9')return current;
      throw Error('未声明的请求');
    };
    assert.deepEqual(await cleanup('failed',{run_id:9},api),[2]);assert.equal([...deleted].filter(path=>path.startsWith('git/refs/')).length,2);
  });
  test('全部前置成功才成功，其余结论一律失败',()=>{
    assert.equal(precedingResult({build:{result:'success'},publish:{result:'success'}}),'success');
    for(const result of ['failure','cancelled','skipped','timed_out',undefined])assert.equal(precedingResult({build:{result}}),'failed');
    assert.throws(()=>precedingResult({}));
  });
  test('当前Run尚在运行也能清理同目标旧结果，保护其它目标和活动任务',()=>{
    const row=(id,conclusion='success',status='completed',path=workflowPath)=>({id,conclusion,status,path,head_branch:'main',event:'workflow_dispatch',created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(6,null,'in_progress');const rows=[row(1),row(2,'failure'),row(3,'success','in_progress'),row(4,'success','completed','.github/workflows/release-other.yml'),current,row(7)];
    assert.deepEqual(cleanupPlan(rows,current,'success').map(row=>row.id),[1]);
    assert.deepEqual(cleanupPlan(rows,current,'failed').map(row=>row.id),[2]);
  });
  test('软件版本进位与协议版本边界',()=>{
    assert.equal(nextVersion('1.0.0',['1.99.99']),'2.0.0');assert.equal(nextVersion('9',['9'],true),'10');
    assert.throws(()=>nextVersion(String(0xffffffff),[String(0xffffffff)],true));
  });
  test('历史完整分页不截断超过1000条记录',async()=>{
    const rows=Array.from({length:1005},(_,id)=>({id}));const api=async path=>rows.slice((Number(/page=(\d+)$/u.exec(path)[1])-1)*100,Number(/page=(\d+)$/u.exec(path)[1])*100);
    assert.equal((await pages('releases',null,api)).length,1005);
  });
  test('失败清理只删除所属旧失败产物及Run，成功和活动任务独立保留',async()=>{
    const row=(id,conclusion,status='completed')=>({id,run_attempt:1,conclusion,status,path:workflowPath,head_branch:'main',event:'workflow_dispatch',repository:{full_name:owner.repository},head_sha:'a'.repeat(40),created_at:new Date(1700000000000+id*1000).toISOString()});
    const current=row(10,null,'in_progress'),rows=[row(1,'success'),row(2,'failure'),row(3,null,'in_progress'),current];
    const gone=new Set(),removed=[];
    const api=async(path,options={})=>{
      if(options.method==='DELETE'){removed.push(path);gone.add(path);return {};}
      if(gone.has(path))return null;
      if(path.startsWith('actions/runs?'))return {workflow_runs:rows};
      if(path.startsWith('releases?')||path.startsWith('git/matching-refs/'))return [];
      if(path.startsWith('actions/runs/2/artifacts?'))return {artifacts:[{id:20}]};
      if(path==='actions/artifacts/20')return {id:20};
      const match=/^actions\/runs\/(\d+)$/u.exec(path);if(match)return rows.find(row=>row.id===Number(match[1]))??null;
      throw Error('未声明的模拟接口：'+path);
    };
    assert.deepEqual(await cleanup('failed',{run_id:10},api),[2]);
    assert.deepEqual(removed,['actions/artifacts/20','actions/runs/2']);
  });

  test('GitHub运行序号保证成功历史清理后版本不会回到初始值',()=>{
    assert.equal(nextVersion('1.0.0',[],false,4),'1.0.3');
    assert.equal(nextVersion('1.99.99',[],false,2),'2.0.0');
    assert.equal(nextVersion('1.0.0',['3.0.0'],false,4),'3.0.1');
    assert.throws(()=>nextVersion('1.0.0',[],false,0));
  });

}
