"""Entry point: starts the MT5 EA Platform server."""
import sys
import secrets
import pathlib
import logging
import argparse
import asyncio

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


def _generate_api_key() -> None:
    """Generate a new API key, hash it, and persist to .env."""
    from passlib.context import CryptContext
    from config import settings

    raw_key = secrets.token_urlsafe(32)
    ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
    hashed = ctx.hash(raw_key)

    env_path = pathlib.Path(".env")
    if env_path.exists():
        lines = env_path.read_text(encoding="utf-8").splitlines()
        new_lines = []
        replaced = False
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

    print("\n" + "=" * 60)
    print("  API KEY GENERATED (shown once — copy it now):")
    print(f"  {raw_key}")
    print("=" * 60 + "\n")


def _detect_mt5() -> None:
    from core.setup.mt5_detector import detect
    from config import settings

    paths = detect()
    if not paths:
        logger.warning("MT5 not detected. Set TERMINAL_PATH and METAEDITOR_PATH in .env")
        return

    logger.info("MT5 detected: terminal=%s", paths.terminal)
    env_path = pathlib.Path(".env")
    updates = {
        "TERMINAL_PATH": paths.terminal,
        "METAEDITOR_PATH": paths.metaeditor,
        "MQL5_ROOT": paths.mql5_root,
    }
    if env_path.exists():
        content = env_path.read_text(encoding="utf-8")
    else:
        content = ""

    lines = content.splitlines()
    for key, val in updates.items():
        found = False
        for i, line in enumerate(lines):
            if line.startswith(f"{key}="):
                if not line[len(key) + 1:]:  # only replace if currently empty
                    lines[i] = f"{key}={val}"
                found = True
                break
        if not found:
            lines.append(f"{key}={val}")

    env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="MT5 EA Platform")
    parser.add_argument("--setup-key", action="store_true", help="Generate a new API key")
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
    for d in ("workspace/templates", "exports", "logs", "temp"):
        pathlib.Path(d).mkdir(parents=True, exist_ok=True)

    # Auto-detect MT5 if paths not set
    from config import settings
    if not settings.terminal_path:
        _detect_mt5()
        # Reload settings after detection
        import importlib
        import config as _cfg
        importlib.reload(_cfg)

    import uvicorn
    from config import settings as s
    host = args.host or s.host
    port = args.port or s.port

    logger.info("Starting MT5 EA Platform on %s:%d", host, port)
    uvicorn.run("api.main:app", host=host, port=port, reload=False, log_level="info")


if __name__ == "__main__":
    main()
