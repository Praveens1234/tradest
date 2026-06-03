"""EA CRUD, upload, and compile endpoints."""
import json
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.database import get_db
from db.models import CompileLog
from api.middleware.auth import require_auth
from core import ea_manager, compiler
from api.websockets.compile_ws import compile_manager

router = APIRouter()


class CreateEARequest(BaseModel):
    name: str
    content: str
    type: str = "mq5"


class UpdateEARequest(BaseModel):
    content: str


@router.post("/create", dependencies=[Depends(require_auth)])
async def create_ea(req: CreateEARequest, db: AsyncSession = Depends(get_db)):
    try:
        ea = await ea_manager.create_ea(db, req.name, req.content, req.type)
    except FileExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return {"id": ea.id, "name": ea.name, "path": ea.path, "type": ea.type}


@router.post("/upload", dependencies=[Depends(require_auth)])
async def upload_ea(
    file: UploadFile = File(...),
    override: bool = False,
    new_name: str = "",
    db: AsyncSession = Depends(get_db),
):
    content = await file.read()
    ea, conflict = await ea_manager.upload_ea(db, file.filename, content, override, new_name)
    if conflict:
        raise HTTPException(status_code=409, detail=conflict.__dict__)
    return {"id": ea.id, "name": ea.name, "path": ea.path}


@router.get("/list", dependencies=[Depends(require_auth)])
async def list_eas(db: AsyncSession = Depends(get_db)):
    eas = await ea_manager.list_eas(db)
    return [{"id": e.id, "name": e.name, "path": e.path, "type": e.type, "updated_at": str(e.updated_at)} for e in eas]


@router.get("/{ea_id}", dependencies=[Depends(require_auth)])
async def get_ea(ea_id: int, db: AsyncSession = Depends(get_db)):
    ea = await ea_manager.get_ea(db, ea_id)
    if not ea:
        raise HTTPException(status_code=404, detail="EA not found")
    try:
        from core.file_manager.fs_operations import read_file
        content = read_file(ea.path)
    except FileNotFoundError:
        content = ""
    return {"id": ea.id, "name": ea.name, "path": ea.path, "type": ea.type, "content": content}


@router.put("/{ea_id}", dependencies=[Depends(require_auth)])
async def update_ea(ea_id: int, req: UpdateEARequest, db: AsyncSession = Depends(get_db)):
    ea = await ea_manager.update_ea(db, ea_id, req.content)
    if not ea:
        raise HTTPException(status_code=404, detail="EA not found")
    return {"id": ea.id, "name": ea.name, "updated_at": str(ea.updated_at)}


@router.delete("/{ea_id}", dependencies=[Depends(require_auth)])
async def delete_ea(ea_id: int, db: AsyncSession = Depends(get_db)):
    deleted = await ea_manager.delete_ea(db, ea_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="EA not found")
    return {"deleted": True}


@router.post("/{ea_id}/compile", dependencies=[Depends(require_auth)])
async def compile_ea_endpoint(ea_id: int, db: AsyncSession = Depends(get_db)):
    queue_key = str(ea_id)
    ws_queue = compile_manager.get_queue(queue_key)
    try:
        result = await compiler.compile_ea(db, ea_id, ws_queue=ws_queue)
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    finally:
        compile_manager.remove_queue(queue_key)
    return {
        "ea_id": result.ea_id,
        "status": result.status,
        "errors": [e.__dict__ for e in result.errors],
        "warnings": [w.__dict__ for w in result.warnings],
        "raw_log": result.raw_log,
        "compiled_at": result.compiled_at,
    }


@router.get("/{ea_id}/compile/logs", dependencies=[Depends(require_auth)])
async def get_compile_logs(ea_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(CompileLog).where(CompileLog.ea_id == ea_id).order_by(CompileLog.timestamp.desc())
    )
    logs = result.scalars().all()
    return [
        {
            "id": l.id,
            "timestamp": str(l.timestamp),
            "status": l.status,
            "errors": json.loads(l.errors_json),
            "warnings": json.loads(l.warnings_json),
        }
        for l in logs
    ]


@router.get("/{ea_id}/compile/logs/last", dependencies=[Depends(require_auth)])
async def get_last_compile_log(ea_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(CompileLog).where(CompileLog.ea_id == ea_id).order_by(CompileLog.timestamp.desc()).limit(1)
    )
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="No compile logs for this EA")
    return {
        "id": log.id,
        "timestamp": str(log.timestamp),
        "status": log.status,
        "errors": json.loads(log.errors_json),
        "warnings": json.loads(log.warnings_json),
        "raw_log": log.raw_log,
    }
