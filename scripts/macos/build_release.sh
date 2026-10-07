#!/bin/bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  LINK_TARGET="$(readlink "$SCRIPT_PATH")"
  [[ "$LINK_TARGET" == /* ]] || LINK_TARGET="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)/$LINK_TARGET"
  SCRIPT_PATH="$LINK_TARGET"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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
WORK_DIR="${TUYUBOOKING_WORK_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/host/macos}"
BUILD_WORK_DIR="${TUYUBOOKING_BUILD_DIR:-$WORK_DIR/build}"
DEPENDENCY_WORK_DIR="${TUYUBOOKING_DEPENDENCY_DIR:-$WORK_DIR/dependencies}"
ARTIFACT_DIR="${TUYUBOOKING_ARTIFACT_DIR:-$WORK_DIR/artifacts}"
export TUYUBOOKING_ROOT="$ROOT"
FLUTTER_APP="$WORK_DIR/flutter-project"
"${PYTHON:?缺少受控Python}" - "$ROOT" "$WORK_DIR" "$BUILD_WORK_DIR" "$DEPENDENCY_WORK_DIR" "$ARTIFACT_DIR" <<'CHECK_PATHS'
from pathlib import Path
import sys
source = Path(sys.argv[1]).resolve()
for value in sys.argv[2:]:
    raw, target = Path(value), Path(value).resolve()
    if not raw.is_absolute() or source / 'target' not in target.parents:
        raise SystemExit(f'TuyuBooking可写目录必须是本产品target内绝对路径：{value}')
CHECK_PATHS
mkdir -p "$WORK_DIR" "$BUILD_WORK_DIR" "$DEPENDENCY_WORK_DIR" "$ARTIFACT_DIR"
rm -rf -- "$FLUTTER_APP"
export PUB_CACHE="${PUB_CACHE:-$DEPENDENCY_WORK_DIR/pub}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$DEPENDENCY_WORK_DIR/flutter-config}"
export CP_HOME_DIR="${CP_HOME_DIR:-$DEPENDENCY_WORK_DIR/cocoapods}"
export TMPDIR="$WORK_DIR/tmp/"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$BUILD_WORK_DIR/cargo}"
mkdir -p "$PUB_CACHE" "$XDG_CONFIG_HOME" "$CP_HOME_DIR" "$TMPDIR" "$CARGO_TARGET_DIR"
"${NODE:?缺少受控Node}" "$ROOT/scripts/sdk-dependencies.mjs" prepare --platform macos \
  --output "$FLUTTER_APP" --offline "${TUYUBOOKING_OFFLINE:-false}"
# Apple安装件装入Pub实际解析的SDK视图，不引入邻仓模式或外部podspec路径。
"${NODE:?缺少受控Node}" "$ROOT/app/scripts/project.mjs" native --source-root "$ROOT/app" \
  --work-root "$WORK_DIR" --output "$FLUTTER_APP" --platform macos >/dev/null

assert_local_work_path() {
  local path="${1:?缺少产品生成路径}"
  case "$path" in "$WORK_DIR"|"$WORK_DIR"/*) ;; *) echo '生成路径不属于TuyuBooking工作目录' >&2; return 1 ;; esac
}

RUNTIME="$BUILD_WORK_DIR/runtime/postgresql"
BUSINESS_SOURCE="${TUYU_BUSINESS_RUNTIME_SOURCE:-}"
XCODE_BUILD="$BUILD_WORK_DIR/xcode"
FLUTTER_BUILD="$BUILD_WORK_DIR/flutter"
CARGO_BUILD="$CARGO_TARGET_DIR"
FLUTTER_CONFIG="$XDG_CONFIG_HOME"
APP="$XCODE_BUILD/Build/Products/Release/TuyuBooking Host.app"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
TUYU_SERVE_URL="${TUYU_SERVE_URL:?TUYU_SERVE_URL must be an HTTPS origin}"
APP_ENTITLEMENTS="$FLUTTER_APP/macos/Runner/Release.entitlements"
case "$TUYU_SERVE_URL" in
  https://*) ;;
  *) echo "TUYU_SERVE_URL must use HTTPS" >&2; exit 1 ;;
esac

# Fail on Flutter contract regressions before building the bundled business and
# PostgreSQL runtimes. The later build phase reuses this resolved application.
(
  cd "$FLUTTER_APP"
  export XDG_CONFIG_HOME="$FLUTTER_CONFIG"
  mkdir -p "$XDG_CONFIG_HOME"
  "${FLUTTER:?缺少受控Flutter}" config --build-dir="$("$PYTHON" -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$FLUTTER_BUILD" "$FLUTTER_APP")" >/dev/null
  "${FLUTTER:?缺少受控Flutter}" pub get
)

BUSINESS_BUILD=""
LOCAL_APP_ENTITLEMENTS=""
POSTGRES_TEST_TMP_ALIAS=""
POSTGRES_TEST_TMP_TARGET=""
cleanup() {
  if [ -n "$BUSINESS_BUILD" ] && [ -d "$BUSINESS_BUILD" ]; then
    assert_local_work_path "$BUSINESS_BUILD" || return 1
    find "$BUSINESS_BUILD" -depth -delete
  fi
  if [ -n "$LOCAL_APP_ENTITLEMENTS" ] && [ -f "$LOCAL_APP_ENTITLEMENTS" ]; then
    assert_local_work_path "$LOCAL_APP_ENTITLEMENTS" || return 1
    find "$LOCAL_APP_ENTITLEMENTS" -delete
  fi
  if [ -n "$POSTGRES_TEST_TMP_ALIAS" ] && [ -L "$POSTGRES_TEST_TMP_ALIAS" ]; then
    [[ "$(readlink "$POSTGRES_TEST_TMP_ALIAS")" == "$POSTGRES_TEST_TMP_TARGET" ]] \
      || { echo 'PostgreSQL测试短路径指向了非本任务目录，拒绝清理' >&2; return 1; }
    rm "$POSTGRES_TEST_TMP_ALIAS"
  fi
}
trap cleanup EXIT

# SDK 原生模块先从本轮解析的源码构建；失败时不再耗时构建四个业务运行时。
(
  cd "$FLUTTER_APP"
  export XDG_CONFIG_HOME="$FLUTTER_CONFIG"
  "${FLUTTER:?缺少受控Flutter}" build macos --release --config-only --target lib/main_host.dart \
    --dart-define="TUYU_SERVE_URL=$TUYU_SERVE_URL"
  cd macos
  "${POD:?缺少受控CocoaPods}" install
)

# Ad-hoc signatures have no Team ID, so Hardened Runtime cannot prove that the
# bundled Flutter frameworks belong to the app. This local-only entitlement is
# never used when CI/Release supplies a real Apple signing identity.
if [ "$IDENTITY" = "-" ]; then
  if [[ "${CI:-}" == true ]]; then
    LOCAL_APP_ENTITLEMENTS="$(mktemp "${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking-adhoc-entitlements.XXXXXX")"
  else
    LOCAL_APP_ENTITLEMENTS="$WORK_DIR/local.entitlements"
    assert_local_work_path "$LOCAL_APP_ENTITLEMENTS"
    [[ ! -e "$LOCAL_APP_ENTITLEMENTS" ]] || { echo '本机临时签名配置已存在，拒绝覆盖' >&2; exit 1; }
  fi
  cp "$APP_ENTITLEMENTS" "$LOCAL_APP_ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c \
    'Add :com.apple.security.cs.disable-library-validation bool true' \
    "$LOCAL_APP_ENTITLEMENTS"
  APP_ENTITLEMENTS="$LOCAL_APP_ENTITLEMENTS"
fi

if [ -z "$BUSINESS_SOURCE" ]; then
  if [[ "${CI:-}" == true ]]; then
    BUSINESS_BUILD="$(mktemp -d "${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking-release-runtime.XXXXXX")"
  else
    BUSINESS_BUILD="$WORK_DIR/runtime/business"
    assert_local_work_path "$BUSINESS_BUILD"
    [[ ! -e "$BUSINESS_BUILD" ]] || { echo '本机临时业务运行件已存在，拒绝覆盖' >&2; exit 1; }
    mkdir -p "$BUSINESS_BUILD"
  fi
  BUSINESS_SOURCE="$BUSINESS_BUILD/business"
  TUYU_VOYANT_OUTPUT_DIR="$WORK_DIR/voyant" \
    "$ROOT/scripts/business-runtime/build_macos.sh" "$BUSINESS_SOURCE"
fi

# 本轮按固定组件锁、GNU官方补丁和已交付工具编译完整运行时，禁止使用只覆盖入口摘要的旧缓存。
# 先创建本轮产物父目录，运行时入口再核验规范路径并排他创建postgresql。
mkdir -p "$BUILD_WORK_DIR/runtime"
TUYU_POSTGRES_DEST="$RUNTIME" "$SCRIPT_DIR/build_runtime.sh"

(
  cd "$FLUTTER_APP"
  export XDG_CONFIG_HOME="$FLUTTER_CONFIG"
  mkdir -p "$XDG_CONFIG_HOME"
  "${FLUTTER:?缺少受控Flutter}" config --build-dir="$("$PYTHON" -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$FLUTTER_BUILD" "$FLUTTER_APP")" >/dev/null
  "${XCODEBUILD:?缺少已验真Xcode}" \
    -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -derivedDataPath "$XCODE_BUILD" \
    -destination 'platform=macOS,arch=arm64' \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    "TUYU_BOOKING_PRODUCT_NAME=TuyuBooking Host" \
    TUYU_BOOKING_BUNDLE_IDENTIFIER=com.tuyulove.tuyubooking.host \
    "TUYU_BOOKING_DISPLAY_NAME=TuyuBooking Host" \
    CODE_SIGN_ENTITLEMENTS=
)
# PostgreSQL limits Unix-domain socket paths to 103 bytes on macOS. Keep all
# test data in the central task directory, but expose that directory through
# a short process-unique alias while the database integration tests run.
POSTGRES_TEST_TMP_TARGET="$WORK_DIR/tmp/postgres-tests"
assert_local_work_path "$POSTGRES_TEST_TMP_TARGET"
mkdir -p "$POSTGRES_TEST_TMP_TARGET"
POSTGRES_TEST_TMP_ALIAS="/tmp/tuyu-pg-test-$$"
[[ ! -e "$POSTGRES_TEST_TMP_ALIAS" && ! -L "$POSTGRES_TEST_TMP_ALIAS" ]] \
  || { echo 'PostgreSQL测试短路径已存在，拒绝覆盖' >&2; exit 1; }
ln -s "$POSTGRES_TEST_TMP_TARGET" "$POSTGRES_TEST_TMP_ALIAS"
(
  cd "$ROOT"
  export CARGO_TARGET_DIR="$CARGO_BUILD"
  TMPDIR="$POSTGRES_TEST_TMP_ALIAS" TUYU_POSTGRES_BIN="$RUNTIME/bin" "${CARGO:?缺少受控Cargo}" test --workspace --locked
  "$CARGO" build --locked --release --target aarch64-apple-darwin -p tuyubooking-native
)

test -d "$APP"
test -d "$APP/Contents/Frameworks/CitizenSDK.framework"
[[ "$( "${LIPO:?缺少已验真Lipo}" -archs "$APP/Contents/Frameworks/CitizenSDK.framework/CitizenSDK")" == arm64 ]]
mkdir -p "$APP/Contents/Frameworks" "$APP/Contents/Resources/postgresql"
ditto "$RUNTIME" "$APP/Contents/Resources/postgresql"
"$ROOT/scripts/business-runtime/materialize.sh" \
  "$BUSINESS_SOURCE" "$APP/Contents/Resources/business"
cp "$CARGO_BUILD/aarch64-apple-darwin/release/libtuyubooking_native.dylib" \
  "$APP/Contents/Frameworks/libtuyubooking_native.dylib"
"${INSTALL_NAME_TOOL:?缺少已验真安装名称工具}" -id '@rpath/libtuyubooking_native.dylib' \
  "$APP/Contents/Frameworks/libtuyubooking_native.dylib"

# Sign nested Mach-O code before signing the containing app bundle. PostgreSQL
# requires System V IPC, so direct-distribution children must not inherit an
# App Sandbox profile; local-only listeners are enforced by runtime config.
sign_nested_code() {
  local file_path="$1" signing_output
  if ! signing_output="$("${CODESIGN:?缺少已验真签名工具}" --force --sign "$IDENTITY" --timestamp=none "$file_path" 2>&1)"; then
    printf '%s\n' "$signing_output" >&2
    return 1
  fi
}

while IFS= read -r file_path; do
  if file -b "$file_path" | grep -q 'Mach-O'; then
    sign_nested_code "$file_path"
  fi
done < <(find "$APP/Contents/Resources/postgresql/bin" \
  "$APP/Contents/Resources/postgresql/lib" "$APP/Contents/Resources/business" "$APP/Contents/Frameworks" \
  -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' -o -name '*.node' \) \
  -print | LC_ALL=C sort)

# 嵌套二进制签名后再封装 SDK framework 的资源签名，保留标准版本化目录结构。
"${CODESIGN:?缺少已验真签名工具}" --force --sign "$IDENTITY" --timestamp=none "$APP/Contents/Frameworks/CitizenSDK.framework"

# Code signing changes Mach-O bytes, so manifests are generated after every
# nested executable and library is signed. One process avoids 100k+ forks.
"$PYTHON" "$SCRIPT_DIR/write_sha256_manifest.py" \
  "$APP/Contents/Resources/postgresql" \
  "$APP/Contents/Resources/postgresql/MANIFEST.sha256"
"$PYTHON" "$SCRIPT_DIR/write_sha256_manifest.py" \
  "$APP/Contents/Resources/business" \
  "$APP/Contents/Resources/business/MANIFEST.sha256"

# Finalize the delivery path before signing. Localized resources provide the
# public brand while the base names match the physical bundle for Finder.
rm -rf "$ARTIFACT_DIR/tuyubooking.app"
if [[ -n "$BUILD_WORK_DIR" ]]; then
  ditto "$APP" "$ARTIFACT_DIR/tuyubooking.app"
else
  mv "$APP" "$ARTIFACT_DIR/tuyubooking.app"
fi
APP="$ARTIFACT_DIR/tuyubooking.app"
bundle_name="$(basename "$APP" .app)"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $bundle_name" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $bundle_name" "$APP/Contents/Info.plist"

if ! app_signing_output="$("${CODESIGN:?缺少已验真签名工具}" --force --sign "$IDENTITY" --timestamp=none --options runtime \
  --entitlements "$APP_ENTITLEMENTS" "$APP" 2>&1)"; then
  printf '%s\n' "$app_signing_output" >&2
  exit 1
fi
"$SCRIPT_DIR/verify_bundle.sh" "$APP"
"$SCRIPT_DIR/smoke_bundle.py" "$APP"
echo "built TuyuBooking macOS app: $ARTIFACT_DIR/tuyubooking.app"
