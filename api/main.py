"""FastAPI application: REST API + WebSocket + static Web UI."""
import json
import pathlib
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from db.database import init_db
from api.routes.auth import router as auth_router
from api.routes.ea import router as ea_router
from api.routes.files import router as files_router
from api.routes.backtest import router as backtest_router
from api.routes.usage import router as usage_router
from api.routes.logs import router as logs_router
from api.websockets.compile_ws import compile_manager
from api.websockets.backtest_ws import backtest_manager
from api.websockets.upload_ws import upload_manager
from api.websockets.logs_ws import logs_manager


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    from core.log_registry import setup_log_registry
    setup_log_registry()
    yield


app = FastAPI(
    title="MT5 EA Platform",
    description="MetaTrader 5 EA Automation Platform API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,   # API uses X-API-Key / Bearer, not cookies
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# API routes
app.include_router(auth_router)
app.include_router(ea_router, prefix="/ea", tags=["EA"])
app.include_router(files_router, prefix="/files", tags=["Files"])
app.include_router(backtest_router, prefix="/backtest", tags=["Backtest"])
app.include_router(usage_router, tags=["Usage"])
app.include_router(logs_router, tags=["Logs"])


# WebSocket endpoints
@app.websocket("/ws/compile/{ea_id}")
async def ws_compile(ws: WebSocket, ea_id: int):
    key = str(ea_id)
    await compile_manager.connect(key, ws)
    try:
        while True:
            await ws.receive_text()  # keep alive
    except WebSocketDisconnect:
        compile_manager.disconnect(key, ws)


@app.websocket("/ws/backtest/{run_id}")
async def ws_backtest(ws: WebSocket, run_id: int):
    key = str(run_id)
    await backtest_manager.connect(key, ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        backtest_manager.disconnect(key, ws)


@app.websocket("/ws/upload/{upload_id}")
async def ws_upload(ws: WebSocket, upload_id: str):
    await upload_manager.connect(upload_id, ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        upload_manager.disconnect(upload_id, ws)


@app.websocket("/ws/logs")
async def ws_logs(ws: WebSocket):
    await logs_manager.connect(ws)
    try:
        while True:
            await ws.receive_text()  # keep-alive
    except WebSocketDisconnect:
        logs_manager.disconnect(ws)


# Serve built React SPA at "/"
_dist = pathlib.Path(__file__).parent.parent / "web_ui_dist"
if _dist.exists():
    app.mount("/", StaticFiles(directory=str(_dist), html=True), name="spa")
