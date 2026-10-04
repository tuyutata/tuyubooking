#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DESTINATION="${1:?usage: build_macos.sh DESTINATION}"
# 原件输入在创建或清理任何本轮目录前验证；没有交付组件就保持源码与既有候选不变。
"${NODE:?缺少Node准确入口}" --input-type=module - "$ROOT" <<'COMPONENT_INPUTS'
import { lstatSync, realpathSync } from 'node:fs';
import { isAbsolute, resolve, sep } from 'node:path';
const source = realpathSync(process.argv[2]);
for (const name of ['TUYU_PHP_PREFIX', 'TUYU_OPENSSL_PREFIX', 'TUYU_PCRE2_PREFIX']) {
  const path = process.env[name];
  if (!path || !isAbsolute(path) || resolve(path) !== path || realpathSync(path) !== path
    || !lstatSync(path).isDirectory() || path === source || path.startsWith(source + sep)
    || source.startsWith(path + sep)) throw Error('编译组件未交付或目录身份无效：' + name);
}
COMPONENT_INPUTS

DEPENDENCY_WORK_DIR="${TUYUBOOKING_DEPENDENCY_DIR:-${TMPDIR:-/tmp}/tuyubooking/dependencies}"
BUILD_ROOT="${TUYUBOOKING_BUILD_DIR:-${TMPDIR:-/tmp}/tuyubooking/build}"
CACHE="$DEPENDENCY_WORK_DIR/runtime"
VOYANT_OUTPUT="${TUYU_VOYANT_OUTPUT_DIR:-$BUILD_ROOT/voyant-output}"
"${PYTHON:?缺少Python准确入口}" - "$ROOT" "$DEPENDENCY_WORK_DIR" "$BUILD_ROOT" "$DESTINATION" "$VOYANT_OUTPUT" <<'CHECK_PATHS'
from pathlib import Path
import sys
source = Path(sys.argv[1]).resolve()
for value in sys.argv[2:]:
    raw, target = Path(value), Path(value).resolve()
    if not raw.is_absolute() or target == source or source in target.parents:
        raise SystemExit(f'TuyuBooking可写目录必须是源码外绝对路径：{value}')
CHECK_PATHS
mkdir -p "$CACHE" "$BUILD_ROOT"
WORK="$(mktemp -d "$BUILD_ROOT/business-build.XXXXXX")"

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "TuyuBooking business runtime build requires macOS" >&2
  exit 1
fi

# The first macOS release line uses the same minimum as the packaged
# PostgreSQL, PHP and OpenSSL build inputs. Never inherit the build host SDK.
export MACOSX_DEPLOYMENT_TARGET=26.0

