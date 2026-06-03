"""MT5 auto-installer: downloads mt5setup.exe and installs silently."""
import os
import pathlib
import subprocess
import tempfile
import time
import logging
import urllib.request

import psutil

from core.setup.mt5_detector import detect, MT5Paths

logger = logging.getLogger(__name__)

MT5_SETUP_URL = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"


def _download_setup(dest: str) -> bool:
    logger.info("Downloading mt5setup.exe from MetaQuotes CDN...")
    try:
        urllib.request.urlretrieve(MT5_SETUP_URL, dest)
        return True
    except Exception as exc:
        logger.error("Download failed: %s", exc)
        return False


def _run_silent_install(setup_exe: str) -> int:
    """Run mt5setup.exe /auto and return exit code."""
    try:
        result = subprocess.run(
            [setup_exe, "/auto"],
            timeout=300,
            capture_output=True,
        )
        return result.returncode
    except subprocess.TimeoutExpired:
        logger.error("MT5 silent install timed out after 5 minutes")
        return -1
    except Exception as exc:
        logger.error("Silent install failed: %s", exc)
        return -2


def _run_gui_install(setup_exe: str) -> None:
    """Launch MT5 installer in GUI mode as fallback (UAC issue)."""
    logger.warning("Silent install failed. Launching GUI installer as fallback.")
    subprocess.Popen([setup_exe])


def install_mt5() -> MT5Paths | None:
    """Download and install MT5. Returns detected paths after install."""
    with tempfile.TemporaryDirectory() as tmpdir:
        setup_path = os.path.join(tmpdir, "mt5setup.exe")

        if not _download_setup(setup_path):
            return None

        exit_code = _run_silent_install(setup_path)

        if exit_code != 0:
            _run_gui_install(setup_path)
            logger.info("Waiting for user to complete GUI installation...")
            # Wait up to 3 minutes for install to complete
            for _ in range(36):
                time.sleep(5)
                paths = detect()
                if paths:
                    return paths
            return None

        # Re-scan after silent install
        for attempt in range(6):
            time.sleep(5)
            paths = detect()
            if paths:
                logger.info("MT5 detected after install at: %s", paths.terminal)
                return paths

    return None
