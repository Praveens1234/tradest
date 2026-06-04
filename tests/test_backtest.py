"""Backtest run, status, cancel, history and result endpoint tests."""
import asyncio
import pytest


@pytest.mark.anyio
async def test_run_backtest_with_ea_name(authed_client):
    r = await authed_client.post("/backtest/run", json={
        "ea_name": "TestEA",
        "symbol": "EURUSD",
        "period": "H1",
        "from_date": "2024.01.01",
        "to_date": "2024.06.01",
    })
    assert r.status_code == 200
    data = r.json()
    assert "run_id" in data
    assert data["status"] == "pending"


@pytest.mark.anyio
async def test_run_backtest_with_ea_id(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "BtEA", "content": "int x=1;", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.post("/backtest/run", json={"ea_id": ea_id})
    assert r.status_code == 200
    assert r.json()["run_id"] > 0


@pytest.mark.anyio
async def test_run_backtest_no_ea(authed_client):
    r = await authed_client.post("/backtest/run", json={})
    assert r.status_code == 400
    assert "ea_name" in r.json()["detail"].lower() or "required" in r.json()["detail"].lower()


@pytest.mark.anyio
async def test_status_transitions(authed_client, monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "terminal_path", "")
    r = await authed_client.post("/backtest/run", json={"ea_name": "StatusEA"})
    run_id = r.json()["run_id"]
    # Give background task time to process
    await asyncio.sleep(0.3)
    r = await authed_client.get(f"/backtest/{run_id}/status")
    assert r.status_code == 200
    data = r.json()
    assert data["run_id"] == run_id
    assert data["status"] in ("pending", "running", "failed", "done", "cancelled")


@pytest.mark.anyio
async def test_status_not_found(authed_client):
    r = await authed_client.get("/backtest/99999/status")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_cancel_backtest(authed_client):
    r = await authed_client.post("/backtest/run", json={"ea_name": "CancelEA"})
    run_id = r.json()["run_id"]
    r = await authed_client.delete(f"/backtest/{run_id}/cancel")
    assert r.status_code == 200
    data = r.json()
    assert "cancelled" in data
    assert data["run_id"] == run_id


@pytest.mark.anyio
async def test_history(authed_client):
    for i in range(3):
        await authed_client.post("/backtest/run", json={"ea_name": f"HistEA{i}"})
    r = await authed_client.get("/backtest/history")
    assert r.status_code == 200
    runs = r.json()
    assert len(runs) >= 3
    assert "run_id" in runs[0]
    assert "status" in runs[0]


@pytest.mark.anyio
async def test_history_pagination(authed_client):
    r = await authed_client.get("/backtest/history", params={"skip": 0, "limit": 2})
    assert r.status_code == 200
    assert len(r.json()) <= 2


@pytest.mark.anyio
async def test_result_not_found(authed_client):
    r = await authed_client.post("/backtest/run", json={"ea_name": "NoResultEA"})
    run_id = r.json()["run_id"]
    r = await authed_client.get(f"/backtest/{run_id}/result")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_reports_not_found(authed_client):
    r = await authed_client.post("/backtest/run", json={"ea_name": "NoReportEA"})
    run_id = r.json()["run_id"]
    r = await authed_client.get(f"/backtest/{run_id}/reports")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_report_html_not_found(authed_client):
    r = await authed_client.post("/backtest/run", json={"ea_name": "NoHtmlEA"})
    run_id = r.json()["run_id"]
    r = await authed_client.get(f"/backtest/{run_id}/report/html")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_report_csv_not_found(authed_client):
    r = await authed_client.post("/backtest/run", json={"ea_name": "NoCsvEA"})
    run_id = r.json()["run_id"]
    r = await authed_client.get(f"/backtest/{run_id}/report/csv")
    assert r.status_code == 404
