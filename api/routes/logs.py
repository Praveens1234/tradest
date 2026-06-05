"""GET /logs/recent — paginated structured log query."""
import json
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from db.database import get_db
from db.models import PlatformLog
from api.middleware.auth import require_auth

router = APIRouter(tags=["Logs"])


@router.get("/logs/recent")
async def get_recent_logs(
    limit: int = Query(100, ge=1, le=500),
    level: str | None = Query(None, description="Filter by level: DEBUG, INFO, WARNING, ERROR, CRITICAL"),
    logger: str | None = Query(None, description="Filter by logger name (substring match)"),
    _: str = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(PlatformLog).order_by(desc(PlatformLog.timestamp))
    if level:
        stmt = stmt.where(PlatformLog.level == level.upper())
    if logger:
        stmt = stmt.where(PlatformLog.logger_name.contains(logger))
    stmt = stmt.limit(limit)
    rows = (await db.execute(stmt)).scalars().all()
    return [
        {
            "id": r.id,
            "level": r.level,
            "logger_name": r.logger_name,
            "message": r.message,
            "context": json.loads(r.context_json or "{}"),
            "timestamp": r.timestamp.isoformat() if r.timestamp else None,
        }
        for r in rows
    ]


@router.delete("/logs/clear")
async def clear_logs(
    _: str = Depends(require_auth),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import delete as sql_delete
    await db.execute(sql_delete(PlatformLog))
    await db.commit()
    return {"cleared": True}
