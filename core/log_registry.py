"""Centralized structured log registry — SQLite + rotating file + WebSocket broadcast."""
import json
import logging
import asyncio
from datetime import datetime
from logging.handlers import RotatingFileHandler
from pathlib import Path


class DBLogHandler(logging.Handler):
    """Writes log records to platform_logs table and broadcasts to WebSocket clients."""

    def emit(self, record: logging.LogRecord) -> None:
        try:
            context = getattr(record, "context", {})
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                return  # no running loop; skip DB write (e.g. during startup sync code)
            loop.create_task(self._write(record, context))
        except Exception:
            self.handleError(record)

    @staticmethod
    async def _write(record: logging.LogRecord, context: dict) -> None:
        try:
            from db.database import AsyncSessionLocal
            from db.models import PlatformLog
            from api.websockets.logs_ws import logs_manager

            entry = PlatformLog(
                level=record.levelname,
                logger_name=record.name,
                message=record.getMessage(),
                context_json=json.dumps(context),
                timestamp=datetime.utcnow(),
            )
            async with AsyncSessionLocal() as db:
                db.add(entry)
                await db.commit()
                await db.refresh(entry)

            await logs_manager.broadcast({
                "id": entry.id,
                "level": record.levelname,
                "logger_name": record.name,
                "message": record.getMessage(),
                "context": context,
                "timestamp": entry.timestamp.isoformat(),
            })
        except Exception:
            pass  # never crash the application due to logging


_db_handler = DBLogHandler()
_db_handler.setLevel(logging.INFO)

_formatter = logging.Formatter("%(asctime)s | %(levelname)-8s | %(name)s | %(message)s")
_db_handler.setFormatter(_formatter)

# Rotating file handler — 5 MB × 3 files
_log_dir = Path("logs")
_log_dir.mkdir(exist_ok=True)
_file_handler = RotatingFileHandler(
    _log_dir / "platform.log",
    maxBytes=5 * 1024 * 1024,
    backupCount=3,
    encoding="utf-8",
)
_file_handler.setLevel(logging.DEBUG)
_file_handler.setFormatter(_formatter)


def setup_log_registry(level: int = logging.INFO) -> None:
    """Attach DB + file handlers to the root logger."""
    root = logging.getLogger()
    if _db_handler not in root.handlers:
        root.addHandler(_db_handler)
    if _file_handler not in root.handlers:
        root.addHandler(_file_handler)
    root.setLevel(level)
