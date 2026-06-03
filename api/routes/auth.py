"""Authentication endpoint."""
import bcrypt
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, status
from jose import jwt
from pydantic import BaseModel
from config import settings

router = APIRouter()


class LoginRequest(BaseModel):
    api_key: str


class LoginResponse(BaseModel):
    token: str
    expires_in: int


@router.post("/auth/login", response_model=LoginResponse)
async def login(req: LoginRequest) -> LoginResponse:
    if not settings.api_key_hash:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="API key not configured")
    try:
        valid = bcrypt.checkpw(req.api_key.encode(), settings.api_key_hash.encode())
    except Exception:
        valid = False
    if not valid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")

    expiry = datetime.utcnow() + timedelta(hours=settings.jwt_expiry_hours)
    token = jwt.encode(
        {"sub": "user", "exp": expiry},
        settings.jwt_secret,
        algorithm="HS256",
    )
    return LoginResponse(token=token, expires_in=settings.jwt_expiry_hours * 3600)
