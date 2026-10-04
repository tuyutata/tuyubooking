#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="${TUYUBOOKING_WORK_DIR:-${TMPDIR:-/tmp}/tuyubooking/linux-amd}"
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
DESKTOP="$(node "$ROOT/app/scripts/project.mjs" create --source-root "$ROOT/app" --work-root "$WORK_DIR" --platform linux-amd)"
RUNTIME="$WORK_DIR/runtime/postgresql/linux-amd"
export TUYUBOOKING_ROOT="$ROOT"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$WORK_DIR/cargo}"
BUSINESS_SOURCE="${TUYU_BUSINESS_RUNTIME_SOURCE:-$ROOT/host/runtime/business/linux-amd}"
TUYU_SERVE_URL="${TUYU_SERVE_URL:?TUYU_SERVE_URL must be an HTTPS origin}"

if [ "$(uname -s)" != Linux ]; then
  echo "Linux package building requires a Linux release host" >&2
  exit 1
fi
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) echo "Linux package building requires an AMD64 release host" >&2; exit 1 ;;
esac
case "$TUYU_SERVE_URL" in
  https://*) ;;
  *) echo "TUYU_SERVE_URL must use HTTPS" >&2; exit 1 ;;
esac

for command_name in flutter cargo dpkg-deb readelf patchelf sha256sum; do
  command -v "$command_name" >/dev/null || {
    echo "missing release-host command: $command_name" >&2
    exit 1
  }
done

TUYU_POSTGRES_DEST="$RUNTIME" "$SCRIPT_DIR/build_runtime.sh"
(
  cd "$DESKTOP"
  flutter pub get --enforce-lockfile
  node "$ROOT/app/scripts/project.mjs" native --source-root "$ROOT/app" \
    --work-root "$WORK_DIR" --output "$DESKTOP" --platform linux-amd >/dev/null
  flutter test
  flutter build linux --release --target lib/main_host.dart \
    --dart-define="TUYU_SERVE_URL=$TUYU_SERVE_URL"
)
(
  cd "$ROOT"
  TUYU_POSTGRES_BIN="$RUNTIME/bin" cargo test --workspace --locked
  cargo build --release --locked --target x86_64-unknown-linux-gnu -p tuyubooking-native
)

mapfile -t bundles < <(find "$DESKTOP/build/linux" -type d -path '*/release/bundle' -print)
if [ "${#bundles[@]}" -ne 1 ]; then
  echo "expected one Flutter Linux release bundle, found ${#bundles[@]}" >&2
  exit 1
fi
bundle="${bundles[0]}"
native="$CARGO_TARGET_DIR/x86_64-unknown-linux-gnu/release/libtuyubooking_native.so"
test -f "$native" || { echo "missing Rust Linux library: $native" >&2; exit 1; }

version="${TUYU_BOOKING_VERSION:-$(awk '/^version:/ {print $2; exit}' "$DESKTOP/pubspec.yaml")}"
stage="$(mktemp -d -t tuyubooking-linux-package.XXXXXX)"
temporary_package="$WORK_DIR/TuyuBooking-LinuxAMD.deb.partial"
package="$WORK_DIR/TuyuBooking-LinuxAMD.deb"
trap 'find "$stage" -depth -delete 2>/dev/null || true; find "$temporary_package" -delete 2>/dev/null || true' EXIT

app="$stage/opt/tuyubooking"
mkdir -p "$app/lib" "$stage/DEBIAN" "$stage/usr/bin" \
  "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/256x256/apps"
cp -a "$bundle/." "$app/"
cp "$native" "$app/lib/libtuyubooking_native.so"
cp -a "$RUNTIME" "$app/postgresql"
"$ROOT/scripts/business-runtime/materialize.sh" "$BUSINESS_SOURCE" "$app/business"
cp "$SCRIPT_DIR/tuyubooking.desktop" "$stage/usr/share/applications/com.tuyulove.tuyubooking.host.desktop"
cp "$DESKTOP/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png" \
  "$stage/usr/share/icons/hicolor/256x256/apps/com.tuyulove.tuyubooking.host.png"
ln -s /opt/tuyubooking/tuyubooking "$stage/usr/bin/tuyubooking"
sed "s/@VERSION@/$version/g" "$SCRIPT_DIR/control.template" > "$stage/DEBIAN/control"

# Every packaged application ELF uses a location relative to itself. The
# PostgreSQL runtime already has its own verified RPATH and is left untouched.
while IFS= read -r elf_file; do
  case "$elf_file" in
    "$app/postgresql/"*|"$app/business/"*) continue ;;
    "$app/tuyubooking") runtime_path='$ORIGIN/lib' ;;
    "$app/lib/"*) runtime_path='$ORIGIN' ;;
    *) runtime_path='$ORIGIN' ;;
  esac
  patchelf --set-rpath "$runtime_path" "$elf_file"
done < <(find "$app" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do readelf -h "$candidate" >/dev/null 2>&1 && printf '%s\n' "$candidate"; done)
"$SCRIPT_DIR/verify_bundle.sh" "$stage"
dpkg-deb --build --root-owner-group "$stage" "$temporary_package"
dpkg-deb --field "$temporary_package" Architecture | grep -qx amd64
mv "$temporary_package" "$package"
hash="$(sha256sum "$package" | awk '{print $1}')"
printf '%s *%s\n' "$hash" "$(basename "$package")" > "$package.sha256"
echo "built TuyuBooking Linux AMD64 package: $package"
