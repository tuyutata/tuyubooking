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
TUYU_SERVE_URL="${TUYU_SERVE_URL:?TUYU_SERVE_URL must be an HTTPS origin}"
WORK_DIR="${TUYUBOOKING_WORK_DIR:-${TMPDIR:-/tmp}/tuyubooking/client/macos}"
BUILD_DIR="${TUYUBOOKING_BUILD_DIR:-$WORK_DIR/build}"
DEPENDENCY_DIR="${TUYUBOOKING_DEPENDENCY_DIR:-$WORK_DIR/dependencies}"
ARTIFACT_DIR="${TUYUBOOKING_ARTIFACT_DIR:-$WORK_DIR/artifacts}"
FLUTTER_APP="$WORK_DIR/flutter-project"

case "$TUYU_SERVE_URL" in https://*) ;; *) echo 'TUYU_SERVE_URL must use HTTPS' >&2; exit 1 ;; esac
python3 - "$ROOT" "$WORK_DIR" "$BUILD_DIR" "$DEPENDENCY_DIR" "$ARTIFACT_DIR" <<'CHECK_PATHS'
from pathlib import Path
import sys
source = Path(sys.argv[1]).resolve()
for value in sys.argv[2:]:
    raw, target = Path(value), Path(value).resolve()
    if not raw.is_absolute() or target == source or source in target.parents:
        raise SystemExit(f'TuyuBooking可写目录必须是源码外绝对路径：{value}')
CHECK_PATHS

mkdir -p "$WORK_DIR" "$BUILD_DIR" "$DEPENDENCY_DIR" "$ARTIFACT_DIR"
rm -rf -- "$FLUTTER_APP"
export PUB_CACHE="${PUB_CACHE:-$DEPENDENCY_DIR/pub}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$DEPENDENCY_DIR/flutter-config}"
export CP_HOME_DIR="${CP_HOME_DIR:-$DEPENDENCY_DIR/cocoapods}"
export TMPDIR="$WORK_DIR/tmp/"
mkdir -p "$PUB_CACHE" "$XDG_CONFIG_HOME" "$CP_HOME_DIR" "$TMPDIR"
node "$ROOT/scripts/sdk-dependencies.mjs" prepare --platform macos \
  --output "$FLUTTER_APP" --offline "${TUYUBOOKING_OFFLINE:-false}"

# SDK安装到本次真实Pub插件视图；源码SHA来自产品声明和锁。
node "$ROOT/app/scripts/project.mjs" native --source-root "$ROOT/app" \
  --work-root "$WORK_DIR" --output "$FLUTTER_APP" --platform macos >/dev/null

XCODE_BUILD="$BUILD_DIR/xcode"
FLUTTER_BUILD="$BUILD_DIR/flutter"
APP="$XCODE_BUILD/Build/Products/Release/TuyuBooking Client.app"
OUTPUT="$ARTIFACT_DIR/tuyubooking-client.app"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_ENTITLEMENTS="$FLUTTER_APP/macos/Runner/Release.entitlements"

(
  cd "$FLUTTER_APP"
  flutter config --build-dir="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$FLUTTER_BUILD" "$FLUTTER_APP")" >/dev/null
  flutter build macos --no-pub --release --config-only --target lib/main_client.dart \
    --dart-define="TUYU_SERVE_URL=$TUYU_SERVE_URL"
  (cd macos && pod install)
  xcodebuild \
    -workspace macos/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -derivedDataPath "$XCODE_BUILD" \
    -destination 'platform=macOS,arch=arm64' \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    "TUYU_BOOKING_PRODUCT_NAME=TuyuBooking Client" \
    TUYU_BOOKING_BUNDLE_IDENTIFIER=com.tuyulove.tuyubooking.client \
    "TUYU_BOOKING_DISPLAY_NAME=TuyuBooking Client" \
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS=NO \
    CODE_SIGN_ENTITLEMENTS=
)

test -d "$APP"
test -d "$APP/Contents/Frameworks/CitizenSDK.framework"
[[ "$(xcrun lipo -archs "$APP/Contents/Frameworks/CitizenSDK.framework/CitizenSDK")" == arm64 ]]
test ! -e "$APP/Contents/Resources/postgresql"
test ! -e "$APP/Contents/Resources/business"
test ! -e "$APP/Contents/Frameworks/libtuyubooking_native.dylib"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP/Contents/Frameworks/CitizenSDK.framework"
rm -rf -- "$OUTPUT"
ditto "$APP" "$OUTPUT"
APP="$OUTPUT"
bundle_name="$(basename "$APP" .app)"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $bundle_name" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $bundle_name" "$APP/Contents/Info.plist"
codesign --force --sign "$IDENTITY" --timestamp=none --options runtime \
  --entitlements "$APP_ENTITLEMENTS" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "built TuyuBooking macOS client app: $OUTPUT"
