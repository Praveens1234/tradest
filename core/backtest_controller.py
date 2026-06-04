"""Orchestrates the full backtest lifecycle end-to-end."""
import json
import asyncio
import pathlib
import logging
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.models import BacktestRun, BacktestResult
from db.database import AsyncSessionLocal
from config import settings
from core.cli_automation.ini_generator import BacktestParams, generate_ini
from core.cli_automation.terminal_launcher import launch_terminal
from core.cli_automation.process_monitor import monitor_process
from core.cli_automation.result_watcher import watch_exports
from core.cli_automation.result_parser import parse_html_report, parse_xml_report
from core.report_exporter import capture_reports
from core.ledger_exporter import export_csv
from api.websockets.backtest_ws import backtest_manager

logger = logging.getLogger(__name__)

# Active tasks: run_id → asyncio.Task
_active_tasks: dict[int, asyncio.Task] = {}

# Grace period (seconds) to wait for reports after the MT5 process exits
_REPORT_GRACE_PERIOD = 15


async def start_backtest(db: AsyncSession, params: BacktestParams, ea_id: int | None = None) -> int:
    """Create a run record and kick off the background task. Returns run_id."""
    run = BacktestRun(
        ea_id=ea_id,
        parameters_json=json.dumps(params.__dict__),
        status="pending",
        started_at=datetime.utcnow(),
    )
    db.add(run)
    await db.commit()
    await db.refresh(run)

    task = asyncio.create_task(_execute(run.id, params))
    _active_tasks[run.id] = task
    task.add_done_callback(lambda t: _active_tasks.pop(run.id, None))

    return run.id


async def cancel_backtest(run_id: int) -> bool:
    task = _active_tasks.get(run_id)
    if task:
        task.cancel()
        return True
    return False


async def get_run(db: AsyncSession, run_id: int) -> BacktestRun | None:
    return (await db.execute(select(BacktestRun).where(BacktestRun.id == run_id))).scalar_one_or_none()


async def get_history(db: AsyncSession, skip: int = 0, limit: int = 50) -> list[BacktestRun]:
    result = await db.execute(
        select(BacktestRun).order_by(BacktestRun.started_at.desc()).offset(skip).limit(limit)
    )
    return list(result.scalars().all())


async def get_result(db: AsyncSession, run_id: int) -> BacktestResult | None:
    return (await db.execute(select(BacktestResult).where(BacktestResult.run_id == run_id))).scalar_one_or_none()


async def _execute(run_id: int, params: BacktestParams) -> None:
    async with AsyncSessionLocal() as db:
        try:
            await _run(db, run_id, params)
        except asyncio.CancelledError:
            await _update_status(db, run_id, "cancelled")
            await backtest_manager.broadcast(str(run_id), {"status": "cancelled", "run_id": run_id})
        except Exception as exc:
            logger.exception("Backtest run #%d failed: %s", run_id, exc)
            await _update_status(db, run_id, "failed")
            await backtest_manager.broadcast(
                str(run_id), {"status": "failed", "run_id": run_id, "error": str(exc)}
            )


async def _run(db: AsyncSession, run_id: int, params: BacktestParams) -> None:
    if not settings.terminal_path:
        raise RuntimeError("terminal_path not configured — set TERMINAL_PATH in .env")

    # Resolve exports_dir to absolute so INI paths and watcher agree with MT5's CWD
    exports_abs = str(pathlib.Path(settings.exports_dir).resolve())

    ini_path, set_path = generate_ini(params, run_id, exports_abs)
    logger.info("Backtest run #%d — INI: %s", run_id, ini_path)

    proc = launch_terminal(ini_path)

    await _update_status(db, run_id, "running", pid=proc.pid)
    await backtest_manager.broadcast(str(run_id), {"status": "running", "pid": proc.pid, "run_id": run_id})

    async def _status_cb(rid: int, info: dict) -> None:
        await backtest_manager.broadcast(str(rid), info)

    monitor_task = asyncio.create_task(
        monitor_process(proc.pid, run_id, _status_cb, max_duration=3600)
    )
    watch_task = asyncio.create_task(
        watch_exports(run_id, exports_abs, timeout=3600)
    )

    # Wait for whichever finishes first
    done, pending = await asyncio.wait(
        {monitor_task, watch_task}, return_when=asyncio.FIRST_COMPLETED
    )

    reports = None

    # If the watch_task completed first, we have reports immediately
    if watch_task in done:
        reports = watch_task.result()
        for t in pending:
            t.cancel()
    else:
        # Process exited first — give a grace period for MT5 to finish writing report files
        logger.info(
            "Run #%d: MT5 process exited; waiting up to %ds for report files...",
            run_id, _REPORT_GRACE_PERIOD,
        )
        try:
            reports = await asyncio.wait_for(watch_task, timeout=_REPORT_GRACE_PERIOD)
        except asyncio.TimeoutError:
            logger.warning("Run #%d: no reports appeared within grace period", run_id)
            watch_task.cancel()

    if reports and reports.get("html"):
        await _finalize(db, run_id, reports)
    else:
        logger.error("Run #%d: finished without report files — marking failed", run_id)
        await _update_status(db, run_id, "failed")
        await backtest_manager.broadcast(str(run_id), {"status": "failed", "run_id": run_id})


async def _finalize(db: AsyncSession, run_id: int, reports: dict) -> None:
    html_path = reports.get("html", "")
    xml_path  = reports.get("xml", "")

    parsed: dict = {}
    if html_path and pathlib.Path(html_path).exists():
        parsed = parse_html_report(html_path)
    elif xml_path and pathlib.Path(xml_path).exists():
        parsed = parse_xml_report(xml_path)

    metrics = parsed.get("metrics", {})
    trades  = parsed.get("trades", [])

    captured = await capture_reports(run_id, html_path, xml_path, str(pathlib.Path(settings.exports_dir).resolve()))
    csv_path = export_csv(trades, run_id, str(pathlib.Path(settings.exports_dir).resolve()))

    result = BacktestResult(
        run_id=run_id,
        metrics_json=json.dumps(metrics),
        trades_json=json.dumps(trades),
        html_path=captured.get("html"),
        xml_path=captured.get("xml"),
        csv_path=csv_path or None,
    )
    db.add(result)
    await _update_status(db, run_id, "done")
    await db.commit()
    await backtest_manager.broadcast(
        str(run_id), {"status": "done", "run_id": run_id, "metrics": metrics}
    )
    logger.info("Backtest run #%d completed successfully", run_id)


async def _update_status(db: AsyncSession, run_id: int, status: str, pid: int | None = None) -> None:
    run = await get_run(db, run_id)
    if run:
        run.status = status
        if pid is not None:
            run.pid = pid
        if status in ("done", "failed", "cancelled"):
            run.finished_at = datetime.utcnow()
        await db.commit()
