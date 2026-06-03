"""5-tier MT5 installation detector."""
import os
import sys
import glob
import pathlib
import subprocess
from dataclasses import dataclass


@dataclass
class MT5Paths:
    terminal: str
    metaeditor: str
    mql5_root: str


def _validate(terminal: str, metaeditor: str) -> bool:
    return (
        os.path.isfile(terminal)
        and os.path.isfile(metaeditor)
        and os.access(terminal, os.X_OK)
        and os.access(metaeditor, os.X_OK)
    )


def _find_mql5_root(terminal_dir: str) -> str:
    """Derive MQL5 data folder from terminal directory."""
    # MT5 stores data in %APPDATA%\MetaQuotes\Terminal\<instance_id>\MQL5\
    appdata = os.environ.get("APPDATA", "")
    if appdata:
        base = pathlib.Path(appdata) / "MetaQuotes" / "Terminal"
        if base.exists():
            for instance_dir in base.iterdir():
                if instance_dir.is_dir():
                    mql5 = instance_dir / "MQL5"
                    if mql5.exists():
                        return str(mql5)
    # Fallback: MQL5 folder inside terminal directory
    candidate = pathlib.Path(terminal_dir) / "MQL5"
    candidate.mkdir(parents=True, exist_ok=True)
    return str(candidate)


def _make_paths(install_dir: str) -> MT5Paths | None:
    terminal = os.path.join(install_dir, "terminal64.exe")
    metaeditor = os.path.join(install_dir, "metaeditor64.exe")
    if not _validate(terminal, metaeditor):
        return None
    return MT5Paths(
        terminal=terminal,
        metaeditor=metaeditor,
        mql5_root=_find_mql5_root(install_dir),
    )


def _tier1_registry() -> MT5Paths | None:
    """Windows Registry scan."""
    if sys.platform != "win32":
        return None
    try:
        import winreg
        for hive in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
            for subkey in (
                r"SOFTWARE\MetaQuotes\MetaTrader 5",
                r"SOFTWARE\WOW6432Node\MetaQuotes\MetaTrader 5",
            ):
                try:
                    with winreg.OpenKey(hive, subkey) as key:
                        install_dir, _ = winreg.QueryValueEx(key, "Path")
                        result = _make_paths(str(install_dir))
                        if result:
                            return result
                except OSError:
                    continue
    except ImportError:
        pass
    return None


def _tier2_known_paths() -> MT5Paths | None:
    """Known standard installation paths."""
    candidates = [
        r"C:\Program Files\MetaTrader 5",
        r"C:\Program Files (x86)\MetaTrader 5",
        r"C:\MT5",
        r"C:\MetaTrader 5",
    ]
    # Also check broker-named folders on C:\
    if sys.platform == "win32":
        try:
            for item in pathlib.Path("C:\\").iterdir():
                if item.is_dir() and "metatrader" in item.name.lower():
                    candidates.append(str(item))
        except (OSError, PermissionError):
            pass

    for path in candidates:
        result = _make_paths(path)
        if result:
            return result
    return None


def _tier3_appdata() -> MT5Paths | None:
    """AppData and LocalAppData scan."""
    appdata_dirs = []
    for var in ("APPDATA", "LOCALAPPDATA"):
        val = os.environ.get(var, "")
        if val:
            appdata_dirs.append(val)

    for base in appdata_dirs:
        candidates = [
            os.path.join(base, "MetaQuotes", "Terminal"),
        ]
        for candidate in candidates:
            if os.path.isdir(candidate):
                for instance in pathlib.Path(candidate).iterdir():
                    if instance.is_dir():
                        result = _make_paths(str(instance))
                        if result:
                            return result
    return None


def _tier4_path_env() -> MT5Paths | None:
    """PATH environment variable scan."""
    path_env = os.environ.get("PATH", "")
    for dir_path in path_env.split(os.pathsep):
        result = _make_paths(dir_path)
        if result:
            return result
    return None


def _tier5_glob_scan() -> MT5Paths | None:
    """Depth-limited glob scan from C:\\ (Windows only)."""
    if sys.platform != "win32":
        return None
    search_roots = ["C:\\"]
    for root in search_roots:
        try:
            pattern = os.path.join(root, "**", "terminal64.exe")
            matches = glob.glob(pattern, recursive=True)
            for match in matches[:20]:  # limit scan results
                install_dir = os.path.dirname(match)
                result = _make_paths(install_dir)
                if result:
                    return result
        except (OSError, PermissionError):
            continue
    return None


def detect() -> MT5Paths | None:
    """Run all 5 detection tiers in priority order."""
    for tier_fn in (_tier1_registry, _tier2_known_paths, _tier3_appdata, _tier4_path_env, _tier5_glob_scan):
        result = tier_fn()
        if result:
            return result
    return None