cleanup() {
  # 只清理本次独占工作目录，绝不清理上游源码目录。
  find "$WORK" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$CACHE" "$WORK" "$(dirname "$DESTINATION")"
if [ -n "$DEPENDENCY_WORK_DIR" ]; then
  mkdir -p "$DEPENDENCY_WORK_DIR/package-managers/npm" \
    "$DEPENDENCY_WORK_DIR/package-managers/yarn" \
    "$DEPENDENCY_WORK_DIR/package-managers/pip" \
    "$DEPENDENCY_WORK_DIR/frappe-assets" \
    "$DEPENDENCY_WORK_DIR/voyant-assets" \
    "$DEPENDENCY_WORK_DIR/hi-events-assets"
  export npm_config_cache="$DEPENDENCY_WORK_DIR/package-managers/npm"
  export YARN_CACHE_FOLDER="$DEPENDENCY_WORK_DIR/package-managers/yarn"
  export PIP_CACHE_DIR="$DEPENDENCY_WORK_DIR/package-managers/pip"
fi
if [ -e "$DESTINATION" ]; then find "$DESTINATION" -depth -delete; fi
mkdir -p "$DESTINATION"

# 只消费调用方已交付的编译组件，禁止编译时由包管理器选择版本或来源。
: "${TUYU_PHP_PREFIX:?缺少验真的PHP编译组件}" "${TUYU_OPENSSL_PREFIX:?缺少验真的OpenSSL编译组件}" "${TUYU_PCRE2_PREFIX:?缺少验真的PCRE2编译组件}"

fetch_locked() {
  # 产品锁固定归档；开发者缓存命中时直接复用，缺失时最多三次取得并原子落盘。
  local url="$1" expected="$2" destination="$3" pending="$3.pending.$$" actual attempt
  if [[ -f "$destination" && ! -L "$destination" ]]; then
    actual="$(shasum -a 256 "$destination" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || { echo "依赖缓存摘要不符：$destination" >&2; return 1; }
    return
  fi
  for attempt in 1 2 3; do
    rm -f -- "$pending"
    if curl --fail --location --silent --show-error --output "$pending" "$url" \
      && [[ "$(shasum -a 256 "$pending" | awk '{print $1}')" == "$expected" ]]; then
      mv "$pending" "$destination"
      return
    fi
  done
  rm -f -- "$pending"
  echo "依赖三次取得或摘要校验失败：$url" >&2
  return 1
}

copy_tree() {
  local source="$1" destination="$2"
  ditto "$source" "$destination"
}

copy_source() {
  local source="$1" destination="$2"
  mkdir -p "$destination"
  rsync -a --delete \
    --exclude '.git' --exclude 'node_modules' --exclude '.turbo' --exclude '.output' \
    --exclude 'vendor' --exclude 'dist' \
    "$source/" "$destination/"
}

PHP_PREFIX="${TUYU_PHP_PREFIX}"
OPENSSL_PREFIX="${TUYU_OPENSSL_PREFIX}"
PCRE2_PREFIX="${TUYU_PCRE2_PREFIX}"
# 随包Node与构建Yarn只读TuyuBooking自己的runtime.lock.json。
RUNTIME_TOOLS="$(node --input-type=module - "$SCRIPT_DIR/runtime.lock.json" <<'NODE_TOOLS'
import {readFileSync} from 'node:fs';
const tools=JSON.parse(readFileSync(process.argv[2],'utf8')).tools;
for(const id of ['node','yarn']) {
  const tool=tools[id];
  process.stdout.write([tool.version,tool.url,tool.sha256,tool.archive,tool.root].join('\n')+'\n');
}
NODE_TOOLS
)"
{ IFS= read -r NODE_VERSION; IFS= read -r NODE_URL; IFS= read -r NODE_SHA256;
  IFS= read -r NODE_ARCHIVE; IFS= read -r NODE_ROOT;
  IFS= read -r YARN_VERSION; IFS= read -r YARN_URL; IFS= read -r YARN_SHA256;
  IFS= read -r YARN_ARCHIVE; IFS= read -r YARN_ROOT; } <<< "$RUNTIME_TOOLS"
fetch_locked "$NODE_URL" "$NODE_SHA256" "$CACHE/$NODE_ARCHIVE"
tar -xzf "$CACHE/$NODE_ARCHIVE" -C "$WORK"
NODE_PREFIX="$WORK/$NODE_ROOT"

test -x "$PHP_PREFIX/bin/php"
test -x "$PHP_PREFIX/sbin/php-fpm"
test -x "$OPENSSL_PREFIX/bin/openssl"
test -x "$NODE_PREFIX/bin/node"
"$PHP_PREFIX/bin/php" --version | head -n 1 | grep -q '^PHP 8\.4\.24'
"$OPENSSL_PREFIX/bin/openssl" version | grep -q '^OpenSSL 3\.6\.3'
test "$("$NODE_PREFIX/bin/node" --version)" = "v$NODE_VERSION"

copy_tree "$PHP_PREFIX" "$DESTINATION/php"
copy_tree "$OPENSSL_PREFIX" "$DESTINATION/openssl"
copy_tree "$NODE_PREFIX" "$DESTINATION/node"

PYTHON_ARCHIVE="$CACHE/Python-3.14.3.tgz"
fetch_locked \
  "https://www.python.org/ftp/python/3.14.3/Python-3.14.3.tgz" \
  "d7fe130d0501ae047ca318fa92aa642603ab6f217901015a1df6ce650d5470cd" \
  "$PYTHON_ARCHIVE"
