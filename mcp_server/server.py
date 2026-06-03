"""MCP Server — all tools wired to the Core Service Layer via stdio transport."""
import json
import base64
import asyncio
import pathlib
import logging
from mcp.server.fastmcp import FastMCP
from db.database import AsyncSessionLocal, init_db
from core.cli_automation.ini_generator import BacktestParams

logger = logging.getLogger(__name__)
mcp = FastMCP("MT5 EA Platform")


async def _get_db():
    async with AsyncSessionLocal() as db:
        return db


# ─────────────────────────────── AUTH ────────────────────────────────

@mcp.tool()
async def auth_check(api_key: str) -> dict:
    """Validate API key and confirm server connectivity."""
    from passlib.context import CryptContext
    from config import settings
    ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
    if not settings.api_key_hash:
        return {"valid": False, "error": "API key not configured"}
    try:
        valid = ctx.verify(api_key, settings.api_key_hash)
    except Exception:
        valid = False
    return {"valid": valid}


# ─────────────────────────────── EA TOOLS ────────────────────────────────

@mcp.tool()
async def ea_create(name: str, code: str, type: str = "mq5") -> dict:
    """Create a new EA file in the MQL5/Experts folder."""
    async with AsyncSessionLocal() as db:
        from core import ea_manager
        try:
            ea = await ea_manager.create_ea(db, name, code, type)
            return {"id": ea.id, "name": ea.name, "path": ea.path}
        except FileExistsError as exc:
            return {"error": "conflict", "detail": str(exc)}


@mcp.tool()
async def ea_upload(filename: str, content_base64: str) -> dict:
    """Upload a .mq5 file (base64 encoded) to MQL5/Experts/."""
    content = base64.b64decode(content_base64)
    async with AsyncSessionLocal() as db:
        from core import ea_manager
        ea, conflict = await ea_manager.upload_ea(db, filename, content)
        if conflict:
            return {"conflict": True, "existing_path": conflict.existing_path, "suggested_name": conflict.suggested_name}
        return {"id": ea.id, "name": ea.name, "path": ea.path}


@mcp.tool()
async def ea_read(ea_id: int) -> dict:
    """Read EA source code by ID."""
    async with AsyncSessionLocal() as db:
        from core import ea_manager
        from core.file_manager.fs_operations import read_file
        ea = await ea_manager.get_ea(db, ea_id)
        if not ea:
            return {"error": "EA not found"}
        try:
            content = read_file(ea.path)
        except FileNotFoundError:
            content = ""
        return {"id": ea.id, "name": ea.name, "content": content}


@mcp.tool()
async def ea_update(ea_id: int, code: str) -> dict:
    """Update EA source code."""
    async with AsyncSessionLocal() as db:
        from core import ea_manager
        ea = await ea_manager.update_ea(db, ea_id, code)
        if not ea:
            return {"error": "EA not found"}
        return {"id": ea.id, "updated_at": str(ea.updated_at)}


@mcp.tool()
async def ea_list() -> list:
    """List all registered EAs."""
    async with AsyncSessionLocal() as db:
        from core import ea_manager
        eas = await ea_manager.list_eas(db)
        return [{"id": e.id, "name": e.name, "path": e.path, "type": e.type} for e in eas]


@mcp.tool()
async def ea_delete(ea_id: int, confirm: bool = False) -> dict:
    """Delete an EA file. Must set confirm=True."""
    if not confirm:
        return {"error": "Pass confirm=True to delete"}
    async with AsyncSessionLocal() as db:
        from core import ea_manager
        deleted = await ea_manager.delete_ea(db, ea_id)
        return {"deleted": deleted}


@mcp.tool()
async def ea_compile(ea_id: int) -> dict:
    """Compile an EA by ID. Returns structured compile result."""
    async with AsyncSessionLocal() as db:
        from core import compiler
        try:
            result = await compiler.compile_ea(db, ea_id)
            return {
                "ea_id": result.ea_id,
                "status": result.status,
                "errors": [e.__dict__ for e in result.errors],
                "warnings": [w.__dict__ for w in result.warnings],
                "raw_log": result.raw_log,
                "compiled_at": result.compiled_at,
            }
        except (ValueError, FileNotFoundError) as exc:
            return {"error": str(exc)}


@mcp.tool()
async def ea_compile_log(ea_id: int) -> dict:
    """Get the latest compile log for an EA."""
    from sqlalchemy import select
    from db.models import CompileLog
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(CompileLog).where(CompileLog.ea_id == ea_id).order_by(CompileLog.timestamp.desc()).limit(1)
        )
        log = result.scalar_one_or_none()
        if not log:
            return {"error": "No compile logs found"}
        return {
            "status": log.status,
            "timestamp": str(log.timestamp),
            "errors": json.loads(log.errors_json),
            "warnings": json.loads(log.warnings_json),
            "raw_log": log.raw_log,
        }


