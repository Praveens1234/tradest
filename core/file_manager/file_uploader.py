"""File upload handling with conflict detection and WebSocket progress events."""
import pathlib
import asyncio
import logging
from dataclasses import dataclass
from config import settings
from core.file_manager.fs_navigator import _safe_resolve
from core.file_manager.conflict_resolver import check_conflict, ConflictInfo

logger = logging.getLogger(__name__)


@dataclass
class UploadResult:
    filename: str
    path: str
    size_bytes: int
    conflict: ConflictInfo | None = None


async def upload_file(
    dest_dir: str,
    filename: str,
    content: bytes,
    override: bool = False,
    new_name: str = "",
    ws_queue: asyncio.Queue | None = None,
) -> UploadResult:
    root = settings.mql5_root or settings.workspace_dir or "workspace"
    dir_path = _safe_resolve(dest_dir, root)
    dir_path.mkdir(parents=True, exist_ok=True)

    effective_name = new_name if new_name else filename
    dest = dir_path / effective_name

    if not override:
        conflict = check_conflict(str(dest))
        if conflict:
            return UploadResult(filename=filename, path="", size_bytes=0, conflict=conflict)

    if ws_queue:
        await ws_queue.put({"filename": effective_name, "percent": 0})

    dest.write_bytes(content)

    if ws_queue:
        await ws_queue.put({"filename": effective_name, "percent": 100})

    root_p = pathlib.Path(root).resolve()
    rel_path = str(dest.resolve().relative_to(root_p)).replace("\\", "/")

    return UploadResult(filename=effective_name, path=rel_path, size_bytes=len(content))
