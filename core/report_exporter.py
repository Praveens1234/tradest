"""Capture and manage backtest report files (HTML + XML)."""
import shutil
import pathlib
import logging

logger = logging.getLogger(__name__)


async def capture_reports(run_id: int, html_src: str, xml_src: str, exports_dir: str) -> dict:
    """Ensure reports are in exports/<run_id>/ and return their paths."""
    run_dir = pathlib.Path(exports_dir) / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)

    result = {}

    for src, filename in ((html_src, "report.html"), (xml_src, "report.xml")):
        if not src:
            continue
        src_p = pathlib.Path(src)
        if not src_p.exists():
            logger.warning("Report file not found: %s", src)
            continue
        dest = run_dir / filename
        if src_p.resolve() != dest.resolve():
            shutil.copy2(str(src_p), str(dest))
        key = "html" if filename.endswith(".html") else "xml"
        result[key] = str(dest)

    return result
