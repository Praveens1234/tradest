"""Watch exports/<run_id>/ for MT5 report files via watchdog."""
import asyncio
import pathlib
import logging
from typing import Callable, Awaitable
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

logger = logging.getLogger(__name__)


class _ReportHandler(FileSystemEventHandler):
    def __init__(self, run_dir: pathlib.Path, loop: asyncio.AbstractEventLoop, queue: asyncio.Queue):
        self._run_dir = run_dir
        self._loop = loop
        self._queue = queue
        self._found_html = False
        self._found_xml = False

    def on_created(self, event):
        if event.is_directory:
            return
        p = pathlib.Path(event.src_path)
        if p.suffix.lower() == ".html":
            self._found_html = True
        elif p.suffix.lower() == ".xml":
            self._found_xml = True

        if self._found_html and self._found_xml:
            self._loop.call_soon_threadsafe(
                self._queue.put_nowait,
                {"html": str(p.parent / "report.html"), "xml": str(p.parent / "report.xml")},
            )

    def on_modified(self, event):
        self.on_created(event)


async def watch_exports(run_id: int, exports_dir: str, timeout: int = 3600) -> dict | None:
    """Watch for both HTML and XML report files. Returns paths dict or None on timeout."""
    run_dir = pathlib.Path(exports_dir) / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)

    # Check if files already exist (race condition guard)
    html_path = run_dir / "report.html"
    xml_path = run_dir / "report.xml"
    if html_path.exists() and xml_path.exists():
        return {"html": str(html_path), "xml": str(xml_path)}

    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()

    handler = _ReportHandler(run_dir, loop, queue)
    observer = Observer()
    observer.schedule(handler, str(run_dir), recursive=False)
    observer.start()

    try:
        result = await asyncio.wait_for(queue.get(), timeout=timeout)
        return result
    except asyncio.TimeoutError:
        logger.warning("Watchdog timed out waiting for reports (run #%d)", run_id)
        return None
    finally:
        observer.stop()
        observer.join()
