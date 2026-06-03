"""Conflict detection and suggested rename generation."""
import os
import pathlib
from dataclasses import dataclass
from datetime import datetime


@dataclass
class ConflictInfo:
    conflict: bool
    existing_path: str
    modified_at: str
    size_bytes: int
    suggested_name: str


def check_conflict(dest_path: str) -> ConflictInfo | None:
    """Return ConflictInfo if dest_path already exists, else None."""
    p = pathlib.Path(dest_path)
    if not p.exists():
        return None

    stat = p.stat()
    modified_at = datetime.utcfromtimestamp(stat.st_mtime).isoformat() + "Z"
    size_bytes = stat.st_size

    # Generate suggested_name: append _1, _2, ... until unique
    stem = p.stem
    suffix = p.suffix
    parent = p.parent
    counter = 1
    while True:
        candidate = parent / f"{stem}_{counter}{suffix}"
        if not candidate.exists():
            suggested_name = candidate.name
            break
        counter += 1

    return ConflictInfo(
        conflict=True,
        existing_path=str(p),
        modified_at=modified_at,
        size_bytes=size_bytes,
        suggested_name=suggested_name,
    )
