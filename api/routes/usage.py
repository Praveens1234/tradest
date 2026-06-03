"""Usage log and health endpoints."""
import pathlib
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from db.database import get_db
from api.middleware.auth import require_auth
from core import usage_store
from config import settings
import psutil

router = APIRouter()


@router.get("/usage/events", dependencies=[Depends(require_auth)])
async def get_events(
    limit: int = Query(default=100, le=1000),
    action: str | None = None,
    date: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    events = await usage_store.get_events(db, limit=limit, action_filter=action)
    return [
        {
            "id": e.id,
            "interface": e.interface,
            "action": e.action,
            "ea_id": e.ea_id,
            "run_id": e.run_id,
            "duration_ms": e.duration_ms,
            "status": e.status,
            "error_msg": e.error_msg,
            "timestamp": str(e.timestamp),
        }
        for e in events
    ]


@router.get("/health")
async def health():
    terminal_ok = bool(settings.terminal_path and pathlib.Path(settings.terminal_path).exists())
    metaeditor_ok = bool(settings.metaeditor_path and pathlib.Path(settings.metaeditor_path).exists())
    mql5_ok = bool(settings.mql5_root and pathlib.Path(settings.mql5_root).exists())

    overall = "ok" if (terminal_ok and metaeditor_ok and mql5_ok) else "degraded"

    try:
        cpu = psutil.cpu_percent(interval=0.1)
        mem = psutil.virtual_memory()
        memory_mb = round(mem.used / 1024 / 1024, 1)
    except Exception:
        cpu = 0.0
        memory_mb = 0.0

    return {
        "status": overall,
        "terminal_path": settings.terminal_path,
        "terminal_ok": terminal_ok,
        "metaeditor_path": settings.metaeditor_path,
        "metaeditor_ok": metaeditor_ok,
        "mql5_root": settings.mql5_root,
        "mql5_ok": mql5_ok,
        "cpu_percent": cpu,
        "memory_mb": memory_mb,
    }
