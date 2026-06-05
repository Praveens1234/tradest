"""Tests for the /logs/* endpoints."""
import pytest


@pytest.mark.anyio
async def test_logs_requires_auth(client):
    r = await client.get("/logs/recent")
    assert r.status_code == 401


@pytest.mark.anyio
async def test_logs_empty(authed_client):
    r = await authed_client.get("/logs/recent")
    assert r.status_code == 200
    assert r.json() == []


@pytest.mark.anyio
async def test_logs_limit_param(authed_client):
    r = await authed_client.get("/logs/recent?limit=5")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.anyio
async def test_logs_level_filter(authed_client, db_log_entries):
    r = await authed_client.get("/logs/recent?level=ERROR")
    assert r.status_code == 200
    data = r.json()
    assert all(e["level"] == "ERROR" for e in data)


@pytest.mark.anyio
async def test_logs_logger_filter(authed_client, db_log_entries):
    r = await authed_client.get("/logs/recent?logger=core")
    assert r.status_code == 200
    data = r.json()
    assert all("core" in e["logger_name"] for e in data)


@pytest.mark.anyio
async def test_logs_response_shape(authed_client, db_log_entries):
    r = await authed_client.get("/logs/recent?limit=1")
    data = r.json()
    if data:
        entry = data[0]
        assert "id" in entry
        assert "level" in entry
        assert "logger_name" in entry
        assert "message" in entry
        assert "timestamp" in entry
        assert "context" in entry


@pytest.mark.anyio
async def test_logs_clear(authed_client, db_log_entries):
    r = await authed_client.delete("/logs/clear")
    assert r.status_code == 200
    assert r.json()["cleared"] is True

    r2 = await authed_client.get("/logs/recent")
    assert r2.json() == []


@pytest.mark.anyio
async def test_logs_clear_requires_auth(client):
    r = await client.delete("/logs/clear")
    assert r.status_code == 401


# ─── Fixture: pre-seed log entries ────────────────────────────────────────

@pytest.fixture()
async def db_log_entries(authed_client):
    """Seed a few PlatformLog rows directly into the test DB."""
    from db.database import AsyncSessionLocal
    from db.models import PlatformLog
    from datetime import datetime

    entries = [
        PlatformLog(level="INFO",    logger_name="core.compiler",    message="Compilation started",  context_json="{}"),
        PlatformLog(level="ERROR",   logger_name="core.backtest",    message="Backtest failed",       context_json='{"run_id": 1}'),
        PlatformLog(level="WARNING", logger_name="core.file_manager",message="File already exists",  context_json="{}"),
        PlatformLog(level="DEBUG",   logger_name="api.routes.ea",    message="EA created",           context_json="{}"),
    ]
    async with AsyncSessionLocal() as db:
        for e in entries:
            db.add(e)
        await db.commit()
    return entries
