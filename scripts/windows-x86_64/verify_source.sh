#!/usr/bin/env bash
# Windows发行件只从锁定官方原件物化；此入口验证显式源码外目录，不寻找产品树或LLVM副本。
set -euo pipefail
[[ $# -eq 1 ]] || { echo '需要准确PostgreSQL运行时目录' >&2; exit 2; }
NODE="${TUYUBOOKING_NODE_BIN:?缺少调用方验真的Node}"
[[ "$NODE" == /* && -f "$NODE" && -x "$NODE" ]] || { echo 'Node必须是验真的绝对可执行文件' >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec "$NODE" "$SCRIPT_DIR/verify-source.mjs" "$1"
