"""EA-specific management layer delegating FS operations to file_manager."""
import json
import pathlib
import logging
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.models import EAFile
from config import settings
from core.file_manager import file_uploader, fs_operations, fs_navigator
from core.file_manager.conflict_resolver import ConflictInfo

logger = logging.getLogger(__name__)

EXPERTS_SUBDIR = "Experts"


def _ensure_experts_dir() -> pathlib.Path:
    root = settings.mql5_root or settings.workspace_dir or "workspace"
    experts = pathlib.Path(root) / EXPERTS_SUBDIR
    experts.mkdir(parents=True, exist_ok=True)
    return experts


async def create_ea(
    db: AsyncSession, name: str, content: str, file_type: str = "mq5"
) -> EAFile:
    root = settings.mql5_root or settings.workspace_dir or "workspace"
    rel_path = f"{EXPERTS_SUBDIR}/{name}.{file_type}"
    fs_operations.write_file(rel_path, content, override=False)

    ea = EAFile(
        name=name,
        path=rel_path,
        type=file_type,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(ea)
    await db.commit()
    await db.refresh(ea)
    return ea


async def upload_ea(
    db: AsyncSession,
    filename: str,
    content: bytes,
    override: bool = False,
    new_name: str = "",
) -> tuple[EAFile | None, ConflictInfo | None]:
    result = await file_uploader.upload_file(
        dest_dir=EXPERTS_SUBDIR,
        filename=filename,
        content=content,
        override=override,
        new_name=new_name,
    )
    if result.conflict:
        return None, result.conflict

    name_without_ext = pathlib.Path(result.filename).stem
    file_type = pathlib.Path(result.filename).suffix.lstrip(".")

    # Upsert DB record
    stmt = select(EAFile).where(EAFile.path == result.path)
    existing = (await db.execute(stmt)).scalar_one_or_none()
    if existing:
        existing.updated_at = datetime.utcnow()
        await db.commit()
        return existing, None

    ea = EAFile(
        name=name_without_ext,
        path=result.path,
        type=file_type,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(ea)
    await db.commit()
    await db.refresh(ea)
    return ea, None


async def get_ea(db: AsyncSession, ea_id: int) -> EAFile | None:
    stmt = select(EAFile).where(EAFile.id == ea_id)
    return (await db.execute(stmt)).scalar_one_or_none()


async def list_eas(db: AsyncSession) -> list[EAFile]:
    await _auto_sync_experts(db)
    result = await db.execute(select(EAFile).order_by(EAFile.name))
    return list(result.scalars().all())


async def _auto_sync_experts(db: AsyncSession) -> None:
    """Register any .mq5 files found on disk that are not yet in the DB."""
    experts_dir = _ensure_experts_dir().resolve()   # must be absolute for relative_to() below
    root = pathlib.Path(settings.mql5_root or settings.workspace_dir or "workspace").resolve()
    added = False
    for mq5_file in sorted(experts_dir.rglob("*.mq5")):
        try:
            rel_path = str(mq5_file.relative_to(root)).replace("\\", "/")
        except ValueError:
            continue
        stmt = select(EAFile).where(EAFile.path == rel_path)
        if not (await db.execute(stmt)).scalar_one_or_none():
            mtime = datetime.utcfromtimestamp(mq5_file.stat().st_mtime)
            db.add(EAFile(
                name=mq5_file.stem,
                path=rel_path,
                type="mq5",
                created_at=mtime,
                updated_at=mtime,
            ))
            logger.info("Auto-registered EA from disk: %s", rel_path)
            added = True
    if added:
        await db.commit()


async def update_ea(db: AsyncSession, ea_id: int, content: str) -> EAFile | None:
    ea = await get_ea(db, ea_id)
    if not ea:
        return None
    fs_operations.write_file(ea.path, content, override=True)
    ea.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(ea)
    return ea


async def delete_ea(db: AsyncSession, ea_id: int) -> bool:
    ea = await get_ea(db, ea_id)
    if not ea:
        return False
    try:
        fs_operations.delete(ea.path, soft=True)
    except FileNotFoundError:
        pass
    await db.delete(ea)
    await db.commit()
    return True


def get_template(name: str) -> str:
    template_path = pathlib.Path(settings.workspace_dir) / "templates" / f"{name}.mq5"
    if template_path.exists():
        return template_path.read_text(encoding="utf-8")
    return _default_template(name)


def _default_template(name: str) -> str:
    return f"""//+------------------------------------------------------------------+
//|                                                    {name}.mq5 |
//|                        Copyright 2024, MT5 EA Platform         |
//+------------------------------------------------------------------+
#property copyright "MT5 EA Platform"
#property strict

input double LotSize = 0.1;

int OnInit()
{{
   return(INIT_SUCCEEDED);
}}

void OnDeinit(const int reason)
{{
}}

void OnTick()
{{
}}
"""
