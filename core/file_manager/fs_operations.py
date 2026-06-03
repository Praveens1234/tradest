"""File system CRUD, copy, move, rename, delete, trash operations."""
import json
import os
import shutil
import pathlib
import logging
from config import settings
from core.file_manager.fs_navigator import _safe_resolve
from core.file_manager.conflict_resolver import check_conflict, ConflictInfo

logger = logging.getLogger(__name__)


def _root() -> str:
    return settings.mql5_root or settings.workspace_dir or "workspace"


def _trash_dir() -> pathlib.Path:
    trash = pathlib.Path(_root()) / "_trash"
    trash.mkdir(parents=True, exist_ok=True)
    return trash


def read_file(path: str) -> str:
    target = _safe_resolve(path, _root())
    return target.read_text(encoding="utf-8", errors="replace")


def write_file(path: str, content: str, override: bool = False, new_name: str = "") -> str:
    root = _root()
    target = _safe_resolve(path, root)
    if new_name:
        target = target.parent / new_name
    if not override:
        conflict = check_conflict(str(target))
        if conflict:
            raise FileExistsError(json.dumps(conflict.__dict__))
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    return str(target.relative_to(pathlib.Path(root).resolve())).replace("\\", "/")


def create_dir(path: str) -> str:
    target = _safe_resolve(path, _root())
    target.mkdir(parents=True, exist_ok=True)
    root_p = pathlib.Path(_root()).resolve()
    return str(target.relative_to(root_p)).replace("\\", "/")


def rename(path: str, new_name: str, override: bool = False) -> str:
    root = _root()
    target = _safe_resolve(path, root)
    dest = target.parent / new_name
    if not override:
        conflict = check_conflict(str(dest))
        if conflict:
            raise FileExistsError(json.dumps(conflict.__dict__))
    target.rename(dest)
    root_p = pathlib.Path(root).resolve()
    return str(dest.relative_to(root_p)).replace("\\", "/")


def copy(source: str, destination: str, override: bool = False) -> str:
    root = _root()
    src = _safe_resolve(source, root)
    dst = _safe_resolve(destination, root)
    if not override:
        conflict = check_conflict(str(dst))
        if conflict:
            raise FileExistsError(json.dumps(conflict.__dict__))
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        shutil.copytree(str(src), str(dst), dirs_exist_ok=override)
    else:
        shutil.copy2(str(src), str(dst))
    root_p = pathlib.Path(root).resolve()
    return str(dst.relative_to(root_p)).replace("\\", "/")


def move(source: str, destination: str, override: bool = False) -> str:
    root = _root()
    src = _safe_resolve(source, root)
    dst = _safe_resolve(destination, root)
    if not override and dst.exists():
        conflict = check_conflict(str(dst))
        if conflict:
            raise FileExistsError(json.dumps(conflict.__dict__))
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dst))
    root_p = pathlib.Path(root).resolve()
    return str(dst.relative_to(root_p)).replace("\\", "/")


def delete(path: str, soft: bool = True) -> str:
    target = _safe_resolve(path, _root())
    if soft:
        trash = _trash_dir()
        dest = trash / target.name
        # Avoid collision in trash
        counter = 1
        while dest.exists():
            dest = trash / f"{target.stem}_{counter}{target.suffix}"
            counter += 1
        shutil.move(str(target), str(dest))
        return f"Moved to trash: {dest.name}"
    else:
        if target.is_dir():
            shutil.rmtree(str(target))
        else:
            target.unlink()
        return f"Deleted: {path}"


def get_meta(path: str) -> dict:
    target = _safe_resolve(path, _root())
    stat = target.stat()
    import datetime
    return {
        "name": target.name,
        "path": path,
        "is_dir": target.is_dir(),
        "size_bytes": stat.st_size,
        "created_at": datetime.datetime.utcfromtimestamp(stat.st_ctime).isoformat() + "Z",
        "modified_at": datetime.datetime.utcfromtimestamp(stat.st_mtime).isoformat() + "Z",
        "extension": target.suffix.lstrip("."),
    }
