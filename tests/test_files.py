"""File Manager API tests: tree, CRUD, copy/move, upload, download, security."""
import io
import zipfile
import pytest


@pytest.mark.anyio
async def test_tree(authed_client, workspace):
    r = await authed_client.get("/files/tree")
    assert r.status_code == 200
    data = r.json()
    assert "name" in data
    assert "is_dir" in data


@pytest.mark.anyio
async def test_list_dir(authed_client, workspace):
    r = await authed_client.get("/files/list", params={"path": ""})
    assert r.status_code == 200
    assert isinstance(r.json(), list)


@pytest.mark.anyio
async def test_mkdir(authed_client, workspace):
    r = await authed_client.post("/files/mkdir", json={"path": "NewDir"})
    assert r.status_code == 200
    assert "NewDir" in r.json()["path"]


@pytest.mark.anyio
async def test_write_and_read(authed_client, workspace):
    r = await authed_client.post("/files/write", json={"path": "test.mq5", "content": "int x=5;", "override": False})
    assert r.status_code == 200
    r = await authed_client.get("/files/read", params={"path": "test.mq5"})
    assert r.status_code == 200
    assert r.json()["content"] == "int x=5;"


@pytest.mark.anyio
async def test_write_conflict(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "dup.mq5", "content": "a", "override": False})
    r = await authed_client.post("/files/write", json={"path": "dup.mq5", "content": "b", "override": False})
    assert r.status_code == 409
    data = r.json()["detail"]
    assert data["conflict"] is True
    assert "suggested_name" in data


@pytest.mark.anyio
async def test_write_override(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "ovr.mq5", "content": "a", "override": False})
    r = await authed_client.post("/files/write", json={"path": "ovr.mq5", "content": "b", "override": True})
    assert r.status_code == 200
    r2 = await authed_client.get("/files/read", params={"path": "ovr.mq5"})
    assert r2.json()["content"] == "b"


@pytest.mark.anyio
async def test_meta(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "meta.mq5", "content": "hello", "override": False})
    r = await authed_client.get("/files/meta", params={"path": "meta.mq5"})
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "meta.mq5"
    assert data["extension"] == "mq5"
    assert data["size_bytes"] == 5
    assert data["is_dir"] is False


@pytest.mark.anyio
async def test_search(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "findme.mq5", "content": "unique_token_xyz", "override": False})
    r = await authed_client.get("/files/search", params={"q": "findme"})
    assert r.status_code == 200
    names = [n["name"] for n in r.json()]
    assert "findme.mq5" in names


@pytest.mark.anyio
async def test_rename(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "before.mq5", "content": "x", "override": False})
    r = await authed_client.put("/files/rename", json={"path": "before.mq5", "new_name": "after.mq5", "override": False})
    assert r.status_code == 200
    assert "after.mq5" in r.json()["path"]


@pytest.mark.anyio
async def test_rename_conflict(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "a.mq5", "content": "x", "override": False})
    await authed_client.post("/files/write", json={"path": "b.mq5", "content": "y", "override": False})
    r = await authed_client.put("/files/rename", json={"path": "a.mq5", "new_name": "b.mq5", "override": False})
    assert r.status_code == 409


@pytest.mark.anyio
async def test_copy(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "src.mq5", "content": "orig", "override": False})
    r = await authed_client.put("/files/copy", json={"source": "src.mq5", "destination": "dst.mq5", "override": False})
    assert r.status_code == 200
    r2 = await authed_client.get("/files/read", params={"path": "dst.mq5"})
    assert r2.json()["content"] == "orig"


@pytest.mark.anyio
async def test_move(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "moveme.mq5", "content": "data", "override": False})
    r = await authed_client.put("/files/move", json={"source": "moveme.mq5", "destination": "moved.mq5", "override": False})
    assert r.status_code == 200
    r2 = await authed_client.get("/files/read", params={"path": "moved.mq5"})
    assert r2.json()["content"] == "data"
    r3 = await authed_client.get("/files/read", params={"path": "moveme.mq5"})
    assert r3.status_code == 404


@pytest.mark.anyio
async def test_delete_soft(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "trash_me.mq5", "content": "x", "override": False})
    r = await authed_client.request("DELETE", "/files/delete", json={"path": "trash_me.mq5", "soft": True})
    assert r.status_code == 200
    assert "trash" in r.json()["message"].lower()
    # File should be gone from original path
    r2 = await authed_client.get("/files/read", params={"path": "trash_me.mq5"})
    assert r2.status_code == 404


@pytest.mark.anyio
async def test_delete_hard(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "hard_del.mq5", "content": "x", "override": False})
    r = await authed_client.request("DELETE", "/files/delete", json={"path": "hard_del.mq5", "soft": False})
    assert r.status_code == 200


@pytest.mark.anyio
async def test_download(authed_client, workspace):
    await authed_client.post("/files/write", json={"path": "dl.mq5", "content": "download_me", "override": False})
    r = await authed_client.get("/files/download", params={"path": "dl.mq5"})
    assert r.status_code == 200
    assert r.content == b"download_me"


@pytest.mark.anyio
async def test_download_zip(authed_client, workspace):
    await authed_client.post("/files/mkdir", json={"path": "ZipDir"})
    await authed_client.post("/files/write", json={"path": "ZipDir/file.mq5", "content": "zipped", "override": False})
    r = await authed_client.get("/files/download-zip", params={"path": "ZipDir"})
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/zip"
    zf = zipfile.ZipFile(io.BytesIO(r.content))
    names = zf.namelist()
    assert any("file.mq5" in n for n in names)


@pytest.mark.anyio
async def test_path_traversal_read(authed_client, workspace):
    r = await authed_client.get("/files/read", params={"path": "../../etc/passwd"})
    assert r.status_code == 404


@pytest.mark.anyio
async def test_path_traversal_write(authed_client, workspace):
    r = await authed_client.post("/files/write", json={"path": "../../etc/evil.txt", "content": "pwned", "override": True})
    assert r.status_code in (400, 404)


@pytest.mark.anyio
async def test_read_not_found(authed_client, workspace):
    r = await authed_client.get("/files/read", params={"path": "does_not_exist.mq5"})
    assert r.status_code == 404


@pytest.mark.anyio
async def test_upload_file(authed_client, workspace):
    content = b"uploaded content"
    r = await authed_client.post(
        "/files/upload",
        params={"path": "", "override": "false"},
        files={"file": ("uploaded.mq5", io.BytesIO(content), "text/plain")},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["filename"] == "uploaded.mq5"
    assert data["size_bytes"] == len(content)


@pytest.mark.anyio
async def test_compile_by_path_not_registered(authed_client, workspace):
    r = await authed_client.post("/files/compile", params={"path": "unregistered.mq5"})
    assert r.status_code == 404
