"""MetaEditor64.exe CLI compiler with UTF-16-LE log parser."""
import re
import json
import pathlib
import asyncio
import subprocess
import logging
from dataclasses import dataclass, field, asdict
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.models import EAFile, CompileLog
from config import settings

logger = logging.getLogger(__name__)

LOG_RE = re.compile(
    r"^(?P<file>.+?)\((?P<line>\d+),(?P<col>\d+)\)\s*:\s*"
    r"(?P<level>error|warning|information)\s*:\s*(?P<message>.+)$",
    re.IGNORECASE,
)


@dataclass
class LogEntry:
    file: str
    line: int
    col: int
    message: str


@dataclass
class CompileResult:
    ea_id: int
    status: str  # success, warning, error
    errors: list[LogEntry] = field(default_factory=list)
    warnings: list[LogEntry] = field(default_factory=list)
    raw_log: str = ""
    compiled_at: str = ""


def _parse_log(raw: str) -> tuple[list[LogEntry], list[LogEntry]]:
    errors: list[LogEntry] = []
    warnings: list[LogEntry] = []
    for line in raw.splitlines():
        m = LOG_RE.match(line.strip())
        if not m:
            continue
        entry = LogEntry(
            file=m.group("file"),
            line=int(m.group("line")),
            col=int(m.group("col")),
            message=m.group("message").strip(),
        )
        level = m.group("level").lower()
        if level == "error":
            errors.append(entry)
        elif level == "warning":
            warnings.append(entry)
    return errors, warnings


def _read_log_file(log_path: pathlib.Path) -> str:
    """Read MetaEditor log file; tries UTF-16-LE first, falls back to UTF-8."""
    if not log_path.exists():
        return ""
    for enc in ("utf-16-le", "utf-8-sig", "utf-8", "latin-1"):
        try:
            return log_path.read_text(encoding=enc, errors="strict")
        except (UnicodeDecodeError, UnicodeError):
            continue
    return log_path.read_text(encoding="utf-8", errors="replace")


async def compile_ea(
    db: AsyncSession,
    ea_id: int,
    ws_queue: asyncio.Queue | None = None,
) -> CompileResult:
    stmt = select(EAFile).where(EAFile.id == ea_id)
    ea = (await db.execute(stmt)).scalar_one_or_none()
    if not ea:
        raise ValueError(f"EA #{ea_id} not found")

    root = settings.mql5_root or settings.workspace_dir or "workspace"
    ea_abs = pathlib.Path(root) / ea.path
    if not ea_abs.exists():
        raise FileNotFoundError(f"EA file not found at: {ea_abs}")

    errors: list[LogEntry] = []
    warnings: list[LogEntry] = []
    raw = ""
    status = "error"

    if not settings.metaeditor_path:
        raw = "MetaEditor path not configured. Set METAEDITOR_PATH in .env."
        logger.warning("Compile skipped — METAEDITOR_PATH not set")
    else:
        compile_failed = False
        log_path = ea_abs.with_suffix(".log")

        # Remove stale log file so we can detect a fresh one
        if log_path.exists():
            try:
                log_path.unlink()
            except OSError:
                pass

        try:
            subprocess.run(
                [settings.metaeditor_path, f"/compile:{ea_abs}", "/log"],
                timeout=120,
                capture_output=True,
            )
        except subprocess.TimeoutExpired:
            logger.error("MetaEditor compilation timed out for EA #%d", ea_id)
            raw = "Compilation timed out after 120 seconds."
            compile_failed = True
        except FileNotFoundError:
            logger.error("MetaEditor not found at: %s", settings.metaeditor_path)
            raw = f"MetaEditor executable not found: {settings.metaeditor_path}"
            compile_failed = True
        except Exception as exc:
            logger.error("MetaEditor execution error for EA #%d: %s", ea_id, exc)
            raw = f"MetaEditor execution error: {exc}"
            compile_failed = True

        if not compile_failed:
            raw = _read_log_file(log_path)
            errors, warnings = _parse_log(raw)
            if errors:
                status = "error"
            elif warnings:
                status = "warning"
            else:
                status = "success"

    if ws_queue:
        for entry in errors:
            await ws_queue.put({"type": "error", **asdict(entry)})
        for entry in warnings:
            await ws_queue.put({"type": "warning", **asdict(entry)})
        await ws_queue.put({"type": "complete", "status": status})

    # Persist to DB
    log_record = CompileLog(
        ea_id=ea_id,
        timestamp=datetime.utcnow(),
        status=status,
        errors_json=json.dumps([asdict(e) for e in errors]),
        warnings_json=json.dumps([asdict(w) for w in warnings]),
        raw_log=raw,
    )
    db.add(log_record)
    await db.commit()

    return CompileResult(
        ea_id=ea_id,
        status=status,
        errors=errors,
        warnings=warnings,
        raw_log=raw,
        compiled_at=datetime.utcnow().isoformat() + "Z",
    )
