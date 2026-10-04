#!/bin/bash
set -Eeuo pipefail

report_verification_failure() {
  local exit_code="$?" line_number="$1" command="$2"
  printf 'macOS bundle verification failed at line %s: %s (exit %s)\n' \
    "$line_number" "$command" "$exit_code" >&2
  exit "$exit_code"
}
trap 'report_verification_failure "$LINENO" "$BASH_COMMAND"' ERR

APP="${1:?usage: verify_bundle.sh /path/to/tuyubooking.app}"
CONTENTS="$APP/Contents"
RUNTIME="$CONTENTS/Resources/postgresql"
NATIVE="$CONTENTS/Frameworks/libtuyubooking_native.dylib"
BUSINESS="$CONTENTS/Resources/business"

test -d "$APP"
test -f "$NATIVE"
for executable in postgres initdb pg_ctl psql; do
  test -x "$RUNTIME/bin/$executable"
done
test -f "$RUNTIME/MANIFEST.sha256"
test -f "$RUNTIME/licenses/PostgreSQL-COPYRIGHT"
test -x "$BUSINESS/python/bin/python3"
test -x "$BUSINESS/node/bin/node"
test -x "$BUSINESS/php/bin/php"
test -x "$BUSINESS/php/sbin/php-fpm"
test -x "$BUSINESS/nginx/sbin/nginx"
test -f "$BUSINESS/voyant/operator/.output/server/index.mjs"
test -f "$BUSINESS/voyant/operator/.output/migration/migrate.mjs"
test -f "$BUSINESS/voyant/operator/migrations/0000_baseline.sql"
test -f "$BUSINESS/tuyu_frappe_runtime.py"
test -f "$BUSINESS/tuyu_frappe_worker.py"
test -f "$BUSINESS/tuyu_runtime_common.py"
test -f "$BUSINESS/tuyu_voyant_runtime.py"
test -f "$BUSINESS/tuyu_hi_events_runtime.py"
test -f "$BUSINESS/tuyu_https_proxy.py"
test -f "$BUSINESS/hi_events/backend/vendor/autoload.php"
test -f "$BUSINESS/hi_events/frontend/server.js"
test -f "$BUSINESS/hi_events/frontend/dist/server/entry.server.js"
test -f "$BUSINESS/runtime.lock.json"
test -f "$BUSINESS/sbom.spdx.json"
test -f "$BUSINESS/bundle.manifest.json"
test -d "$BUSINESS/licenses"
test -f "$BUSINESS/bench/apps/frappe/LICENSE"
test -f "$BUSINESS/bench/apps/erpnext/license.txt"
test -f "$BUSINESS/bench/apps/hrms/license.txt"
test -f "$BUSINESS/bench/apps/kamra/license.txt"
test -f "$BUSINESS/bench/apps/ury/LICENSE"
test -f "$BUSINESS/MANIFEST.sha256"

is_macho() {
  file -b "$1" | grep -q 'Mach-O'
}

while IFS= read -r link; do
  case "$(readlink "$link")" in
    /*) echo "release bundle contains an absolute symlink: $link" >&2; exit 1 ;;
  esac
done < <(find "$APP" -type l -print)

while IFS= read -r file_path; do
  is_macho "$file_path" || continue
  lipo -archs "$file_path" | tr ' ' '\n' | grep -qx arm64
  while IFS= read -r dependency; do
    case "$dependency" in
      /System/Library/*|/usr/lib/*|@loader_path/*|@rpath/*) ;;
      /*)
        echo "release bundle contains an external dependency: $file_path -> $dependency" >&2
        exit 1
        ;;
    esac
  done < <(otool -L "$file_path" | awk '/^[[:space:]]/{print $1}')
done < <(find "$CONTENTS/MacOS" "$CONTENTS/Frameworks" "$RUNTIME/bin" "$RUNTIME/lib" "$BUSINESS" \
  -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' -o -name '*.node' \) \
  -print | LC_ALL=C sort)

nm -gU "$NATIVE" | grep '_tuyubooking_contract' >/dev/null
nm -gU "$NATIVE" | grep '_tuyubooking_start' >/dev/null
nm -gU "$NATIVE" | grep '_tuyubooking_runtime_snapshot' >/dev/null
nm -gU "$NATIVE" | grep '_tuyubooking_restart_module' >/dev/null
# Keep verification side-effect free: validate the embedded version marker,
# signed-byte manifest, and enclosing code signature without launching servers.
strings "$RUNTIME/bin/postgres" | grep -F 'PostgreSQL) 17.11' >/dev/null
(
  cd "$RUNTIME"
  shasum -a 256 -c MANIFEST.sha256 >/dev/null
)
(
  cd "$BUSINESS"
  shasum -a 256 -c MANIFEST.sha256 >/dev/null
)
grep -q '"network_install_allowed": false' "$BUSINESS/runtime.lock.json"
grep -q '"database_name": "tuyubooking"' "$BUSINESS/runtime.lock.json"
# Business children inherit the App Sandbox and therefore cannot be launched by
# this unsandboxed shell. Their real execution is covered by smoke_bundle.py.
# Here we validate the locked version, signed bytes, and static binary marker.
# 不启动沙箱内业务进程；只读产品锁和包内Node静态版本标记。
NODE_VERSION="$(node --input-type=module - "$BUSINESS/runtime.lock.json" <<'NODE_TOOL'
import { readFileSync } from 'node:fs';
const lock = JSON.parse(readFileSync(process.argv[2], 'utf8'));
if (!lock.tools?.node?.version) throw new Error('TuyuBooking产品锁缺少Node版本');
process.stdout.write(lock.tools.node.version);
NODE_TOOL
)"
grep -q '"php": "8.4.24"' "$BUSINESS/runtime.lock.json"
grep -Fx "v$NODE_VERSION" < <(strings "$BUSINESS/node/bin/node") >/dev/null
grep -Fx '8.4.24' < <(strings "$BUSINESS/php/bin/php") >/dev/null
codesign --verify --deep --strict "$APP"
effective_entitlements="$(codesign -d --entitlements - "$APP" 2>&1)"
if grep -q 'com.apple.security.app-sandbox' <<< "$effective_entitlements"; then
  echo "App Sandbox is incompatible with embedded PostgreSQL System V IPC" >&2
  exit 1
fi
if grep -q 'keychain-access-groups' <<< "$effective_entitlements"; then
  echo "release bundle must not request a shared Keychain access group" >&2
  exit 1
fi
echo "verified macOS bundle: $APP"
