from __future__ import annotations

import stat
from pathlib import Path


NON_EXECUTABLE_FILE_MODE = 0o644
EXECUTABLE_FILE_MODE = 0o755


def file_mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def normalized_file_mode(path: Path) -> int:
    if file_mode(path) & 0o111:
        return EXECUTABLE_FILE_MODE
    return NON_EXECUTABLE_FILE_MODE
