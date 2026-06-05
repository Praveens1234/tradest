"""Usage events, health check, and filtering tests."""
import asyncio
import pytest


@pytest.mark.anyio
async def test_health_no_auth(client):
    """Health endpoint is public — no auth required."""
    r = await client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert "status" in data
    assert data["status"] in ("ok", "degraded")
    assert "terminal_ok" in data
    assert "metaeditor_ok" in data
    assert "mql5_ok" in data
    assert "cpu_percent" in data
    assert "memory_mb" in data


@pytest.mark.anyio
async def test_health_degraded_without_mt5(client, monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "terminal_path", "")
    monkeypatch.setattr(cfg.settings, "metaeditor_path", "")
    monkeypatch.setattr(cfg.settings, "mql5_root", "")
    r = await client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "degraded"


@pytest.mark.anyio
async def test_usage_events_empty(authed_client):
    r = await authed_client.get("/usage/events")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.anyio
async def test_usage_events_after_activity(authed_client, workspace):
    # Trigger some activity
    await authed_client.post("/ea/create", json={"name": "EventEA", "content": "x", "type": "mq5"})
    r = await authed_client.get("/usage/events")
    assert r.status_code == 200


@pytest.mark.anyio
async def test_usage_events_limit(authed_client):
    r = await authed_client.get("/usage/events", params={"limit": 5})
    assert r.status_code == 200
    assert len(r.json()) <= 5


@pytest.mark.anyio
async def test_usage_events_limit_max(authed_client):
    # Over 1000 should be rejected (le=1000 constraint)
    r = await authed_client.get("/usage/events", params={"limit": 9999})
    assert r.status_code == 422


@pytest.mark.anyio
async def test_usage_events_action_filter(authed_client):
    r = await authed_client.get("/usage/events", params={"action": "nonexistent_action_xyz"})
    assert r.status_code == 200
    assert r.json() == []


@pytest.mark.anyio
async def test_usage_events_date_filter_future(authed_client):
    # Date far in the future → no events
    r = await authed_client.get("/usage/events", params={"date": "2099-01-01"})
    assert r.status_code == 200
    assert r.json() == []


@pytest.mark.anyio
async def test_usage_events_date_filter_past(authed_client, workspace):
    # Date in the past → events returned
    await authed_client.post("/ea/create", json={"name": "DateEA", "content": "x", "type": "mq5"})
    r = await authed_client.get("/usage/events", params={"date": "2000-01-01"})
    assert r.status_code == 200


@pytest.mark.anyio
async def test_usage_events_invalid_date(authed_client):
    # Invalid date string → gracefully returns events (filter ignored)
    r = await authed_client.get("/usage/events", params={"date": "not-a-date"})
    assert r.status_code == 200


@pytest.mark.anyio
async def test_usage_event_schema(authed_client):
    r = await authed_client.get("/usage/events")
    events = r.json()
    if events:
        e = events[0]
        assert "id" in e
        assert "interface" in e
        assert "action" in e
        assert "timestamp" in e
        assert "status" in e