# ─────────────────────────────── FILE TOOLS ────────────────────────────────

@mcp.tool()
async def file_tree(path: str = "") -> dict:
    """Get the MQL5 directory tree."""
    from core.file_manager.fs_navigator import get_tree
    def _to_dict(n):
        d = {"name": n.name, "path": n.path, "is_dir": n.is_dir, "extension": n.extension, "size": n.size}
        if n.children is not None:
            d["children"] = [_to_dict(c) for c in n.children]
        return d
    return _to_dict(get_tree(path))


@mcp.tool()
async def file_list(path: str) -> list:
    """List contents of a directory."""
    from core.file_manager.fs_navigator import list_dir
    items = list_dir(path)
    return [{"name": n.name, "path": n.path, "is_dir": n.is_dir, "size": n.size} for n in items]


@mcp.tool()
async def file_read(path: str) -> dict:
    """Read file content as text."""
    from core.file_manager.fs_operations import read_file
    try:
        return {"path": path, "content": read_file(path)}
    except FileNotFoundError:
        return {"error": "File not found"}


@mcp.tool()
async def file_meta(path: str) -> dict:
    """Get file metadata."""
    from core.file_manager.fs_operations import get_meta
    try:
        return get_meta(path)
    except FileNotFoundError:
        return {"error": "File not found"}


@mcp.tool()
async def file_search(query: str, path: str = "") -> list:
    """Search files by name or content."""
    from core.file_manager.fs_navigator import search
    items = search(query, path)
    return [{"name": n.name, "path": n.path, "is_dir": n.is_dir} for n in items]


@mcp.tool()
async def file_write(path: str, content: str, override: bool = False, new_name: str = "") -> dict:
    """Write or create a file."""
    from core.file_manager.fs_operations import write_file
    try:
        saved = write_file(path, content, override, new_name)
        return {"path": saved}
    except FileExistsError as exc:
        return {"conflict": True, "detail": str(exc)}


@mcp.tool()
async def file_upload(path: str, content_base64: str, override: bool = False, new_name: str = "") -> dict:
    """Upload a file (base64 encoded content) to a directory."""
    content = base64.b64decode(content_base64)
    filename = pathlib.Path(path).name
    dest_dir = str(pathlib.Path(path).parent)
    from core.file_manager.file_uploader import upload_file
    result = await upload_file(dest_dir, filename, content, override, new_name)
    if result.conflict:
        return {"conflict": True, "suggested_name": result.conflict.suggested_name}
    return {"filename": result.filename, "path": result.path}


@mcp.tool()
async def file_mkdir(path: str) -> dict:
    """Create a directory."""
    from core.file_manager.fs_operations import create_dir
    try:
        return {"path": create_dir(path)}
    except ValueError as exc:
        return {"error": str(exc)}


@mcp.tool()
async def file_rename(path: str, new_name: str, override: bool = False) -> dict:
    """Rename a file or folder."""
    from core.file_manager.fs_operations import rename
    try:
        return {"path": rename(path, new_name, override)}
    except FileExistsError as exc:
        return {"conflict": True, "detail": str(exc)}


@mcp.tool()
async def file_copy(source: str, destination: str, override: bool = False) -> dict:
    """Copy a file or folder."""
    from core.file_manager.fs_operations import copy
    try:
        return {"path": copy(source, destination, override)}
    except FileExistsError as exc:
        return {"conflict": True, "detail": str(exc)}


@mcp.tool()
async def file_move(source: str, destination: str, override: bool = False) -> dict:
    """Move a file or folder."""
    from core.file_manager.fs_operations import move
    try:
        return {"path": move(source, destination, override)}
    except FileExistsError as exc:
        return {"conflict": True, "detail": str(exc)}


@mcp.tool()
async def file_delete(path: str, confirm: bool = False) -> dict:
    """Delete a file or folder (soft delete to _trash/ by default)."""
    if not confirm:
        return {"error": "Pass confirm=True to delete"}
    from core.file_manager.fs_operations import delete
    try:
        return {"message": delete(path, soft=True)}
    except FileNotFoundError as exc:
        return {"error": str(exc)}


@mcp.tool()
async def file_download_zip(path: str) -> dict:
    """Zip a folder and return base64-encoded content."""
    from core.file_manager.zip_exporter import zip_folder
    try:
        data = zip_folder(path)
        return {"content_base64": base64.b64encode(data).decode(), "size_bytes": len(data)}
    except FileNotFoundError as exc:
        return {"error": str(exc)}


