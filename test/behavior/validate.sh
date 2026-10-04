#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"

jq -e '
  .schema_version == 3 and
  .dependency_mode == "git_subtree" and
  (.sources | length) == 7 and
  ([.sources[].repository] | sort) == ([
    "https://github.com/tuyutata/Hi.Events",
    "https://github.com/tuyutata/erpnext",
    "https://github.com/tuyutata/frappe",
    "https://github.com/tuyutata/hrms",
    "https://github.com/tuyutata/kamra-pms",
    "https://github.com/tuyutata/ury",
    "https://github.com/tuyutata/voyant"
  ] | sort) and
  all(.sources[];
    (.commit | length) == 40 and
    (has("archive_sha256") | not) and
    (has("tree_sha256") | not) and
    (has("file_count") | not) and
    (.upstream_repository | startswith("https://github.com/")))
' tuyubooking.sources.json >/dev/null

for domain in hotel restaurant tour ticket; do
  for doc in BEHAVIOR.md FEATURES.md INTEGRATION.md TRACEABILITY.md; do
    test -s "specifications/behavior/$domain/$doc"
  done
  jq -e '.schema_version == 1 and (.scenarios | type == "array" and length > 0) and all(.scenarios[]; has("id") and has("given") and has("when") and has("then"))' "specifications/fixtures/$domain.json" >/dev/null
done

test -s host/database/SCHEMA_BASELINE.md
test ! -e runtime/lab
test ! -e specifications/behavior/runtime-bootstrap.log
test ! -e specifications/behavior/RUNTIME_BASELINE.md

plain_http=$(printf 'http:\057\057')
# 校验当前目录，并区分“未匹配”与“读取失败”，禁止缺失来源被误报为通过。
if rg -n -F "$plain_http" specifications/behavior specifications/fixtures host/database/SCHEMA_BASELINE.md test/behavior tuyubooking.sources.json >/dev/null; then
  echo "明文 HTTP 检查失败" >&2
  exit 1
else
  scan_status=$?
  if [ "$scan_status" -ne 1 ]; then
    echo "来源合同扫描失败" >&2
    exit "$scan_status"
  fi
fi
echo "TuyuBooking source integration baseline: PASS"
