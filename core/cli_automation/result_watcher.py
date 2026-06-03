"""Watch exports/<run_id>/ for MT5 report files via watchdog."""
import asyncio
import pathlib
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

logger = logging.getLogger(__name__)


class _ReportHandler(FileSystemEventHandler):
    def __init__(self, run_dir: pathlib.Path, loop: asyncio.AbstractEventLoop, queue: asyncio.Queue):
        self._run_dir = run_dir
        self._loop = loop
        self._queue = queue
        self._html_path: str | None = None
        self._xml_path: str | None = None
        self._notified = False

    def _check_and_notify(self):
        if self._notified:
            return
        if self._html_path and self._xml_path:
            self._notified = True
            self._loop.call_soon_threadsafe(
                self._queue.put_nowait,
                {"html": self._html_path, "xml": self._xml_path},
            )

    def on_closed(self, event):
        if event.is_directory:
            return
        p = pathlib.Path(event.src_path)
        if p.suffix.lower() == ".html":
            self._html_path = str(p)
        elif p.suffix.lower() == ".xml":
            self._xml_path = str(p)
        self._check_and_notify()

    def on_created(self, event):
        # Fallback for platforms that don't emit on_closed
        if event.is_directory:
            return
        p = pathlib.Path(event.src_path)
        if p.suffix.lower() == ".html" and not self._html_path:
            self._html_path = str(p)
        elif p.suffix.lower() == ".xml" and not self._xml_path:
            self._xml_path = str(p)
        self._check_and_notify()


async def watch_exports(run_id: int, exports_dir: str, timeout: int = 3600) -> dict | None:
    """Watch for both HTML and XML report files. Returns paths dict or None on timeout."""
    run_dir = pathlib.Path(exports_dir) / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)

    # Check if files already exist (race condition guard)
    existing_html = next(run_dir.glob("*.html"), None)
    existing_xml = next(run_dir.glob("*.xml"), None)
    if existing_html and existing_xml:
        return {"html": str(existing_html), "xml": str(existing_xml)}

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