tar -xzf "$PYTHON_ARCHIVE" -C "$WORK"
(
  cd "$WORK/Python-3.14.3"
  CPPFLAGS="-I$OPENSSL_PREFIX/include" \
  LDFLAGS="-L$OPENSSL_PREFIX/lib" \
  ac_cv_func_dup3=no \
  ac_cv_func_pipe2=no \
    ./configure \
      --prefix="$DESTINATION/python" \
      --enable-shared \
      --with-ensurepip=install \
      --with-openssl="$OPENSSL_PREFIX"
  make -j"$(sysctl -n hw.logicalcpu)"
  make install
)
PYTHON="$DESTINATION/python/bin/python3"
"$PYTHON" --version 2>&1 | grep -q '^Python 3\.14\.3$'
"$PYTHON" - "$DESTINATION/python" <<'PY'
import pathlib
import sys
import sysconfig

prefix = pathlib.Path(sys.argv[1]).resolve()
purelib = pathlib.Path(sysconfig.get_paths()["purelib"]).resolve()
if prefix not in purelib.parents:
    raise SystemExit(f"Python package directory escaped runtime: {purelib}")
PY

# Yarn仅用于本次构建，不封入运行包，也不依赖Node是否附带Corepack。
fetch_locked "$YARN_URL" "$YARN_SHA256" "$CACHE/$YARN_ARCHIVE"
mkdir -p "$WORK/yarn"
tar -xzf "$CACHE/$YARN_ARCHIVE" -C "$WORK/yarn"
YARN="$WORK/yarn/$YARN_ROOT/bin/yarn.js"
test "$("$DESTINATION/node/bin/node" "$YARN" --version)" = "$YARN_VERSION"
export PATH="$DESTINATION/node/bin:$(dirname "$YARN"):$PATH"

NGINX_ARCHIVE="$CACHE/nginx-1.30.4.tar.gz"
fetch_locked \
  "https://nginx.org/download/nginx-1.30.4.tar.gz" \
  "4261dc90e9e47c1c4041276e9aaa3d48ebe2e664f728e14fa95ae6c67d57a08b" \
  "$NGINX_ARCHIVE"
tar -xzf "$NGINX_ARCHIVE" -C "$WORK"
(
  cd "$WORK/nginx-1.30.4"
  ./configure \
    --prefix="$DESTINATION/nginx" \
    --sbin-path="$DESTINATION/nginx/sbin/nginx" \
    --conf-path="$DESTINATION/nginx/conf/nginx.conf" \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-pcre-jit \
    --with-cc-opt="-I$PCRE2_PREFIX/include -I$OPENSSL_PREFIX/include" \
    --with-ld-opt="-L$PCRE2_PREFIX/lib -L$OPENSSL_PREFIX/lib"
  make -j"$(sysctl -n hw.logicalcpu)"
  make install
)
"$DESTINATION/nginx/sbin/nginx" -v 2>&1 | grep -q '^nginx version: nginx/1\.30\.4$'

BENCH="$DESTINATION/bench"
mkdir -p "$BENCH/apps" "$BENCH/sites"
for app in frappe erpnext hrms kamra ury; do
  copy_source "$ROOT/upstream/$app" "$BENCH/apps/$app"
done

# The product runtime is PostgreSQL-only. Remove MariaDB-only drivers from the
# disposable Frappe build copy without changing the imported upstream source.
FRAPPE_PROJECT="$BENCH/apps/frappe/pyproject.toml"
sed -i '' \
  -e '/"PyMySQL==1\.1\.2",/d' \
  -e '/"mysqlclient==2\.2\.7",/d' \
  "$FRAPPE_PROJECT"
if grep -Eq '"(PyMySQL==1\.1\.2|mysqlclient==2\.2\.7)"' "$FRAPPE_PROJECT"; then
  echo "failed to remove MariaDB-only Frappe dependencies" >&2
  exit 1
fi

