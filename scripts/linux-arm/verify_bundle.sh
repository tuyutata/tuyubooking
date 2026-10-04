#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: verify_bundle.sh <debian-staging-root>" >&2
  exit 2
fi
if [ "$(uname -s)" != Linux ]; then
  echo "Linux bundle verification requires a Linux host" >&2
  exit 1
fi
case "$(uname -m)" in
  aarch64|arm64) ;;
  *) echo "Linux bundle verification requires an ARM64 host" >&2; exit 1 ;;
esac

stage="$(cd "$1" && pwd)"
app="$stage/opt/tuyubooking"
runtime="$app/postgresql"
native="$app/lib/libtuyubooking_native.so"
business="$app/business"

for required in \
  "$app/tuyubooking" \
  "$native" \
  "$runtime/bin/postgres" \
  "$runtime/bin/initdb" \
  "$runtime/bin/pg_ctl" \
  "$runtime/MANIFEST.sha256" \
  "$business/python/bin/python3" \
  "$business/node/bin/node" \
  "$business/php/bin/php" \
  "$business/php/sbin/php-fpm" \
  "$business/nginx/sbin/nginx" \
  "$business/voyant/operator/.output/server/index.mjs" \
  "$business/voyant/operator/.output/migration/migrate.mjs" \
  "$business/voyant/operator/.output/migrations/meta/_journal.json" \
  "$business/tuyu_frappe_runtime.py" \
  "$business/tuyu_runtime_common.py" \
  "$business/tuyu_voyant_runtime.py" \
  "$business/tuyu_hi_events_runtime.py" \
  "$business/tuyu_https_proxy.py" \
  "$business/hi_events/backend/vendor/autoload.php" \
  "$business/hi_events/frontend/dist/server/entry.server.js" \
  "$business/runtime.lock.json" \
  "$business/bench/apps/frappe/LICENSE" \
  "$business/bench/apps/erpnext/license.txt" \
  "$business/bench/apps/hrms/license.txt" \
  "$business/bench/apps/kamra/license.txt" \
  "$business/bench/apps/ury/license.txt" \
  "$stage/DEBIAN/control" \
  "$stage/usr/share/applications/com.tuyulove.tuyubooking.desktop"; do
  test -e "$required" || { echo "missing Linux bundle file: $required" >&2; exit 1; }
done

"$business/python/bin/python3" --version 2>&1 | grep -q '^Python 3\.14\.'
"$business/node/bin/node" --version 2>&1 | grep -q '^v24\.'
"$business/php/bin/php" --version 2>&1 | grep -q '^PHP 8\.4\.'
grep -q '"network_install_allowed": false' "$business/runtime.lock.json"
grep -q '"database_name": "tuyubooking"' "$business/runtime.lock.json"

while IFS= read -r elf_file; do
  readelf -h "$elf_file" | grep -q 'Machine:.*AArch64' || {
    echo "non-AArch64 ELF in package: $elf_file" >&2
    exit 1
  }
  ldd "$elf_file" | grep -q 'not found' && {
    echo "unresolved Linux dependency: $elf_file" >&2
    exit 1
  }
  patchelf --print-rpath "$elf_file" | grep -qE '^\$ORIGIN' || {
    echo "non-relative Linux RPATH: $elf_file" >&2
    exit 1
  }
done < <(find "$app" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do readelf -h "$candidate" >/dev/null 2>&1 && printf '%s\n' "$candidate"; done)

nm -D "$native" | grep -q ' tuyubooking_contract$'
nm -D "$native" | grep -q ' tuyubooking_start$'
"$runtime/bin/postgres" --version | grep -F 'PostgreSQL) 17.11' >/dev/null
(
  cd "$runtime"
  sha256sum --check --status MANIFEST.sha256
)
grep -q '^Architecture: arm64$' "$stage/DEBIAN/control"
grep -q '^Exec=/opt/tuyubooking/tuyubooking$' "$stage/usr/share/applications/com.tuyulove.tuyubooking.desktop"
echo "verified TuyuBooking Linux ARM64 staging bundle: $stage"
