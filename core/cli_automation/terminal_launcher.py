"""Launch MT5 terminal64.exe with a config INI file."""
import subprocess
import logging
from config import settings

logger = logging.getLogger(__name__)


def launch_terminal(ini_path: str) -> subprocess.Popen:
    """Start terminal64.exe /config:<ini_path> and return the Popen handle."""
    if not settings.terminal_path:
        raise RuntimeError("terminal_path not configured")

    cmd = [settings.terminal_path, f"/config:{ini_path}"]
    logger.info("Launching MT5 terminal: %s", " ".join(cmd))

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, "CREATE_NO_WINDOW") else 0,
    )
    return proc