export PYTHONNOUSERSITE=1
# Python依赖由产品自己的pyproject清单和pip解析，调用方只选择产品缓存目录。
unset PIP_NO_CACHE_DIR UV_NO_CACHE
export PIP_CACHE_DIR="$DEPENDENCY_WORK_DIR/package-managers/pip"
export UV_CACHE_DIR="$DEPENDENCY_WORK_DIR/package-managers/uv"
mkdir -p "$PIP_CACHE_DIR" "$UV_CACHE_DIR"
PIP_NETWORK_ARGS=()
case "${TUYUBOOKING_OFFLINE:-false}" in
  true) PIP_NETWORK_ARGS+=(--no-index) ;;
  false) ;;
  *) echo 'TUYUBOOKING_OFFLINE只接受true或false' >&2; exit 1 ;;
esac
"$PYTHON" -m pip install --disable-pip-version-check --break-system-packages \
  --cache-dir "$PIP_CACHE_DIR" "${PIP_NETWORK_ARGS[@]}" "$BENCH/apps/frappe"
for app in erpnext hrms kamra ury; do
  "$PYTHON" -m pip install --disable-pip-version-check --break-system-packages \
    --cache-dir "$PIP_CACHE_DIR" "${PIP_NETWORK_ARGS[@]}" "$BENCH/apps/$app"
done
TUYU_FRAPPE_ASSET_CACHE="${DEPENDENCY_WORK_DIR:+$DEPENDENCY_WORK_DIR/frappe-assets}" \
  "$SCRIPT_DIR/build_frappe_assets.sh" "$DESTINATION" "$YARN"

VOYANT_SOURCE="$ROOT/upstream/voyant"
VOYANT_BUILD_SOURCE="$WORK/voyant-source"
VOYANT_LOCK_SHA256="$(shasum -a 256 "$VOYANT_SOURCE/pnpm-lock.yaml" | awk '{print $1}')"
copy_source "$VOYANT_SOURCE" "$VOYANT_BUILD_SOURCE"
PNPM_TOOL="$("$DESTINATION/node/bin/node" --input-type=module - "$SCRIPT_DIR/runtime.lock.json" <<'NODE_PNPM'
import {readFileSync} from 'node:fs';
const tool=JSON.parse(readFileSync(process.argv[2],'utf8')).tools.pnpm;
process.stdout.write([tool.version,tool.url,tool.sha256,tool.archive,tool.root].join('\n'));
NODE_PNPM
)"
{ IFS= read -r PNPM_VERSION; IFS= read -r PNPM_URL; IFS= read -r PNPM_SHA256;
  IFS= read -r PNPM_ARCHIVE; IFS= read -r PNPM_ROOT; } <<< "$PNPM_TOOL"
