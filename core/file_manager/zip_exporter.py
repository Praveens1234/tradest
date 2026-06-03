"""Folder zip export: PowerShell Compress-Archive with zipfile fallback."""
import os
import io
import zipfile
import tempfile
import pathlib
import logging
from core.file_manager.pwsh_runner import pwsh_available, run_pwsh
from core.file_manager.fs_navigator import _safe_resolve
from config import settings

logger = logging.getLogger(__name__)


def zip_folder(path: str) -> bytes:
    root = settings.mql5_root or settings.workspace_dir or "workspace"
    target = _safe_resolve(path, root)

    if not target.exists():
        raise FileNotFoundError(f"Path not found: {path!r}")

    if pwsh_available():
        return _zip_with_pwsh(target)
    return _zip_with_zipfile(target)


def _zip_with_pwsh(target: pathlib.Path) -> bytes:
    with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp:
        tmp_path = tmp.name

    script = f'Compress-Archive -Path "{target}" -DestinationPath "{tmp_path}" -Force'
    result = run_pwsh(script, timeout=60)

    if result["code"] != 0:
        logger.warning("pwsh zip failed: %s — falling back to zipfile", result["stderr"])
        os.unlink(tmp_path)
        return _zip_with_zipfile(target)

    try:
        data = pathlib.Path(tmp_path).read_bytes()
    finally:
        os.unlink(tmp_path)
    return data


def _zip_with_zipfile(target: pathlib.Path) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        if target.is_file():
            zf.write(target, target.name)
        else:
            for item in target.rglob("*"):
                if item.is_file():
                    arcname = item.relative_to(target.parent)
                    zf.write(item, arcname)
    buf.seek(0)
    return buf.read()
