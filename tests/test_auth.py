"""Authentication endpoint and middleware tests."""
import secrets
import pytest
import bcrypt


@pytest.mark.anyio
async def test_login_success(client, raw_api_key):
    r = await client.post("/auth/login", json={"api_key": raw_api_key})
    assert r.status_code == 200
    data = r.json()
    assert "token" in data
    assert data["expires_in"] == 86400  # 24 hours
    assert len(data["token"]) > 20


@pytest.mark.anyio
async def test_login_wrong_key(client):
    r = await client.post("/auth/login", json={"api_key": "wrong_key_xyz"})
    assert r.status_code == 401
    assert "Invalid" in r.json()["detail"]


@pytest.mark.anyio
async def test_login_no_key_configured(client, monkeypatch):
    import config as cfg
    monkeypatch.setattr(cfg.settings, "api_key_hash", "")
    r = await client.post("/auth/login", json={"api_key": "anything"})
    assert r.status_code == 503


@pytest.mark.anyio
async def test_bearer_jwt_auth(client, raw_api_key):
    # Get JWT
    r = await client.post("/auth/login", json={"api_key": raw_api_key})
    assert r.status_code == 200
    token = r.json()["token"]
    # Use JWT on a protected endpoint
    r = await client.get("/ea/list", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200


@pytest.mark.anyio
async def test_api_key_header_auth(authed_client):
    r = await authed_client.get("/ea/list")
    assert r.status_code == 200


@pytest.mark.anyio
async def test_invalid_jwt(client):
    r = await client.get("/ea/list", headers={"Authorization": "Bearer garbage.invalid.token"})
    assert r.status_code == 401


@pytest.mark.anyio
async def test_missing_auth(client):
    r = await client.get("/ea/list")
    assert r.status_code == 401
    assert r.headers.get("WWW-Authenticate") == "Bearer"


@pytest.mark.anyio
async def test_expired_jwt_rejected(client, monkeypatch):
    from datetime import datetime, timedelta
    from jose import jwt
    import config as cfg

    # Create an already-expired token
    exp = datetime.utcnow() - timedelta(hours=1)
    token = jwt.encode({"sub": "user", "exp": exp}, cfg.settings.jwt_secret, algorithm="HS256")
    r = await client.get("/ea/list", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 401
