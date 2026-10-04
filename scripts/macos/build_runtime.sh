#!/bin/bash
# macOS PostgreSQL入口只调用所属产品的受控源码编译器；缺少输入直接失败。
set -euo pipefail
[[ $# -eq 0 && "${NODE:?缺少已交付Node}" == /* && -x "$NODE" ]] || { echo "PostgreSQL编译入口无效" >&2; exit 2; }
exec "$NODE" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/postgres-runtime.mjs"
