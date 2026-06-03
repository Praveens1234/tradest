"""Auth middleware: validates both Bearer JWT and X-API-Key headers."""
from fastapi import Header, Depends, HTTPException, status
from jose import JWTError, jwt
from passlib.context import CryptContext
from config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def _verify_api_key(raw_key: str) -> bool:
    if not settings.api_key_hash:
        return False
    try:
        return pwd_context.verify(raw_key, settings.api_key_hash)
    except Exception:
        return False


def _verify_jwt(token: str) -> bool:
    try:
        jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        return True
    except JWTError:
        return False


async def require_auth(
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
    authorization: str | None = Header(default=None),
) -> str:
    # Bearer JWT (Web UI session token)
    if authorization and authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ")
        if _verify_jwt(token):
            return "jwt"

    # X-API-Key header (direct API / MCP / Flutter)
    if x_api_key and _verify_api_key(x_api_key):
        return "api_key"

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing authentication",
        headers={"WWW-Authenticate": "Bearer"},
    )
