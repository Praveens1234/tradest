"""Watch exports/<run_id>/ for MT5 report files via watchdog."""
import asyncio
import pathlib
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

logger = logging.getLogger(__name__)

# MT5 creates .htm (not .html) for its HTML report and .xml for the XML report
_HTML_EXTS = {".htm", ".html"}
_XML_EXTS  = {".xml"}


class _ReportHandler(FileSystemEventHandler):
    def __init__(self, run_dir: pathlib.Path, loop: asyncio.AbstractEventLoop, queue: asyncio.Queue):
        self._run_dir = run_dir
        self._loop = loop
        self._queue = queue
        self._html_path: str | None = None
        self._xml_path:  str | None = None
        self._notified = False

    def _check_and_notify(self) -> None:
        if self._notified:
            return
        if self._html_path and self._xml_path:
            self._notified = True
            self._loop.call_soon_threadsafe(
                self._queue.put_nowait,
                {"html": self._html_path, "xml": self._xml_path},
            )
        elif self._html_path:
            # Some MT5 configurations only produce the HTML report
            self._notified = True
            self._loop.call_soon_threadsafe(
                self._queue.put_nowait,
                {"html": self._html_path, "xml": ""},
            )

    def _handle_path(self, src_path: str) -> None:
        p = pathlib.Path(src_path)
        suffix = p.suffix.lower()
        if suffix in _HTML_EXTS and not self._html_path:
            logger.debug("Watcher: HTML report detected: %s", p)
            self._html_path = str(p)
        elif suffix in _XML_EXTS and not self._xml_path:
            logger.debug("Watcher: XML report detected: %s", p)
            self._xml_path = str(p)
        self._check_and_notify()

    def on_closed(self, event):
        """Primary handler on Windows — fires when the file handle is released."""
        if not event.is_directory:
            self._handle_path(event.src_path)

    def on_created(self, event):
        """Fallback for platforms that don't emit on_closed (Linux/macOS)."""
        if not event.is_directory:
            self._handle_path(event.src_path)

    def on_modified(self, event):
        """Second fallback — catches writes that don't trigger on_created."""
        if not event.is_directory:
            self._handle_path(event.src_path)


async def watch_exports(run_id: int, exports_dir: str, timeout: int = 3600) -> dict | None:
    """Watch run directory for MT5 report files. Returns paths dict or None on timeout."""
    run_dir = pathlib.Path(exports_dir).resolve() / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)

    # Check for files that already exist (race-condition guard)
    existing_html = next(
        (f for f in run_dir.iterdir() if f.suffix.lower() in _HTML_EXTS), None
    )
    existing_xml = next(
        (f for f in run_dir.iterdir() if f.suffix.lower() in _XML_EXTS), None
    )
    if existing_html:
        logger.info("Watcher: reports already present for run #%d", run_id)
        return {"html": str(existing_html), "xml": str(existing_xml) if existing_xml else ""}

    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()

    handler  = _ReportHandler(run_dir, loop, queue)
    observer = Observer()
    observer.schedule(handler, str(run_dir), recursive=False)
    observer.start()
    logger.info("Watcher started for run #%d watching: %s", run_id, run_dir)

    try:
        result = await asyncio.wait_for(queue.get(), timeout=timeout)
        logger.info("Watcher: reports captured for run #%d: %s", run_id, result)
        return result
    except asyncio.TimeoutError:
        logger.warning("Watcher timed out for run #%d after %ds", run_id, timeout)
        return None
    finally:
        observer.stop()
        # join() is blocking — run it in a thread so we don't block the event loop
        await asyncio.to_thread(observer.join)
