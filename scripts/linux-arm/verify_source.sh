#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

for required in \
  "$ROOT/app/linux/CMakeLists.txt" \
  "$ROOT/app/linux/runner/my_application.cc" \
  "$SCRIPT_DIR/build_runtime.sh" \
  "$SCRIPT_DIR/build_package.sh" \
  "$SCRIPT_DIR/verify_bundle.sh" \
  "$SCRIPT_DIR/postgresql.runtime.lock.json" \
  "$SCRIPT_DIR/control.template" \
  "$SCRIPT_DIR/../tuyubooking.desktop"; do
  test -f "$required" || { echo "missing Linux source contract: $required" >&2; exit 1; }
done

python3 - "$SCRIPT_DIR/postgresql.runtime.lock.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    lock = json.load(source)
assert lock["version"] == "17.11"
assert lock["architecture"] == "linux-arm"
assert lock["source_url"].startswith("https://")
assert lock["source_sha256"] == "dd27f2b3c59e73ed14aa3324901242bf69a032a6347805f274e6260322d42979"
PY

plain_http_pattern='http:'"//"
if grep -R -I -n "$plain_http_pattern" "$SCRIPT_DIR" "$ROOT/app/linux"; then
  echo "plain HTTP is prohibited in the Linux source contract" >&2
  exit 1
fi
grep -q 'aarch64-unknown-linux-gnu' "$SCRIPT_DIR/build_package.sh"
grep -q '^Architecture: arm64$' "$SCRIPT_DIR/control.template"
grep -q '\$ORIGIN/lib' "$ROOT/app/linux/CMakeLists.txt"
echo "verified TuyuBooking Linux ARM64 source contract"
