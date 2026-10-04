#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${1:?usage: materialize.sh SOURCE DESTINATION}"
DESTINATION="${2:?usage: materialize.sh SOURCE DESTINATION}"

require_file() { test -f "$1" || { echo "missing runtime file: $1" >&2; exit 1; }; }
require_dir() { test -d "$1" || { echo "missing runtime directory: $1" >&2; exit 1; }; }
require_executable() { test -x "$1" || { echo "missing runtime executable: $1" >&2; exit 1; }; }

require_executable "$SOURCE/python/bin/python3"
"$SOURCE/python/bin/python3" --version 2>&1 | grep -q '^Python 3\.14\.'
require_executable "$SOURCE/node/bin/node"
# 组装再次读取TuyuBooking产品锁中的Node版本。
NODE_VERSION="$(node --input-type=module - "$SCRIPT_DIR/runtime.lock.json" <<'NODE_TOOL'
import { readFileSync } from 'node:fs';
const lock = JSON.parse(readFileSync(process.argv[2], 'utf8'));
if (!lock.tools?.node?.version) throw new Error('TuyuBooking产品锁缺少Node版本');
process.stdout.write(lock.tools.node.version);
NODE_TOOL
)"
test "$("$SOURCE/node/bin/node" --version)" = "v$NODE_VERSION"
require_executable "$SOURCE/php/bin/php"
"$SOURCE/php/bin/php" --version | grep -q '^PHP 8\.4\.'
require_executable "$SOURCE/php/sbin/php-fpm"
require_executable "$SOURCE/nginx/sbin/nginx"
require_executable "$SOURCE/openssl/bin/openssl"

for app in frappe erpnext hrms kamra ury; do require_dir "$SOURCE/bench/apps/$app"; done
require_file "$SOURCE/bench/sites/assets/assets.json"
require_file "$SOURCE/voyant/operator/.output/server/index.mjs"
require_file "$SOURCE/voyant/operator/.output/migration/migrate.mjs"
require_file "$SOURCE/voyant/operator/migrations/0000_baseline.sql"
require_file "$SOURCE/hi_events/backend/vendor/autoload.php"
require_file "$SOURCE/hi_events/frontend/server.js"
require_file "$SOURCE/hi_events/frontend/dist/client/index.html"
require_file "$SOURCE/hi_events/frontend/dist/server/entry.server.js"
require_dir "$SOURCE/hi_events/frontend/node_modules"
require_file "$SOURCE/sbom.spdx.json"
require_file "$SOURCE/bundle.manifest.json"

if test -n "$(find "$SOURCE/bench/apps" -name .git -print -quit)"; then
  echo "business runtime still contains version-control metadata; run build_frappe_assets.sh" >&2
  exit 1
fi
if test -n "$(find "$SOURCE/bench/apps" -type d -name node_modules -print -quit)"; then
  echo "business runtime still contains Frappe build dependencies; run build_frappe_assets.sh" >&2
  exit 1
fi

if [ -e "$DESTINATION" ]; then find "$DESTINATION" -depth -delete; fi
mkdir -p "$DESTINATION"

copy_tree() {
  local source="$1" destination="$2"
  mkdir -p "$destination"
  # Runtime trees contain generated assets and many relative symlinks. rsync's
  # archive contract copies the complete directory contents deterministically;
  # ditto can omit entries when merging these large generated trees.
  rsync -a --delete "$source/" "$destination/"
}

for directory in python node php nginx openssl bench voyant hi_events licenses; do
  copy_tree "$SOURCE/$directory" "$DESTINATION/$directory"
done
# Homebrew exposes its global PECL directory through an absolute symlink. The
# product runtime may use only extensions explicitly embedded in this bundle.
if [ -L "$DESTINATION/php/pecl" ]; then
  rm "$DESTINATION/php/pecl"
  mkdir -p "$DESTINATION/php/pecl"
fi
cp "$SOURCE/sbom.spdx.json" "$DESTINATION/sbom.spdx.json"
cp "$SOURCE/bundle.manifest.json" "$DESTINATION/bundle.manifest.json"

for script in tuyu_runtime_common.py tuyu_https_proxy.py tuyu_frappe_runtime.py tuyu_frappe_worker.py tuyu_frappe_wsgi.py tuyu_voyant_runtime.py tuyu_voyant_https.mjs tuyu_hi_events_runtime.py; do
  require_file "$SCRIPT_DIR/$script"
  cp "$SCRIPT_DIR/$script" "$DESTINATION/$script"
  chmod 0755 "$DESTINATION/$script"
done
cp "$SCRIPT_DIR/runtime.lock.json" "$DESTINATION/runtime.lock.json"
require_file "$DESTINATION/bench/sites/assets/assets.json"

while IFS= read -r link; do
  case "$(readlink "$link")" in
    /*) echo "business runtime contains an absolute symlink: $link" >&2; exit 1 ;;
  esac
done < <(find "$DESTINATION" -type l -print)

if [ "$(uname -s)" = Darwin ]; then
  "$SCRIPT_DIR/relocate_macos.sh" "$DESTINATION" "$SOURCE"
fi

echo "materialized TuyuBooking business runtime: $DESTINATION"
