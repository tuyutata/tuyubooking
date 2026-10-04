#!/usr/bin/env python3
"""Write a deterministic shasum-compatible manifest without per-file forks."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import sys
import tempfile


def digest(path: Path) -> str:
    checksum = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: write_sha256_manifest.py ROOT OUTPUT")

    root = Path(sys.argv[1]).resolve(strict=True)
    output = Path(sys.argv[2]).resolve()
    files = sorted(
        (
            path
            for path in root.rglob("*")
            if path.is_file() and path.resolve() != output
        ),
        key=lambda path: path.relative_to(root).as_posix().encode("utf-8"),
    )

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output.name}.", dir=output.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as target:
            for path in files:
                relative = path.relative_to(root).as_posix()
                target.write(f"{digest(path)}  ./{relative}\n")
        os.replace(temporary_name, output)
    except BaseException:
        os.unlink(temporary_name)
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
