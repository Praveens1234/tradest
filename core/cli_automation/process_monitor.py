"""Monitor a running MT5 terminal process via psutil."""
import asyncio
import logging
from typing import Callable, Awaitable
import psutil

logger = logging.getLogger(__name__)

DEFAULT_POLL_INTERVAL = 5  # seconds
DEFAULT_MAX_DURATION = 3600  # 1 hour


async def monitor_process(
    pid: int,
    run_id: int,
    status_cb: Callable[[int, dict], Awaitable[None]],
    max_duration: int = DEFAULT_MAX_DURATION,
    poll_interval: int = DEFAULT_POLL_INTERVAL,
) -> str:
    """Poll process until it exits or times out. Returns final status string."""
    elapsed = 0

    while elapsed < max_duration:
        if not psutil.pid_exists(pid):
            logger.info("Process PID %d exited after %ds (run #%d)", pid, elapsed, run_id)
            return "done"

        try:
            proc = psutil.Process(pid)
            info = {
                "status": "running",
                "pid": pid,
                "elapsed_s": elapsed,
                "resources": {
                    "cpu_percent": proc.cpu_percent(interval=None),
                    "memory_mb": round(proc.memory_info().rss / 1024 / 1024, 1),
                },
            }
        except psutil.NoSuchProcess:
            return "done"

        await status_cb(run_id, info)
        await asyncio.sleep(poll_interval)
        elapsed += poll_interval

    # Timeout — kill the process
    logger.warning("Backtest PID %d exceeded max duration %ds. Killing.", pid, max_duration)
    try:
        proc = psutil.Process(pid)
        proc.kill()
    except psutil.NoSuchProcess:
        pass
    return "failed"
