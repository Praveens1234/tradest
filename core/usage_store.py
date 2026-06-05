"""SQLite usage/activity event logging."""
import logging
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.models import UsageEvent

logger = logging.getLogger(__name__)


async def log_event(
    db: AsyncSession,
    interface: str,
    action: str,
    ea_id: int | None = None,
    run_id: int | None = None,
    duration_ms: int | None = None,
    status: str = "ok",
    error_msg: str | None = None,
) -> None:
    event = UsageEvent(
        interface=interface,
        action=action,
        ea_id=ea_id,
        run_id=run_id,
        duration_ms=duration_ms,
        status=status,
        error_msg=error_msg,
        timestamp=datetime.utcnow(),
    )
    db.add(event)
    await db.commit()


async def get_events(
    db: AsyncSession,
    limit: int = 100,
    action_filter: str | None = None,
    date_filter: str | None = None,
) -> list[UsageEvent]:
    stmt = select(UsageEvent).order_by(UsageEvent.timestamp.desc())
    if action_filter:
        stmt = stmt.where(UsageEvent.action == action_filter)
    if date_filter:
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(date_filter)
            stmt = stmt.where(UsageEvent.timestamp >= dt)
        except ValueError:
            pass
    stmt = stmt.limit(limit)
    result = await db.execute(stmt)
    return list(result.scalars().all())
