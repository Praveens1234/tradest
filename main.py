"""Entry point: starts the MT5 EA Platform server."""
import sys
import secrets
import pathlib
import logging
import argparse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


def _generate_api_key() -> None:
    """Generate a new API key, hash it, persist to .env, and print both values."""
    import bcrypt

    raw_key = secrets.token_urlsafe(32)
    hashed  = bcrypt.hashpw(raw_key.encode(), bcrypt.gensalt()).decode()

    env_path = pathlib.Path(".env")
    if env_path.exists():
        lines    = env_path.read_text(encoding="utf-8").splitlines()
        new_lines = []
        replaced  = False
        for line in lines:
            if line.startswith("API_KEY_HASH="):
                new_lines.append(f"API_KEY_HASH={hashed}")
                replaced = True
            else:
                new_lines.append(line)
        if not replaced:
            new_lines.append(f"API_KEY_HASH={hashed}")
        env_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    else:
        env_path.write_text(f"API_KEY_HASH={hashed}\n", encoding="utf-8")

    # Print in a format that setup.ps1 can parse
    print()
    print("=" * 64)
    print("  API KEY GENERATED — copy both values below:")
    print("=" * 64)
    print(f"  Raw key : {raw_key}")
    print(f"  Hash    : {hashed}")
    print("=" * 64)
    print()


def _detect_mt5() -> None:
    """Auto-detect MT5 installation, write paths to .env, and print results."""
    from core.setup.mt5_detector import detect

    paths = detect()
    if not paths:
        logger.warning("MT5 not detected. Set TERMINAL_PATH and METAEDITOR_PATH in .env manually.")
        print("MT5_DETECTION=not_found")
        return

    logger.info("MT5 detected: terminal=%s", paths.terminal)

    env_path = pathlib.Path(".env")
    updates  = {
        "TERMINAL_PATH":   paths.terminal,
        "METAEDITOR_PATH": paths.metaeditor,
        "MQL5_ROOT":       paths.mql5_root,
    }
    content = env_path.read_text(encoding="utf-8") if env_path.exists() else ""
    lines   = content.splitlines()

    for key, val in updates.items():
        found = False
        for i, line in enumerate(lines):
            if line.startswith(f"{key}="):
                if not line[len(key) + 1:].strip():  # only replace if currently empty
                    lines[i] = f"{key}={val}"
                found = True
                break
        if not found:
            lines.append(f"{key}={val}")

    env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # Print in parseable format for setup.ps1
    print(f"TERMINAL_PATH={paths.terminal}")
    print(f"METAEDITOR_PATH={paths.metaeditor}")
    print(f"MQL5_ROOT={paths.mql5_root}")


def main() -> None:
    parser = argparse.ArgumentParser(description="MT5 EA Platform")
    parser.add_argument("--setup-key",  action="store_true", help="Generate a new API key")
    parser.add_argument("--detect-mt5", action="store_true", help="Run MT5 auto-detection")
    parser.add_argument("--host", default=None)
    parser.add_argument("--port", type=int, default=None)
    args = parser.parse_args()

    if args.setup_key:
        _generate_api_key()
        sys.exit(0)

    if args.detect_mt5:
        _detect_mt5()
        sys.exit(0)

    # Ensure required directories exist
    for d in ("workspace/Experts", "workspace/Include", "workspace/templates", "exports", "logs", "temp"):
        pathlib.Path(d).mkdir(parents=True, exist_ok=True)

    # Auto-detect MT5 if paths not set
    from config import settings
    if not settings.terminal_path:
        _detect_mt5()
        # Update settings in-place so uvicorn picks up the new paths
        from core.setup.mt5_detector import detect as _detect_fn
        _found = _detect_fn()
        if _found:
            settings.terminal_path   = _found.terminal
            settings.metaeditor_path = _found.metaeditor
            settings.mql5_root       = _found.mql5_root

    import uvicorn
    host = args.host or settings.host
    port = args.port or settings.port

    logger.info("Starting MT5 EA Platform on %s:%d", host, port)
    uvicorn.run("api.main:app", host=host, port=port, reload=False, log_level="info")


if __name__ == "__main__":
    main()
