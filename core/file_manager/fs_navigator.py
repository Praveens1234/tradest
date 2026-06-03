"""Directory tree navigation and file search."""
import os
import pathlib
from dataclasses import dataclass, field
from typing import Optional
from config import settings


def _safe_resolve(path: str, root: str) -> pathlib.Path:
    """Resolve path under root; raise ValueError on traversal attempt."""
    root_p = pathlib.Path(root).resolve()
    resolved = (root_p / path).resolve()
    try:
        resolved.relative_to(root_p)
    except ValueError:
        raise ValueError(f"Path traversal attempt: {path!r}")
    return resolved


@dataclass
class FileNode:
    name: str
    path: str          # relative to workspace root
    is_dir: bool
    extension: str
    size: int = 0
    children: Optional[list] = field(default=None)


def _node_from_path(abs_path: pathlib.Path, root: pathlib.Path, depth: int, max_depth: int) -> FileNode:
    rel = abs_path.relative_to(root)
    is_dir = abs_path.is_dir()
    size = abs_path.stat().st_size if not is_dir else 0
    ext = abs_path.suffix.lstrip(".") if not is_dir else ""
    node = FileNode(
        name=abs_path.name,
        path=str(rel).replace("\\", "/"),
        is_dir=is_dir,
        extension=ext,
        size=size,
    )
    if is_dir and depth < max_depth:
        try:
            children = sorted(
                abs_path.iterdir(),
                key=lambda p: (not p.is_dir(), p.name.lower()),
            )
            node.children = [_node_from_path(c, root, depth + 1, max_depth) for c in children]
        except PermissionError:
            node.children = []
    return node


def get_tree(path: str = "", max_depth: int = 8) -> FileNode:
    root = settings.mql5_root or settings.workspace_dir
    if not root:
        root = "workspace"
    root_p = pathlib.Path(root)
    root_p.mkdir(parents=True, exist_ok=True)

    target = _safe_resolve(path, root)
    return _node_from_path(target, root_p.resolve(), 0, max_depth)


def list_dir(path: str) -> list[FileNode]:
    root = settings.mql5_root or settings.workspace_dir or "workspace"
    target = _safe_resolve(path, root)
    root_p = pathlib.Path(root).resolve()
    if not target.is_dir():
        raise NotADirectoryError(f"Not a directory: {path!r}")
    items = sorted(target.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower()))
    return [_node_from_path(item, root_p, 0, 0) for item in items]


def search(query: str, path: str = "") -> list[FileNode]:
    root = settings.mql5_root or settings.workspace_dir or "workspace"
    root_p = pathlib.Path(root).resolve()
    target = _safe_resolve(path, root)
    query_lower = query.lower()
    results: list[FileNode] = []

    for item in target.rglob("*"):
        if not item.is_file():
            continue
        # Name match
        if query_lower in item.name.lower():
            results.append(_node_from_path(item, root_p, 0, 0))
            continue
        # Content match (text files only)
        if item.suffix.lower() in (".mq5", ".mqh", ".txt", ".log", ".csv", ".ini"):
            try:
                text = item.read_text(encoding="utf-8", errors="ignore")
                if query_lower in text.lower():
                    results.append(_node_from_path(item, root_p, 0, 0))
            except OSError:
                pass

    return results
