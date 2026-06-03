"""PowerShell runner with shutil/os fallback."""
import subprocess
import shutil
import logging

logger = logging.getLogger(__name__)

# Detected at module import time
_PWSH_AVAILABLE: bool = bool(shutil.which("pwsh") or shutil.which("powershell"))


def pwsh_available() -> bool:
    return _PWSH_AVAILABLE


def run_pwsh(script: str, timeout: int = 30) -> dict:
    """Run a PowerShell script and return stdout/stderr/code."""
    exe = shutil.which("pwsh") or shutil.which("powershell")
    if not exe:
        return {"stdout": "", "stderr": "PowerShell not available", "code": -1}
    try:
        result = subprocess.run(
            [exe, "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {"stdout": result.stdout, "stderr": result.stderr, "code": result.returncode}
    except subprocess.TimeoutExpired:
        return {"stdout": "", "stderr": "PowerShell command timed out", "code": -2}
    except Exception as exc:
        return {"stdout": "", "stderr": str(exc), "code": -3}
