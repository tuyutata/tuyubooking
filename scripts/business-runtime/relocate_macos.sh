#!/bin/bash
set -euo pipefail

ROOT_INPUT="${1:?usage: relocate_macos.sh BUSINESS_RUNTIME [BUILD_SOURCE]}"
ROOT_INPUT="${ROOT_INPUT%/}"
SOURCE_INPUT="${2:-$ROOT_INPUT}"
SOURCE_INPUT="${SOURCE_INPUT%/}"
ROOT="$(cd "$ROOT_INPUT" && pwd -P)"
if [ -d "$SOURCE_INPUT" ]; then
  SOURCE_ROOT="$(cd "$SOURCE_INPUT" && pwd -P)"
else
  # A completed Release may be diagnosed after its temporary source is gone.
  SOURCE_ROOT="$SOURCE_INPUT"
fi
LIB="$ROOT/lib"
HOST_PYTHON="$(command -v python3)"
mkdir -p "$LIB"

candidates() {
  find "$ROOT" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' -o -name '*.node' \) -print | LC_ALL=C sort
}

is_macho() { file -b "$1" | grep -q 'Mach-O'; }
canonical_path() {
  if [ -e "$1" ]; then
    (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")")
  else
    printf '%s\n' "$1"
  fi
}
is_system() {
  case "$1" in
    /System/Library/*|/usr/lib/*) return 0 ;;
    *) return 1 ;;
  esac
}
is_internal() {
  local dependency canonical
  dependency="$1"
  case "$dependency" in
    "$ROOT"/*|"$ROOT_INPUT"/*|"$SOURCE_ROOT"/*) return 0 ;;
  esac
  canonical="$(canonical_path "$dependency")"
  case "$canonical" in
    "$ROOT"/*|"$SOURCE_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}
is_external() {
  is_internal "$1" && return 1
  is_system "$1" && return 1
  case "$1" in
    /*) return 0 ;;
    *) return 1 ;;
  esac
}

while :; do
  copied=0
  while IFS= read -r binary; do
    is_macho "$binary" || continue
    dylib_id="$(otool -D "$binary" 2>/dev/null | sed -n '2p' || true)"
    while IFS= read -r dependency; do
      [ -n "$dylib_id" ] && [ "$dependency" = "$dylib_id" ] && continue
      is_internal "$dependency" && continue
      is_external "$dependency" || continue
      test -f "$dependency" || { echo "missing dylib: $dependency" >&2; exit 1; }
      destination="$LIB/$(basename "$dependency")"
      if [ ! -f "$destination" ]; then
        cp -L "$dependency" "$destination"
        chmod u+w "$destination"
        copied=$((copied + 1))
      elif ! cmp -s "$dependency" "$destination"; then
        echo "dylib basename collision: $dependency" >&2
        exit 1
      fi
    done < <(otool -L "$binary" | awk '/^[[:space:]]/{print $1}')
    while IFS= read -r dependency; do
      [ -n "$dylib_id" ] && [ "$dependency" = "$dylib_id" ] && continue
      case "$dependency" in
        @loader_path/*)
          local_candidate="$(dirname "$binary")/${dependency#@loader_path/}"
          ;;
        @rpath/*)
          local_candidate="$LIB/$(basename "$dependency")"
          ;;
        *) continue ;;
      esac
      [ -e "$local_candidate" ] && continue
      name="$(basename "$dependency")"
      source_candidate="$(find -L /opt/homebrew/opt -name "$name" -print -quit 2>/dev/null || true)"
      [ -n "$source_candidate" ] || continue
      destination="$LIB/$name"
      if [ ! -f "$destination" ]; then
        cp -L "$source_candidate" "$destination"
        chmod u+w "$destination"
        copied=$((copied + 1))
      fi
    done < <(otool -L "$binary" | awk '/^[[:space:]]/{print $1}')
  done < <(candidates)
  [ "$copied" -gt 0 ] || break
done

while IFS= read -r binary; do
  is_macho "$binary" || continue
  chmod u+w "$binary"
  dylib_id="$(otool -D "$binary" 2>/dev/null | sed -n '2p' || true)"
  relative="$($HOST_PYTHON -c 'import os,sys; print(os.path.relpath(sys.argv[2], os.path.dirname(sys.argv[1])))' "$binary" "$LIB")"
  while IFS= read -r dependency; do
    if [ -n "$dylib_id" ] && [ "$dependency" = "$dylib_id" ]; then
      # Wheel extension modules may use a module-qualified @rpath LC_ID_DYLIB.
      install_name_tool -id "@loader_path/$(basename "$binary")" "$binary"
      continue
    fi
    case "$dependency" in
      @loader_path/*)
        local_candidate="$(dirname "$binary")/${dependency#@loader_path/}"
        [ -e "$local_candidate" ] && continue
        ;;
      @rpath/*) ;;
      *) local_candidate="" ;;
    esac
    case "$dependency" in
      @loader_path/*|@rpath/*)
        target="$LIB/$(basename "$dependency")"
        [ -f "$target" ] || { echo "missing relative dylib: $dependency" >&2; exit 1; }
        install_name_tool -change "$dependency" "@loader_path/$relative/$(basename "$dependency")" "$binary"
        continue
        ;;
    esac
    if is_external "$dependency"; then
      install_name_tool -change "$dependency" "@loader_path/$relative/$(basename "$dependency")" "$binary"
    elif is_internal "$dependency"; then
      canonical_dependency="$(canonical_path "$dependency")"
      case "$canonical_dependency" in
        "$ROOT"/*) target="$canonical_dependency" ;;
        "$ROOT_INPUT"/*) target="$ROOT/${canonical_dependency#"$ROOT_INPUT"/}" ;;
        "$SOURCE_ROOT"/*) target="$ROOT/${canonical_dependency#"$SOURCE_ROOT"/}" ;;
        *) echo "cannot map internal dependency: $dependency" >&2; exit 1 ;;
      esac
      target="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
      if [ "$target" = "$binary" ]; then
        install_name_tool -id "@loader_path/$(basename "$binary")" "$binary"
      else
        target_relative="$($HOST_PYTHON -c 'import os,sys; print(os.path.relpath(sys.argv[2], os.path.dirname(sys.argv[1])))' "$binary" "$target")"
        install_name_tool -change "$dependency" "@loader_path/$target_relative" "$binary"
      fi
    fi
  done < <(otool -L "$binary" | awk '/^[[:space:]]/{print $1}')
  while IFS= read -r runpath; do
    is_external "$runpath" || continue
    install_name_tool -delete_rpath "$runpath" "$binary" 2>/dev/null || true
  done < <(otool -l "$binary" | awk '/cmd LC_RPATH/{getline; getline; print $2}')
  # Every packaged dylib needs a bundle-relative install ID, including dylibs
  # kept in component-owned directories such as openssl/lib.
  case "$binary" in *.dylib) install_name_tool -id "@loader_path/$(basename "$binary")" "$binary" ;; esac
  codesign --force --sign - --timestamp=none "$binary" >/dev/null
done < <(candidates)

while IFS= read -r binary; do
  is_macho "$binary" || continue
  while IFS= read -r dependency; do
    case "$dependency" in
      @rpath/*)
        echo "unrelocated dependency: $binary -> $dependency" >&2
        exit 1
        ;;
      /*)
        if ! is_system "$dependency"; then
          echo "unrelocated absolute dependency: $binary -> $dependency" >&2
          exit 1
        fi
        ;;
    esac
  done < <(otool -L "$binary" | awk '/^[[:space:]]/{print $1}')
done < <(candidates)

echo "relocated macOS business runtime: $ROOT"
