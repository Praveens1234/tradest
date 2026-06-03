"""File Manager endpoints: tree, CRUD, upload, copy, move, delete, download."""
import json
import pathlib
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import Response, StreamingResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from db.database import get_db
from api.middleware.auth import require_auth
from core.file_manager import fs_navigator, fs_operations, file_uploader, zip_exporter
from core.file_manager.conflict_resolver import check_conflict
from core import compiler as compiler_module
from config import settings

router = APIRouter()


def _node_to_dict(node) -> dict:
    d = {
        "name": node.name,
        "path": node.path,
        "is_dir": node.is_dir,
        "extension": node.extension,
        "size": node.size,
    }
    if node.children is not None:
        d["children"] = [_node_to_dict(c) for c in node.children]
    return d


@router.get("/tree", dependencies=[Depends(require_auth)])
async def get_tree(path: str = "", depth: int = 8):
    try:
        tree = fs_navigator.get_tree(path, max_depth=depth)
        return _node_to_dict(tree)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/list", dependencies=[Depends(require_auth)])
async def list_dir(path: str = ""):
    try:
        items = fs_navigator.list_dir(path)
        return [_node_to_dict(n) for n in items]
    except (ValueError, NotADirectoryError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/read", dependencies=[Depends(require_auth)])
async def read_file(path: str = Query(...)):
    try:
        content = fs_operations.read_file(path)
        return {"path": path, "content": content}
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/meta", dependencies=[Depends(require_auth)])
async def get_meta(path: str = Query(...)):
    try:
        return fs_operations.get_meta(path)
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/search", dependencies=[Depends(require_auth)])
async def search_files(q: str, path: str = ""):
    results = fs_navigator.search(q, path)
    return [_node_to_dict(n) for n in results]


@router.get("/download", dependencies=[Depends(require_auth)])
async def download_file(path: str = Query(...)):
    try:
        root = settings.mql5_root or settings.workspace_dir or "workspace"
        abs_path = fs_navigator._safe_resolve(path, root)
        content = abs_path.read_bytes()
        filename = abs_path.name
        return Response(
            content=content,
            media_type="application/octet-stream",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/download-zip", dependencies=[Depends(require_auth)])
async def download_zip(path: str = Query(...)):
    try:
        data = zip_exporter.zip_folder(path)
        folder_name = pathlib.Path(path).name or "archive"
        return Response(
            content=data,
            media_type="application/zip",
            headers={"Content-Disposition": f'attachment; filename="{folder_name}.zip"'},
        )
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc))


class WriteRequest(BaseModel):
    path: str
    content: str
    override: bool = False
    new_name: str = ""


@router.post("/write", dependencies=[Depends(require_auth)])
async def write_file(req: WriteRequest):
    try:
        saved_path = fs_operations.write_file(req.path, req.content, req.override, req.new_name)
        return {"path": saved_path}
    except FileExistsError as exc:
        try:
            conflict_data = json.loads(str(exc))
        except Exception:
            conflict_data = str(exc)
        raise HTTPException(status_code=409, detail=conflict_data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/upload", dependencies=[Depends(require_auth)])
async def upload_file(
    path: str = "",
    override: bool = False,
    new_name: str = "",
    file: UploadFile = File(...),
):
    content = await file.read()
    result = await file_uploader.upload_file(path, file.filename, content, override, new_name)
    if result.conflict:
        raise HTTPException(status_code=409, detail=result.conflict.__dict__)
    return {"filename": result.filename, "path": result.path, "size_bytes": result.size_bytes}


class MkdirRequest(BaseModel):
    path: str


@router.post("/mkdir", dependencies=[Depends(require_auth)])
async def create_dir(req: MkdirRequest):
    try:
        created = fs_operations.create_dir(req.path)
        return {"path": created}
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


class RenameRequest(BaseModel):
    path: str
    new_name: str
    override: bool = False


@router.put("/rename", dependencies=[Depends(require_auth)])
async def rename_file(req: RenameRequest):
    try:
        new_path = fs_operations.rename(req.path, req.new_name, req.override)
        return {"path": new_path}
    except FileExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))


class CopyMoveRequest(BaseModel):
    source: str
    destination: str
    override: bool = False


@router.put("/copy", dependencies=[Depends(require_auth)])
async def copy_file(req: CopyMoveRequest):
    try:
        dest = fs_operations.copy(req.source, req.destination, req.override)
        return {"path": dest}
    except FileExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.put("/move", dependencies=[Depends(require_auth)])
async def move_file(req: CopyMoveRequest):
    try:
        dest = fs_operations.move(req.source, req.destination, req.override)
        return {"path": dest}
    except FileExistsError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=400, detail=str(exc))


class DeleteRequest(BaseModel):
    path: str
    soft: bool = True


@router.delete("/delete", dependencies=[Depends(require_auth)])
async def delete_file(req: DeleteRequest):
    try:
        msg = fs_operations.delete(req.path, req.soft)
        return {"message": msg}
    except (ValueError, FileNotFoundError) as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/compile", dependencies=[Depends(require_auth)])
async def compile_by_path(path: str, db: AsyncSession = Depends(get_db)):
    """Compile any .mq5 file directly by path (not by ea_id)."""
    from sqlalchemy import select
    from db.models import EAFile
    stmt = select(EAFile).where(EAFile.path == path)
    ea = (await db.execute(stmt)).scalar_one_or_none()
    if not ea:
        raise HTTPException(status_code=404, detail="EA not registered. Use /ea/upload first.")
    result = await compiler_module.compile_ea(db, ea.id)
    return {
        "ea_id": result.ea_id,
        "status": result.status,
        "errors": [e.__dict__ for e in result.errors],
        "warnings": [w.__dict__ for w in result.warnings],
        "compiled_at": result.compiled_at,
    }
