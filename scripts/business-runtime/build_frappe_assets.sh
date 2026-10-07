#!/bin/bash
set -euo pipefail

SOURCE="${1:?usage: build_frappe_assets.sh BUSINESS_RUNTIME_SOURCE}"
BENCH="$SOURCE/bench"
NODE="$SOURCE/node/bin/node"
YARN="${2:?usage: build_frappe_assets.sh BUSINESS_RUNTIME_SOURCE VERIFIED_YARN}"
ASSETS="$BENCH/sites/assets"
FRAPPE_PUBLIC="$BENCH/apps/frappe/frappe/public"
APPS=(frappe erpnext hrms kamra ury)
ASSET_CACHE="${TUYU_FRAPPE_ASSET_CACHE:-}"

require_file() { test -f "$1" || { echo "missing Frappe build file: $1" >&2; exit 1; }; }
require_dir() { test -d "$1" || { echo "missing Frappe build directory: $1" >&2; exit 1; }; }
require_executable() { test -x "$1" || { echo "missing Frappe build executable: $1" >&2; exit 1; }; }

require_executable "$NODE"
require_executable "$YARN"
for app in "${APPS[@]}"; do
  require_dir "$BENCH/apps/$app/$app/public"
done
require_file "$BENCH/apps/frappe/yarn.lock"
require_file "$BENCH/apps/erpnext/yarn.lock"
require_file "$BENCH/apps/hrms/yarn.lock"