fetch_locked "$PNPM_URL" "$PNPM_SHA256" "$CACHE/$PNPM_ARCHIVE"
mkdir -p "$WORK/pnpm"
tar -xzf "$CACHE/$PNPM_ARCHIVE" -C "$WORK/pnpm"
VOYANT_PNPM="$WORK/pnpm/$PNPM_ROOT/bin/pnpm.cjs"
VOYANT_PNPM_STORE="$DEPENDENCY_WORK_DIR/package-managers/pnpm-store"
test "$("$DESTINATION/node/bin/node" "$VOYANT_PNPM" --version)" = "$PNPM_VERSION"
mkdir -p "$VOYANT_PNPM_STORE"
PNPM_OPTIONS=()
if [ "${TUYUBOOKING_OFFLINE:-false}" = true ]; then PNPM_OPTIONS+=(--offline); fi
(
  cd "$VOYANT_BUILD_SOURCE"
  # 依赖只安装到产品临时源码副本；锁文件和包管理器版本保持冻结。
  export HUSKY=0 CI=true
  "$DESTINATION/node/bin/node" "$VOYANT_PNPM" install --frozen-lockfile "${PNPM_OPTIONS[@]}" \
    --store-dir "$VOYANT_PNPM_STORE"
)
export PATH="$DESTINATION/node/bin:$VOYANT_BUILD_SOURCE/node_modules/.bin:$PATH"
VOYANT_CACHE="${DEPENDENCY_WORK_DIR:+$DEPENDENCY_WORK_DIR/voyant-assets}"
VOYANT_FINGERPRINT=""
if [ -n "$VOYANT_CACHE" ]; then
  VOYANT_FINGERPRINT="$({
    printf '%s\n' 'tuyu-voyant-assets-v1'
    printf '%s\n' "$NODE_VERSION" "$NODE_SHA256"
    find "$ROOT/upstream/voyant/templates/operator" -type f \
      ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/.output/*' \
      -exec shasum -a 256 {} + | LC_ALL=C sort
    shasum -a 256 "$ROOT/upstream/voyant/pnpm-lock.yaml"
  } | shasum -a 256 | awk '{print $1}')"
fi
if [ -n "$VOYANT_CACHE" ] \
  && [ -f "$VOYANT_CACHE/fingerprint" ] \
  && [ "$(cat "$VOYANT_CACHE/fingerprint")" = "$VOYANT_FINGERPRINT" ] \
  && [ -f "$VOYANT_CACHE/output/server/index.mjs" ]; then
  if [ -e "$VOYANT_OUTPUT" ]; then find "$VOYANT_OUTPUT" -depth -delete; fi
  copy_tree "$VOYANT_CACHE/output" "$VOYANT_OUTPUT"
else
  (
    cd "$VOYANT_BUILD_SOURCE/templates/operator"
    TUYU_VOYANT_OUTPUT_DIR="$VOYANT_OUTPUT" \
      "$DESTINATION/node/bin/node" scripts/build-tuyu.mjs
  )
  if [ -n "$VOYANT_CACHE" ]; then
    VOYANT_CACHE_NEXT="$VOYANT_CACHE.next.$$"
    if [ -e "$VOYANT_CACHE_NEXT" ]; then find "$VOYANT_CACHE_NEXT" -depth -delete; fi
    mkdir -p "$VOYANT_CACHE_NEXT"
    copy_tree "$VOYANT_OUTPUT" "$VOYANT_CACHE_NEXT/output"
    printf '%s\n' "$VOYANT_FINGERPRINT" > "$VOYANT_CACHE_NEXT/fingerprint"
    if [ -e "$VOYANT_CACHE" ]; then find "$VOYANT_CACHE" -depth -delete; fi
    mv "$VOYANT_CACHE_NEXT" "$VOYANT_CACHE"
  fi
fi
test "$(shasum -a 256 "$VOYANT_SOURCE/pnpm-lock.yaml" | awk '{print $1}')" = "$VOYANT_LOCK_SHA256"
test -f "$VOYANT_OUTPUT/server/index.mjs"
mkdir -p "$DESTINATION/voyant/operator"
copy_tree "$VOYANT_OUTPUT" "$DESTINATION/voyant/operator/.output"
copy_tree "$VOYANT_BUILD_SOURCE/templates/operator/migrations" \
  "$DESTINATION/voyant/operator/migrations"

HI_EVENTS_WORK="$WORK/hi_events"
copy_source "$ROOT/upstream/hi_events/backend" "$HI_EVENTS_WORK/backend"
copy_source "$ROOT/upstream/hi_events/frontend" "$HI_EVENTS_WORK/frontend"
HI_EVENTS_CACHE="${DEPENDENCY_WORK_DIR:+$DEPENDENCY_WORK_DIR/hi-events-assets}"
HI_EVENTS_FINGERPRINT=""
HI_EVENTS_CACHE_HIT=0
if [ -n "$HI_EVENTS_CACHE" ]; then
  HI_EVENTS_FINGERPRINT="$({
    printf '%s\n' 'tuyu-hi-events-assets-v1'
    printf '%s\n' "$NODE_VERSION" "$NODE_SHA256" "$YARN_VERSION" "$YARN_SHA256"
    find "$ROOT/upstream/hi_events/frontend" -type f \
      ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/dist/*' \
      ! -path '*/build/*' ! -path '*/.next/*' ! -path '*/.output/*' \
      -exec shasum -a 256 {} + | LC_ALL=C sort
  } | shasum -a 256 | awk '{print $1}')"
  if [ -f "$HI_EVENTS_CACHE/fingerprint" ] \
    && [ "$(cat "$HI_EVENTS_CACHE/fingerprint")" = "$HI_EVENTS_FINGERPRINT" ] \
    && [ -f "$HI_EVENTS_CACHE/outputs.txt" ] \
    && [ -d "$HI_EVENTS_CACHE/node_modules" ]; then
    HI_EVENTS_CACHE_HIT=1
    copy_tree "$HI_EVENTS_CACHE/node_modules" "$HI_EVENTS_WORK/frontend/node_modules"
    while IFS= read -r generated; do
      [ -n "$generated" ] || continue
      [ -d "$HI_EVENTS_CACHE/$generated" ] || { HI_EVENTS_CACHE_HIT=0; break; }
      copy_tree "$HI_EVENTS_CACHE/$generated" "$HI_EVENTS_WORK/frontend/$generated"
    done < "$HI_EVENTS_CACHE/outputs.txt"
  fi
fi

# 固定Composer本体直接执行；生产依赖由composer.lock决定。
COMPOSER_TOOL="$(node --input-type=module - "$SCRIPT_DIR/runtime.lock.json" <<'NODE_COMPOSER'
import {readFileSync} from 'node:fs';
const tool=JSON.parse(readFileSync(process.argv[2],'utf8')).tools.composer;
process.stdout.write([tool.version,tool.url,tool.sha256,tool.archive].join('\n'));
NODE_COMPOSER
)"
{ IFS= read -r COMPOSER_VERSION; IFS= read -r COMPOSER_URL;
  IFS= read -r COMPOSER_SHA256; IFS= read -r COMPOSER_ARCHIVE; } <<< "$COMPOSER_TOOL"
COMPOSER="$CACHE/$COMPOSER_ARCHIVE"
fetch_locked "$COMPOSER_URL" "$COMPOSER_SHA256" "$COMPOSER"
COMPOSER_HOME="$DEPENDENCY_WORK_DIR/package-managers/composer-home"
COMPOSER_CACHE_DIR="$DEPENDENCY_WORK_DIR/package-managers/composer-cache"
export COMPOSER_HOME COMPOSER_CACHE_DIR
mkdir -p "$COMPOSER_HOME" "$COMPOSER_CACHE_DIR"
COMPOSER_NETWORK_ENV=()
if [ "${TUYUBOOKING_OFFLINE:-false}" = true ]; then COMPOSER_NETWORK_ENV+=(COMPOSER_DISABLE_NETWORK=1); fi
(
  cd "$HI_EVENTS_WORK/backend"
  env "${COMPOSER_NETWORK_ENV[@]}" "$DESTINATION/php/bin/php" "$COMPOSER" install \
    --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader
)
if [ "$HI_EVENTS_CACHE_HIT" != 1 ]; then
  YARN_NETWORK_ARGS=()
  if [ "${TUYUBOOKING_OFFLINE:-false}" = true ]; then YARN_NETWORK_ARGS+=(--offline); fi
  (
    cd "$HI_EVENTS_WORK/frontend"
    "$DESTINATION/node/bin/node" "$YARN" install --frozen-lockfile --non-interactive \
      --cache-folder "$YARN_CACHE_FOLDER" "${YARN_NETWORK_ARGS[@]}"
    "$DESTINATION/node/bin/node" "$YARN" build
    find node_modules -depth -delete
    "$DESTINATION/node/bin/node" "$YARN" install --frozen-lockfile --non-interactive \
      --cache-folder "$YARN_CACHE_FOLDER" "${YARN_NETWORK_ARGS[@]}" --production=true --ignore-scripts
  )
  if [ -n "$HI_EVENTS_CACHE" ]; then
    HI_EVENTS_CACHE_NEXT="$HI_EVENTS_CACHE.next.$$"
    if [ -e "$HI_EVENTS_CACHE_NEXT" ]; then find "$HI_EVENTS_CACHE_NEXT" -depth -delete; fi
    mkdir -p "$HI_EVENTS_CACHE_NEXT"
    copy_tree "$HI_EVENTS_WORK/frontend/node_modules" "$HI_EVENTS_CACHE_NEXT/node_modules"
    : > "$HI_EVENTS_CACHE_NEXT/outputs.txt"
    for generated in dist build .next .output; do
      if [ -d "$HI_EVENTS_WORK/frontend/$generated" ]; then
        copy_tree "$HI_EVENTS_WORK/frontend/$generated" "$HI_EVENTS_CACHE_NEXT/$generated"
        printf '%s\n' "$generated" >> "$HI_EVENTS_CACHE_NEXT/outputs.txt"
      fi
    done
    [ -s "$HI_EVENTS_CACHE_NEXT/outputs.txt" ] \
      || { echo 'Hi.Events前端没有产生可缓存资产目录' >&2; exit 1; }
    printf '%s\n' "$HI_EVENTS_FINGERPRINT" > "$HI_EVENTS_CACHE_NEXT/fingerprint"
    if [ -e "$HI_EVENTS_CACHE" ]; then find "$HI_EVENTS_CACHE" -depth -delete; fi
    mv "$HI_EVENTS_CACHE_NEXT" "$HI_EVENTS_CACHE"
  fi
fi
copy_tree "$HI_EVENTS_WORK" "$DESTINATION/hi_events"

mkdir -p "$DESTINATION/licenses/upstream" "$DESTINATION/licenses/build-inventory"
copy_tree "$ROOT/licenses" "$DESTINATION/licenses/upstream"
"$PYTHON" -m pip freeze > "$DESTINATION/licenses/build-inventory/python.txt"
cp "$ROOT/upstream/hi_events/backend/composer.lock" \
  "$DESTINATION/licenses/build-inventory/hi-events-composer.lock"
cp "$ROOT/upstream/hi_events/frontend/yarn.lock" \
  "$DESTINATION/licenses/build-inventory/hi-events-yarn.lock"
cp "$ROOT/upstream/voyant/pnpm-lock.yaml" \
  "$DESTINATION/licenses/build-inventory/voyant-pnpm-lock.yaml"

DESTINATION="$DESTINATION" ROOT="$ROOT" NODE_VERSION="$NODE_VERSION" "$PYTHON" - <<'PY'
import hashlib
import json
import os
from pathlib import Path

root = Path(os.environ["DESTINATION"])
repo = Path(os.environ["ROOT"])
locks = json.loads((repo / "scripts/business-runtime/runtime.lock.json").read_text())
packages = [
    {"SPDXID": "SPDXRef-Python", "name": "Python", "versionInfo": "3.14.3"},
    {"SPDXID": "SPDXRef-Node", "name": "Node.js", "versionInfo": os.environ["NODE_VERSION"]},
    {"SPDXID": "SPDXRef-PHP", "name": "PHP", "versionInfo": "8.4.24"},
    {"SPDXID": "SPDXRef-Nginx", "name": "Nginx", "versionInfo": "1.30.4"},
]
for name in ("frappe", "erpnext", "hrms", "kamra", "ury"):
    packages.append({
        "SPDXID": f"SPDXRef-{name}",
        "name": name,
        "versionInfo": locks[f"{name}_commit"],
    })
packages.extend([
    {"SPDXID": "SPDXRef-Voyant", "name": "Voyant", "versionInfo": locks["voyant"]["commit"]},
    {"SPDXID": "SPDXRef-HiEvents", "name": "Hi.Events", "versionInfo": locks["hi_events"]["commit"]},
])
(root / "sbom.spdx.json").write_text(json.dumps({
    "spdxVersion": "SPDX-2.3",
    "dataLicense": "CC0-1.0",
    "SPDXID": "SPDXRef-DOCUMENT",
    "name": "TuyuBooking-macOS-business-runtime",
    "documentNamespace": "https://tuyu.love/spdx/tuyubooking/business-runtime/macos",
    "creationInfo": {"creators": ["Tool: TuyuBooking build_macos.sh"]},
    "packages": packages,
}, ensure_ascii=False, indent=2) + "\n")

records = []
for path in sorted(root.rglob("*")):
    if not path.is_file() or path.name == "bundle.manifest.json":
        continue
    records.append({
        "path": path.relative_to(root).as_posix(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size": path.stat().st_size,
        "executable": bool(path.stat().st_mode & 0o111),
    })
(root / "bundle.manifest.json").write_text(json.dumps({
    "schema_version": 1,
    "platform": "macos",
    "network_install_allowed": False,
    "files": records,
}, ensure_ascii=False, indent=2) + "\n")
PY

echo "built TuyuBooking macOS business runtime: $DESTINATION"
