"""Shared fixtures for all test modules."""
import sys
import pathlib
import secrets
import asyncio
import pytest
import bcrypt

_ROOT = pathlib.Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


def pytest_configure(config):
    config.addinivalue_line("markers", "anyio: mark test as async")


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest.fixture(autouse=True)
def patch_db(tmp_path_factory, monkeypatch):
    """Give each test an isolated SQLite database file."""
    db_file = tmp_path_factory.mktemp("db") / "test.db"
    monkeypatch.setattr("config.settings.db_path", str(db_file))

    import db.database as _db_mod
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
    from sqlalchemy import event as sa_event
    from db.models import Base

    new_engine = create_async_engine(
        f"sqlite+aiosqlite:///{db_file}",
        connect_args={"check_same_thread": False},
    )

    def _set_wal(dbapi_conn, _cr):
        dbapi_conn.execute("PRAGMA journal_mode=WAL")
        dbapi_conn.execute("PRAGMA foreign_keys=ON")

    sa_event.listen(new_engine.sync_engine, "connect", _set_wal)
    monkeypatch.setattr(_db_mod, "engine", new_engine)
    monkeypatch.setattr(
        _db_mod,
        "AsyncSessionLocal",
        async_sessionmaker(bind=new_engine, class_=AsyncSession, expire_on_commit=False),
    )

    async def _init():
        async with new_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    # asyncio.run() creates its own loop — safe regardless of existing loop state
    asyncio.run(_init())


@pytest.fixture()
def raw_api_key(monkeypatch):
    """Generate a test API key and patch settings."""
    import config as cfg
    key = secrets.token_urlsafe(32)
    hashed = bcrypt.hashpw(key.encode(), bcrypt.gensalt()).decode()
    monkeypatch.setattr(cfg.settings, "api_key_hash", hashed)
    return key


@pytest.fixture()
def auth_headers(raw_api_key):
    return {"X-API-Key": raw_api_key}


@pytest.fixture()
async def client(raw_api_key):
    from httpx import AsyncClient, ASGITransport
    from api.main import app
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture()
async def authed_client(raw_api_key):
    from httpx import AsyncClient, ASGITransport
    from api.main import app
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"X-API-Key": raw_api_key},
    ) as c:
        yield c


@pytest.fixture()
def workspace(tmp_path, monkeypatch):
    """Isolated workspace directory for file operations."""
    import config as cfg
    ws = tmp_path / "workspace"
    ws.mkdir()
    monkeypatch.setattr(cfg.settings, "workspace_dir", str(ws))
    monkeypatch.setattr(cfg.settings, "mql5_root", "")
    return ws