export PATH="$SOURCE/node/bin:$(dirname "$YARN"):$PATH"
# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。
PRODUCT_TEMP_SCRIPT="${BASH_SOURCE[0]}"
while [[ -L "$PRODUCT_TEMP_SCRIPT" ]]; do
  PRODUCT_TEMP_LINK="$(readlink "$PRODUCT_TEMP_SCRIPT")"
  [[ "$PRODUCT_TEMP_LINK" == /* ]] || PRODUCT_TEMP_LINK="$(cd "$(dirname "$PRODUCT_TEMP_SCRIPT")" && pwd -P)/$PRODUCT_TEMP_LINK"
  PRODUCT_TEMP_SCRIPT="$PRODUCT_TEMP_LINK"
done
PRODUCT_TEMP_SOURCE="$(cd "$(dirname "$PRODUCT_TEMP_SCRIPT")/../.." && pwd -P)"
PRODUCT_TARGET_TEMP_ROOT="$("${PRODUCT_NODE_BIN:-${NODE:-node}}" "$PRODUCT_TEMP_SOURCE/scripts/build.mjs" temporary-root "${PLATFORM:-${platform:-}}" 'host-macos')" || exit 1
if [[ -z "${PRODUCT_WORK_DIR:-}" && "${TMPDIR:-}" != "$PRODUCT_TEMP_SOURCE/target/"* ]]; then
  export TMPDIR="$PRODUCT_TARGET_TEMP_ROOT/"
fi
BUILD_TMP_ROOT="${TUYU_BUILD_TMPDIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}}"
mkdir -p "$BUILD_TMP_ROOT"
BUILD_TMP="$(mktemp -d "$BUILD_TMP_ROOT/tuyubooking-frappe-assets.XXXXXX")"
export TMPDIR="$BUILD_TMP"
export FRAPPE_BENCH_ROOT="$BENCH"
export NODE_OPTIONS="--max_old_space_size=4096"

asset_fingerprint() {
  {
    printf '%s\n' 'tuyu-frappe-assets-v1'
    shasum -a 256 "$0"
    # 工具变化必须使资源缓存失效，不能复用另一版本的编译结果。
    shasum -a 256 "$NODE" "$YARN"
    find "$BENCH/apps" -type f \
      ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/sites/assets/*' \
      -exec shasum -a 256 {} + | LC_ALL=C sort
  } | shasum -a 256 | awk '{print $1}'
}

copy_tree() {
  local source="$1" destination="$2"
  if command -v ditto >/dev/null 2>&1; then
    ditto "$source" "$destination"
  else
    cp -a "$source" "$destination"
  fi
}

cleanup() {
  if test -L "$FRAPPE_PUBLIC/node_modules"; then
    find "$FRAPPE_PUBLIC/node_modules" -delete
  fi
  if test -d "$BUILD_TMP"; then
    find "$BUILD_TMP" -depth -delete
  fi
}
trap cleanup EXIT

ASSET_FINGERPRINT=""
if test -n "$ASSET_CACHE"; then
  ASSET_FINGERPRINT="$(asset_fingerprint)"
  if test -f "$ASSET_CACHE/fingerprint" \
    && test "$(cat "$ASSET_CACHE/fingerprint")" = "$ASSET_FINGERPRINT" \
    && test -f "$ASSET_CACHE/assets/assets.json"; then
    if test -e "$ASSETS" || test -L "$ASSETS"; then
      find "$ASSETS" -depth -delete
    fi
    mkdir -p "$ASSETS"
    copy_tree "$ASSET_CACHE/assets/." "$ASSETS"
    printf 'frappe\nerpnext\nhrms\nkamra\nury\n' > "$BENCH/sites/apps.txt"
    echo "reused immutable TuyuBooking Frappe assets: $ASSETS"
    exit 0
  fi
fi

# Yarn版本由TuyuBooking runtime锁固定，依赖闭包由各上游yarn.lock决定。
YARN_CACHE_FOLDER="${YARN_CACHE_FOLDER:-${TUYUBOOKING_DEPENDENCY_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/dependencies}/package-managers/yarn}"
mkdir -p "$YARN_CACHE_FOLDER"
YARN_NETWORK_ARGS=()
case "${TUYUBOOKING_OFFLINE:-false}" in
  true) YARN_NETWORK_ARGS+=(--offline) ;;
  false) ;;
  *) echo 'TUYUBOOKING_OFFLINE只接受true或false' >&2; exit 1 ;;
esac

install_locked_dependencies() {
  local app="$1"
  shift
  (
    cd "$BENCH/apps/$app"
    "$NODE" "$YARN" --cache-folder "$YARN_CACHE_FOLDER" \
      install --frozen-lockfile --non-interactive --network-timeout 60000 \
      "${YARN_NETWORK_ARGS[@]}" "$@"
  )
}

# These dependencies exist only on the trusted build machine. They are pruned
# after the immutable browser assets have been generated.
install_locked_dependencies frappe
install_locked_dependencies erpnext --ignore-scripts
install_locked_dependencies hrms --ignore-scripts

# @frappe/esbuild-plugin-postcss2 0.1.3 derives an entry-point temporary path
# from path.relative(). When Node resolves an input through a different macOS
# filesystem root, the relative path contains ".." segments and path.resolve()
# escapes the plugin temporary directory.
# Patch only the disposable, lockfile-installed build dependency. The exact
# one-match gate makes an upstream plugin change fail closed instead of silently
# applying an incompatible replacement.
POSTCSS_PLUGIN="$BENCH/apps/frappe/node_modules/@frappe/esbuild-plugin-postcss2/dist/index.js"
require_file "$POSTCSS_PLUGIN"
"$NODE" - "$POSTCSS_PLUGIN" <<'NODE'
const fs = require("fs");

const file = process.argv[2];
const source = fs.readFileSync(file, "utf8");
const unsafe = `        const sourceRelDir = import_path.default.relative(import_path.default.dirname(rootDir), import_path.default.dirname(sourceFullPath));
        tmpFilePath = import_path.default.resolve(tmpDirPath, sourceRelDir, \`${"${sourceBaseName}"}.css\`);`;
const safe = `        tmpFilePath = import_path.default.resolve(tmpDirPath, uniqueId(), \`${"${sourceBaseName}"}.css\`);`;
const count = source.split(unsafe).length - 1;
if (count !== 1) {
  throw new Error(`postcss2 entry-point temp-path contract drifted: expected 1 match, found ${count}`);
}
fs.writeFileSync(file, source.replace(unsafe, safe));
NODE

if test -e "$ASSETS" || test -L "$ASSETS"; then
  find "$ASSETS" -depth -delete
fi
mkdir -p "$ASSETS"
printf 'frappe\nerpnext\nhrms\nkamra\nury\n' > "$BENCH/sites/apps.txt"

# Kamra and URY publish their committed front-end output through their own
# public directories. Frappe, ERPNext and HRMS bundles are added below.
for app in "${APPS[@]}"; do
  copy_tree "$BENCH/apps/$app/$app/public" "$ASSETS/$app"
done

if test -e "$FRAPPE_PUBLIC/node_modules" || test -L "$FRAPPE_PUBLIC/node_modules"; then
  echo "unexpected Frappe public/node_modules path" >&2
  exit 1
fi
# One upstream stylesheet imports this conventional build-time path. The link
# is temporary and never enters the runtime payload.
ln -s ../../node_modules "$FRAPPE_PUBLIC/node_modules"

find \
  "$BENCH/apps/frappe/frappe/public/scss" \
  "$BENCH/apps/erpnext/erpnext/public/scss" \
  "$BENCH/apps/hrms/hrms/public/scss" \
  -type f -name '*.bundle.css' -delete

# Frappe resolves CSS imports relative to its app root, so this working
# directory is part of the reproducible build contract.
(
  cd "$BENCH/apps/frappe"
  "$NODE" esbuild --production --apps frappe,erpnext,hrms
)

require_file "$ASSETS/assets.json"
"$NODE" - "$ASSETS/assets.json" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const assets = JSON.parse(fs.readFileSync(file, "utf8"));
for (const key of ["login.bundle.css", "desk.bundle.js", "erpnext.bundle.js", "hrms.bundle.js"]) {
  if (typeof assets[key] !== "string" || !assets[key].startsWith("/assets/")) {
    throw new Error(`missing required Frappe asset: ${key}`);
  }
}
NODE

if test -n "$ASSET_CACHE"; then
  ASSET_CACHE_NEXT="$ASSET_CACHE.next.$$"
  if test -e "$ASSET_CACHE_NEXT"; then find "$ASSET_CACHE_NEXT" -depth -delete; fi
  mkdir -p "$ASSET_CACHE_NEXT/assets"
  copy_tree "$ASSETS/." "$ASSET_CACHE_NEXT/assets"
  printf '%s\n' "$ASSET_FINGERPRINT" > "$ASSET_CACHE_NEXT/fingerprint"
  if test -e "$ASSET_CACHE"; then find "$ASSET_CACHE" -depth -delete; fi
  mv "$ASSET_CACHE_NEXT" "$ASSET_CACHE"
fi

find \
  "$BENCH/apps/frappe/frappe/public/scss" \
  "$BENCH/apps/erpnext/erpnext/public/scss" \
  "$BENCH/apps/hrms/hrms/public/scss" \
  -type f -name '*.bundle.css' -delete

# Application source and generated assets are runtime inputs. Package-manager
# trees and version-control metadata are build inputs and must not ship.
find "$BENCH/apps" -type d -name node_modules -prune -print0 |
  while IFS= read -r -d '' directory; do find "$directory" -depth -delete; done
find "$BENCH/apps" -name .git -print0 |
  while IFS= read -r -d '' marker; do find "$marker" -depth -delete; done

echo "built immutable TuyuBooking Frappe assets: $ASSETS"
