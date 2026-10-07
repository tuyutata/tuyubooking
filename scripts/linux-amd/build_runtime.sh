#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCK="$SCRIPT_DIR/postgresql.runtime.lock.json"
# 所有独立入口的工具临时状态归本产品target；宿主已交付的产品工作根继续归当前任务。
PRODUCT_TEMP_SCRIPT="${BASH_SOURCE[0]}"
while [[ -L "$PRODUCT_TEMP_SCRIPT" ]]; do
  PRODUCT_TEMP_LINK="$(readlink "$PRODUCT_TEMP_SCRIPT")"
  [[ "$PRODUCT_TEMP_LINK" == /* ]] || PRODUCT_TEMP_LINK="$(cd "$(dirname "$PRODUCT_TEMP_SCRIPT")" && pwd -P)/$PRODUCT_TEMP_LINK"
  PRODUCT_TEMP_SCRIPT="$PRODUCT_TEMP_LINK"
done
PRODUCT_TEMP_SOURCE="$(cd "$(dirname "$PRODUCT_TEMP_SCRIPT")/../.." && pwd -P)"
PRODUCT_TARGET_TEMP_ROOT="$("${PRODUCT_NODE_BIN:-${NODE:-node}}" "$PRODUCT_TEMP_SOURCE/scripts/build.mjs" temporary-root "${PLATFORM:-${platform:-}}" 'host-linux-amd')" || exit 1
if [[ -z "${PRODUCT_WORK_DIR:-}" && "${TMPDIR:-}" != "$PRODUCT_TEMP_SOURCE/target/"* ]]; then
  export TMPDIR="$PRODUCT_TARGET_TEMP_ROOT/"
fi
DEST="${TUYU_POSTGRES_DEST:-${TUYUBOOKING_ARTIFACT_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/artifacts}/postgresql/linux-amd}"
DEPENDENCY_DIR="${TUYUBOOKING_DEPENDENCY_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/dependencies}"
BUILD_PARENT="${TUYUBOOKING_BUILD_DIR:-${TMPDIR:-$PRODUCT_TARGET_TEMP_ROOT}/tuyubooking/build}"

if [ "$(uname -s)" != Linux ]; then
  echo "Linux PostgreSQL scripts requires a Linux release host" >&2
  exit 1
fi
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) echo "Linux PostgreSQL scripts requires an AMD64 release host" >&2; exit 1 ;;
esac

for command_name in python3 node curl sha256sum tar make gcc readelf patchelf ldd dpkg-query; do
  command -v "$command_name" >/dev/null || {
    echo "missing release-host command: $command_name" >&2
    exit 1
  }
done

lock_values="$(python3 - "$LOCK" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    lock = json.load(source)
print("\t".join((lock["version"], lock["source_url"], lock["source_sha256"], lock["install_prefix"])))
PY
)"
IFS=$'\t' read -r version source_url source_sha install_prefix <<< "$lock_values"
case "$source_url" in
  https://*) ;;
  *) echo "PostgreSQL source URL must use HTTPS" >&2; exit 1 ;;
esac

mkdir -p "$DEPENDENCY_DIR/archives" "$BUILD_PARENT"
archive="${POSTGRES_SOURCE_ARCHIVE:-$DEPENDENCY_DIR/archives/postgresql-$version.tar.bz2}"
if [ ! -f "$archive" ]; then
  pending="$archive.pending.$$"
  for attempt in 1 2 3; do
    rm -f -- "$pending"
    if curl --fail --location --silent --show-error --output "$pending" "$source_url" \
      && printf '%s  %s\n' "$source_sha" "$pending" | sha256sum --check --status -; then
      mv "$pending" "$archive"; break
    fi
  done
  rm -f -- "$pending"
fi
test -f "$archive" && test ! -L "$archive" || { echo 'PostgreSQL原件不存在或是符号链接' >&2; exit 1; }
printf '%s  %s\n' "$source_sha" "$archive" | sha256sum --check --status - || {
  echo "PostgreSQL source checksum mismatch" >&2
  exit 1
}

work="$(mktemp -d "$BUILD_PARENT/postgresql-linux-amd.XXXXXX")"
trap 'find "$work" -depth -delete 2>/dev/null || true' EXIT
tar -xjf "$archive" -C "$work"
source_root="$work/postgresql-$version"
build_root="$work/build"
install_root="$work/install"
mkdir -p "$build_root" "$install_root"

(
  cd "$build_root"
  "$source_root/configure" --prefix="$install_prefix" --without-readline
  make -j "${BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN)}"
  make DESTDIR="$install_root" install
)

installed="$install_root$install_prefix"
mkdir -p "$DEST/bin" "$DEST/lib" "$DEST/share" "$DEST/licenses"
find "$DEST/bin" "$DEST/lib" "$DEST/share" "$DEST/licenses" -mindepth 1 -delete
cp -a "$installed/bin/." "$DEST/bin/"
cp -a "$installed/lib/." "$DEST/lib/"
cp -a "$installed/share/." "$DEST/share/"
cp "$source_root/COPYRIGHT" "$DEST/licenses/PostgreSQL-COPYRIGHT"

is_elf() {
  readelf -h "$1" >/dev/null 2>&1
}

is_system_runtime() {
  case "$(basename "$1")" in
    ld-linux-x86-64.so.*|libc.so.*|libdl.so.*|libm.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|libutil.so.*) return 0 ;;
    *) return 1 ;;
  esac
}

component_file="$work/components.txt"
: > "$component_file"
while :; do
  added=0
  while IFS= read -r elf_file; do
    while IFS= read -r dependency; do
      [ -n "$dependency" ] || continue
      is_system_runtime "$dependency" && continue
      resolved="$(readlink -f "$dependency")"
      destination="$DEST/lib/$(basename "$resolved")"
      if [ ! -f "$destination" ]; then
        cp "$resolved" "$destination"
        chmod u+w "$destination"
        added=1
      fi
      dependency_name="$(basename "$dependency")"
      if [ "$dependency_name" != "$(basename "$resolved")" ] && [ ! -e "$DEST/lib/$dependency_name" ]; then
        ln -s "$(basename "$resolved")" "$DEST/lib/$dependency_name"
        added=1
      fi
      package_spec="$(dpkg-query -S "$dependency" 2>/dev/null | head -1 | cut -d: -f1 || true)"
      if [ -z "$package_spec" ]; then
        echo "cannot identify Debian package for bundled dependency: $dependency" >&2
        exit 1
      fi
      package_version="$(dpkg-query -W -f='${Version}' "$package_spec")"
      [ -n "$package_version" ] || {
        echo "cannot identify package version for bundled dependency: $package_spec" >&2
        exit 1
      }
      copyright_source="/usr/share/doc/$package_spec/copyright"
      [ -f "$copyright_source" ] || {
        echo "missing Debian copyright file for bundled dependency: $package_spec" >&2
        exit 1
      }
      printf '%s\t%s\n' "$package_spec" "$package_version" >> "$component_file"
      mkdir -p "$DEST/licenses/$package_spec"
      cp "$copyright_source" "$DEST/licenses/$package_spec/copyright"
    done < <(ldd "$elf_file" | awk '/=> \// {print $3} /^\// {print $1}')
  done < <(find "$DEST/bin" "$DEST/lib" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do is_elf "$candidate" && printf '%s\n' "$candidate"; done)
  [ "$added" -eq 1 ] || break
done

while IFS= read -r elf_file; do
  case "$elf_file" in
    "$DEST/bin/"*) runtime_path='$ORIGIN/../lib' ;;
    "$DEST/lib/postgresql/"*) runtime_path='$ORIGIN/..:$ORIGIN' ;;
    "$DEST/lib/"*) runtime_path='$ORIGIN' ;;
    *) echo "unsupported Linux ELF location: $elf_file" >&2; exit 1 ;;
  esac
  patchelf --set-rpath "$runtime_path" "$elf_file"
  readelf -h "$elf_file" | grep -q 'Machine:.*X86-64' || {
    echo "non-X86-64 ELF in runtime: $elf_file" >&2
    exit 1
  }
done < <(find "$DEST/bin" "$DEST/lib" -type f -print | LC_ALL=C sort | while IFS= read -r candidate; do is_elf "$candidate" && printf '%s\n' "$candidate"; done)

{
  printf 'postgresql\t%s\n' "$version"
  LC_ALL=C sort -u "$component_file"
} > "$DEST/THIRD_PARTY_COMPONENTS.txt"

"$DEST/bin/postgres" --version | grep -F 'PostgreSQL) 17.11' >/dev/null
(
  cd "$DEST"
  find . -type f ! -name MANIFEST.sha256 -print | LC_ALL=C sort |
    while IFS= read -r file_path; do sha256sum "$file_path"; done > MANIFEST.sha256
)
echo "packaged PostgreSQL Linux AMD64 runtime: $DEST"