@mcp.tool()
async def file_compile(path: str) -> dict:
    """Compile a .mq5 file by its path."""
    from sqlalchemy import select
    from db.models import EAFile
    async with AsyncSessionLocal() as db:
        stmt = select(EAFile).where(EAFile.path == path)
        ea = (await db.execute(stmt)).scalar_one_or_none()
        if not ea:
            return {"error": "EA not registered. Use ea_upload or ea_create first."}
        from core import compiler
        result = await compiler.compile_ea(db, ea.id)
        return {"status": result.status, "errors": [e.__dict__ for e in result.errors]}


# ─────────────────────────────── BACKTEST TOOLS ────────────────────────────────

@mcp.tool()
async def backtest_run(
    ea_id: int,
    symbol: str = "EURUSD",
    period: str = "H1",
    from_date: str = "2024.01.01",
    to_date: str = "2024.12.31",
    model: int = 1,
    deposit: float = 10000.0,
    currency: str = "USD",
    leverage: int = 100,
) -> dict:
    """Launch a backtest. Returns run_id immediately."""
    async with AsyncSessionLocal() as db:
        from core import ea_manager, backtest_controller
        ea = await ea_manager.get_ea(db, ea_id)
        if not ea:
            return {"error": "EA not found"}
        params = BacktestParams(
            ea_name=ea.name, symbol=symbol, period=period,
            from_date=from_date, to_date=to_date, model=model,
            deposit=deposit, currency=currency, leverage=leverage,
        )
        run_id = await backtest_controller.start_backtest(db, params, ea_id=ea_id)
        return {"run_id": run_id, "status": "pending"}


@mcp.tool()
async def backtest_status(run_id: int) -> dict:
    """Get current status of a backtest run."""
    async with AsyncSessionLocal() as db:
        from core import backtest_controller
        run = await backtest_controller.get_run(db, run_id)
        if not run:
            return {"error": "Run not found"}
        return {"run_id": run.id, "status": run.status, "pid": run.pid}


@mcp.tool()
async def backtest_result(run_id: int) -> dict:
    """Get result metrics for a completed backtest."""
    async with AsyncSessionLocal() as db:
        from core import backtest_controller
        result = await backtest_controller.get_result(db, run_id)
        if not result:
            return {"error": "Result not available"}
        return {
            "run_id": run_id,
            "metrics": json.loads(result.metrics_json),
            "trades_count": len(json.loads(result.trades_json)),
        }


@mcp.tool()
async def backtest_report_html(run_id: int) -> dict:
    """Get HTML report path for a backtest run."""
    async with AsyncSessionLocal() as db:
        from core import backtest_controller
        result = await backtest_controller.get_result(db, run_id)
        if not result or not result.html_path:
            return {"error": "HTML report not available"}
        return {"run_id": run_id, "html_path": result.html_path}


@mcp.tool()
async def backtest_report_excel(run_id: int) -> dict:
    """Get Excel XML report path for a backtest run."""
    async with AsyncSessionLocal() as db:
        from core import backtest_controller
        result = await backtest_controller.get_result(db, run_id)
        if not result or not result.xml_path:
            return {"error": "Excel report not available"}
        return {"run_id": run_id, "xml_path": result.xml_path}


@mcp.tool()
async def backtest_report_csv(run_id: int) -> dict:
    """Get CSV ledger path for a backtest run."""
    async with AsyncSessionLocal() as db:
        from core import backtest_controller
        result = await backtest_controller.get_result(db, run_id)
        if not result or not result.csv_path:
            return {"error": "CSV report not available"}
        return {"run_id": run_id, "csv_path": result.csv_path}


@mcp.tool()
async def backtest_cancel(run_id: int) -> dict:
    """Cancel a running backtest."""
    from core import backtest_controller
    cancelled = await backtest_controller.cancel_backtest(run_id)
    return {"cancelled": cancelled}


@mcp.tool()
async def backtest_history(limit: int = 20, ea_id: int | None = None) -> list:
    """List past backtest runs with summaries."""
    async with AsyncSessionLocal() as db:
        from core import backtest_controller
        runs = await backtest_controller.get_history(db, limit=limit)
        if ea_id:
            runs = [r for r in runs if r.ea_id == ea_id]
        return [
            {"run_id": r.id, "ea_id": r.ea_id, "status": r.status,
             "started_at": str(r.started_at)}
            for r in runs
        ]


# ─────────────────────────────── USAGE TOOL ────────────────────────────────

@mcp.tool()
async def usage_log(limit: int = 50, action: str | None = None) -> list:
    """Query usage/activity log."""
    async with AsyncSessionLocal() as db:
        from core import usage_store
        events = await usage_store.get_events(db, limit=limit, action_filter=action)
        return [
            {"id": e.id, "interface": e.interface, "action": e.action,
             "status": e.status, "timestamp": str(e.timestamp)}
            for e in events
        ]


if __name__ == "__main__":
    asyncio.run(init_db())
    mcp.run(transport="stdio")
