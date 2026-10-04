#!/usr/bin/env python3
"""Cold-start the packaged host/runtime boundary without a user login."""

from __future__ import annotations

import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PACKAGED_SMOKE_TIMEOUT_SECONDS = 900
SENSITIVE_LOG_MARKERS = (
    "--db-password",
    "--db-root-password",
    "--admin-password",
)


def print_runtime_logs(root: Path) -> None:
    for log in sorted((root / "logs").rglob("*.log")):
        print(f"===== {log} =====", file=sys.stderr)
        print(log.read_text(errors="replace")[-12000:], file=sys.stderr)


def assert_runtime_logs_are_redacted(root: Path) -> None:
    """Fail Release if a child traceback copies credential arguments to disk."""
    for log in sorted((root / "logs").rglob("*.log")):
        content = log.read_text(errors="replace")
        leaked = next(
            (marker for marker in SENSITIVE_LOG_MARKERS if marker in content),
            None,
        )
        if leaked is not None:
            raise RuntimeError(
                f"sensitive provisioning argument {leaked} leaked into "
                f"{log.relative_to(root)}"
            )


def bundle_identity(app: Path) -> tuple[Path, str]:
    """以安装包自身元数据为准，避免主机、分机改名后验收仍使用旧名称。"""
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    if not isinstance(info, dict):
        raise RuntimeError("Info.plist must contain a dictionary")
    executable_name = info.get("CFBundleExecutable")
    bundle_id = info.get("CFBundleIdentifier")
    # 名称可以包含空格，但不能把启动路径或临时目录指向安装包之外。
    if (
        not isinstance(executable_name, str)
        or executable_name in ("", ".", "..")
        or Path(executable_name).name != executable_name
        or "\x00" in executable_name
    ):
        raise RuntimeError("Info.plist has an invalid CFBundleExecutable")
    if not isinstance(bundle_id, str) or not re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9.-]*", bundle_id
    ):
        raise RuntimeError("Info.plist has an invalid CFBundleIdentifier")
    executable = app / "Contents/MacOS" / executable_name
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise RuntimeError(f"CFBundleExecutable is missing or not executable: {executable}")
    return executable, bundle_id


def main() -> int:
    app = Path(sys.argv[1]).resolve()
    executable, bundle_id = bundle_identity(app)
    container_tmp = (
        Path.home() / "Library/Containers" / bundle_id / "Data/tmp"
    )
    container_tmp.mkdir(parents=True, exist_ok=True)
    temporary = Path(
        # A deliberate space keeps Release validation equivalent to macOS's
        # standard "Application Support" path used by the installed app.
        tempfile.mkdtemp(prefix="tuyubooking cold start-", dir=container_tmp)
    )
    result_file = temporary / "result.json"
    environment = {
        **os.environ,
        "TUYU_PACKAGED_SMOKE": "1",
        "TUYU_PACKAGED_SMOKE_ROOT": str(temporary),
        "TUYU_PACKAGED_SMOKE_RESULT": str(result_file),
    }
    try:
        try:
            completed = subprocess.run(
                [str(executable)],
                check=False,
                capture_output=True,
                text=True,
                timeout=PACKAGED_SMOKE_TIMEOUT_SECONDS,
                env=environment,
            )
        except subprocess.TimeoutExpired as error:
            print(error.stdout or "", file=sys.stderr)
            print(error.stderr or "", file=sys.stderr)
            print_runtime_logs(temporary)
            raise RuntimeError(
                "signed app smoke exceeded "
                f"{PACKAGED_SMOKE_TIMEOUT_SECONDS} seconds"
            ) from error
        if not result_file.is_file():
            print(completed.stdout, file=sys.stderr)
            print(completed.stderr, file=sys.stderr)
            print_runtime_logs(temporary)
            raise RuntimeError(
                f"signed app smoke exited {completed.returncode} without a result"
            )
        result = json.loads(result_file.read_text())
        if completed.returncode != 0 or result.get("ok") is not True:
            print(completed.stdout, file=sys.stderr)
            print(completed.stderr, file=sys.stderr)
            print_runtime_logs(temporary)
            raise RuntimeError(json.dumps(result, ensure_ascii=False))
        assert_runtime_logs_are_redacted(temporary)
    finally:
        shutil.rmtree(temporary, ignore_errors=True)
    print("verified TuyuBooking packaged cold start, HTTPS, restart and persistence")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
