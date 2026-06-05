"""EA CRUD, upload, compile and log endpoint tests."""
import io
import pytest


@pytest.mark.anyio
async def test_create_ea(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "MyEA", "content": "int x=1;", "type": "mq5"})
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "MyEA"
    assert data["type"] == "mq5"
    assert "id" in data
    assert "path" in data


@pytest.mark.anyio
async def test_create_ea_duplicate(authed_client, workspace):
    await authed_client.post("/ea/create", json={"name": "DupEA", "content": "x", "type": "mq5"})
    r = await authed_client.post("/ea/create", json={"name": "DupEA", "content": "y", "type": "mq5"})
    assert r.status_code == 409


@pytest.mark.anyio
async def test_list_eas(authed_client, workspace):
    await authed_client.post("/ea/create", json={"name": "EA1", "content": "x", "type": "mq5"})
    await authed_client.post("/ea/create", json={"name": "EA2", "content": "y", "type": "mq5"})
    r = await authed_client.get("/ea/list")
    assert r.status_code == 200
    names = [e["name"] for e in r.json()]
    assert "EA1" in names
    assert "EA2" in names


@pytest.mark.anyio
async def test_get_ea(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "GetEA", "content": "int x=42;", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.get(f"/ea/{ea_id}")
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "GetEA"
    assert data["content"] == "int x=42;"


@pytest.mark.anyio
async def test_get_ea_not_found(authed_client):
    r = await authed_client.get("/ea/99999")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_update_ea(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "UpdEA", "content": "int x=1;", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.put(f"/ea/{ea_id}", json={"content": "int x=999;"})
    assert r.status_code == 200
    # Read back and verify
    r2 = await authed_client.get(f"/ea/{ea_id}")
    assert r2.json()["content"] == "int x=999;"


@pytest.mark.anyio
async def test_update_ea_not_found(authed_client):
    r = await authed_client.put("/ea/99999", json={"content": "x"})
    assert r.status_code == 404


@pytest.mark.anyio
async def test_delete_ea(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "DelEA", "content": "x", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.delete(f"/ea/{ea_id}")
    assert r.status_code == 200
    assert r.json()["deleted"] is True
    r = await authed_client.get(f"/ea/{ea_id}")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_delete_ea_not_found(authed_client):
    r = await authed_client.delete("/ea/99999")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_upload_ea_multipart(authed_client, workspace):
    content = b"int OnInit(){return 0;}"
    r = await authed_client.post(
        "/ea/upload",
        files={"file": ("UploadedEA.mq5", io.BytesIO(content), "text/plain")},
    )
    assert r.status_code == 200
    data = r.json()
    assert "id" in data
    assert "UploadedEA" in data["name"]


@pytest.mark.anyio
async def test_upload_ea_conflict(authed_client, workspace):
    content = b"int OnInit(){return 0;}"
    await authed_client.post(
        "/ea/upload",
        files={"file": ("ConflictEA.mq5", io.BytesIO(content), "text/plain")},
    )
    r = await authed_client.post(
        "/ea/upload",
        files={"file": ("ConflictEA.mq5", io.BytesIO(content), "text/plain")},
    )
    assert r.status_code == 409


@pytest.mark.anyio
async def test_compile_ea_no_metaeditor(authed_client, workspace, monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "metaeditor_path", "")
    r = await authed_client.post("/ea/create", json={"name": "CompEA", "content": "int x=1;", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.post(f"/ea/{ea_id}/compile")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "error"
    assert "MetaEditor" in data["raw_log"]


@pytest.mark.anyio
async def test_compile_ea_bad_path(authed_client, workspace, monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "metaeditor_path", "/nonexistent/metaeditor64.exe")
    r = await authed_client.post("/ea/create", json={"name": "BadPathEA", "content": "int x=1;", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.post(f"/ea/{ea_id}/compile")
    assert r.status_code == 200
    assert r.json()["status"] == "error"


@pytest.mark.anyio
async def test_compile_logs_empty(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "LogEA", "content": "x", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.get(f"/ea/{ea_id}/compile/logs")
    assert r.status_code == 200
    assert r.json() == []


@pytest.mark.anyio
async def test_last_compile_log_not_found(authed_client, workspace):
    r = await authed_client.post("/ea/create", json={"name": "NoLogEA", "content": "x", "type": "mq5"})
    ea_id = r.json()["id"]
    r = await authed_client.get(f"/ea/{ea_id}/compile/logs/last")
    assert r.status_code == 404


@pytest.mark.anyio
async def test_compile_then_logs(authed_client, workspace, monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "metaeditor_path", "")
    r = await authed_client.post("/ea/create", json={"name": "LoggedEA", "content": "int x=1;", "type": "mq5"})
    ea_id = r.json()["id"]
    await authed_client.post(f"/ea/{ea_id}/compile")
    r = await authed_client.get(f"/ea/{ea_id}/compile/logs")
    assert r.status_code == 200
    assert len(r.json()) == 1
    # Also test last log endpoint
    r = await authed_client.get(f"/ea/{ea_id}/compile/logs/last")
    assert r.status_code == 200
    assert r.json()["status"] == "error"
