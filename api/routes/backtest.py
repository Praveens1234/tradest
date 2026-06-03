"""Backtest run, status, result, and report download endpoints."""
import json
import pathlib
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from db.database import get_db
from api.middleware.auth import require_auth
from core import backtest_controller
from core.cli_automation.ini_generator import BacktestParams
from config import settings

router = APIRouter()


class RunBacktestRequest(BaseModel):
    ea_id: int | None = None
    ea_name: str = ""
    symbol: str = "EURUSD"
    period: str = "H1"
    from_date: str = "2024.01.01"
    to_date: str = "2024.12.31"
    model: int = 1
    deposit: float = 10000.0
    currency: str = "USD"
    leverage: int = 100
    ea_set_params: dict = {}
    login: str = ""
    password: str = ""
    server: str = ""


@router.post("/run", dependencies=[Depends(require_auth)])
async def run_backtest(req: RunBacktestRequest, db: AsyncSession = Depends(get_db)):
    # Resolve EA name from DB if ea_id given
    ea_name = req.ea_name
    if req.ea_id and not ea_name:
        from core.ea_manager import get_ea
        ea = await get_ea(db, req.ea_id)
        if ea:
            ea_name = ea.name

    if not ea_name:
        raise HTTPException(status_code=400, detail="ea_name or ea_id required")

    params = BacktestParams(
        ea_name=ea_name,
        symbol=req.symbol,
        period=req.period,
        from_date=req.from_date,
        to_date=req.to_date,
        model=req.model,
        deposit=req.deposit,
        currency=req.currency,
        leverage=req.leverage,
        ea_set_params=req.ea_set_params,
        login=req.login,
        password=req.password,
        server=req.server,
    )
    run_id = await backtest_controller.start_backtest(db, params, ea_id=req.ea_id)
    return {"run_id": run_id, "status": "pending"}


@router.get("/{run_id}/status", dependencies=[Depends(require_auth)])
async def get_status(run_id: int, db: AsyncSession = Depends(get_db)):
    run = await backtest_controller.get_run(db, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="Run not found")
    return {
        "run_id": run.id,
        "status": run.status,
        "pid": run.pid,
        "started_at": str(run.started_at) if run.started_at else None,
        "finished_at": str(run.finished_at) if run.finished_at else None,
    }


@router.get("/{run_id}/result", dependencies=[Depends(require_auth)])
async def get_result(run_id: int, db: AsyncSession = Depends(get_db)):
    result = await backtest_controller.get_result(db, run_id)
    if not result:
        raise HTTPException(status_code=404, detail="Result not available yet")
    return {
        "run_id": run_id,
        "metrics": json.loads(result.metrics_json),
        "trades": json.loads(result.trades_json),
        "html_path": result.html_path,
        "xml_path": result.xml_path,
        "csv_path": result.csv_path,
    }


@router.get("/{run_id}/reports", dependencies=[Depends(require_auth)])
async def list_reports(run_id: int, db: AsyncSession = Depends(get_db)):
    result = await backtest_controller.get_result(db, run_id)
    if not result:
        raise HTTPException(status_code=404, detail="No reports for this run")
    files = {}
    for key, path in [("html", result.html_path), ("xml", result.xml_path), ("csv", result.csv_path)]:
        if path and pathlib.Path(path).exists():
            files[key] = {"path": path, "size_bytes": pathlib.Path(path).stat().st_size}
    return {
        "run_id": run_id,
        "metrics": json.loads(result.metrics_json),
        "trades": json.loads(result.trades_json),
        "files": files,
    }


def _report_response(path: str | None, media_type: str, filename: str) -> Response:
    if not path or not pathlib.Path(path).exists():
        raise HTTPException(status_code=404, detail=f"Report file not found: {filename}")
    data = pathlib.Path(path).read_bytes()
    return Response(
        content=data,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/{run_id}/report/html", dependencies=[Depends(require_auth)])
async def download_html_report(run_id: int, db: AsyncSession = Depends(get_db)):
    result = await backtest_controller.get_result(db, run_id)
    if not result:
        raise HTTPException(status_code=404, detail="Result not found")
    return _report_response(result.html_path, "text/html", f"report_{run_id}.html")


@router.get("/{run_id}/report/excel", dependencies=[Depends(require_auth)])
async def download_excel_report(run_id: int, db: AsyncSession = Depends(get_db)):
    result = await backtest_controller.get_result(db, run_id)
    if not result:
        raise HTTPException(status_code=404, detail="Result not found")
    return _report_response(
        result.xml_path,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        f"report_{run_id}.xml",
    )


@router.get("/{run_id}/report/csv", dependencies=[Depends(require_auth)])
async def download_csv_report(run_id: int, db: AsyncSession = Depends(get_db)):
    result = await backtest_controller.get_result(db, run_id)
    if not result:
        raise HTTPException(status_code=404, detail="Result not found")
    return _report_response(result.csv_path, "text/csv", f"ledger_{run_id}.csv")


@router.delete("/{run_id}/cancel", dependencies=[Depends(require_auth)])
async def cancel_backtest(run_id: int):
    cancelled = await backtest_controller.cancel_backtest(run_id)
    return {"cancelled": cancelled, "run_id": run_id}


@router.get("/history", dependencies=[Depends(require_auth)])
async def get_history(skip: int = 0, limit: int = 50, db: AsyncSession = Depends(get_db)):
    runs = await backtest_controller.get_history(db, skip=skip, limit=limit)
    return [
        {
            "run_id": r.id,
            "ea_id": r.ea_id,
            "status": r.status,
            "parameters": json.loads(r.parameters_json),
            "started_at": str(r.started_at) if r.started_at else None,
            "finished_at": str(r.finished_at) if r.finished_at else None,
        }
        for r in runs
    ]
