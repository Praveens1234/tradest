"""Capture and manage backtest report files (HTML + XML)."""
import shutil
import pathlib
import logging

logger = logging.getLogger(__name__)


async def capture_reports(run_id: int, html_src: str, xml_src: str, exports_dir: str) -> dict:
    """Copy reports into exports/<run_id>/ with canonical names; return paths dict."""
    run_dir = pathlib.Path(exports_dir).resolve() / str(run_id)
    run_dir.mkdir(parents=True, exist_ok=True)

    result: dict = {}

    for src, dest_name, key in (
        (html_src, "report.html", "html"),
        (xml_src,  "report.xml",  "xml"),
    ):
        if not src:
            continue
        src_p = pathlib.Path(src)
        if not src_p.exists():
            logger.warning("Report file not found (will skip): %s", src)
            continue
        dest = run_dir / dest_name
        if src_p.resolve() != dest.resolve():
            shutil.copy2(str(src_p), str(dest))
            logger.debug("Copied %s → %s", src_p, dest)
        result[key] = str(dest)

    return result
