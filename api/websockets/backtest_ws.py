"""WebSocket connection manager for live backtest status streaming."""
import asyncio
import json
import logging
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class BacktestConnectionManager:
    def __init__(self):
        self._connections: dict[str, list[WebSocket]] = {}

    async def connect(self, key: str, ws: WebSocket) -> None:
        await ws.accept()
        self._connections.setdefault(key, []).append(ws)

    def disconnect(self, key: str, ws: WebSocket) -> None:
        conns = self._connections.get(key, [])
        if ws in conns:
            conns.remove(ws)

    async def broadcast(self, key: str, data: dict) -> None:
        message = json.dumps(data)
        dead = []
        for ws in self._connections.get(key, []):
            try:
                await ws.send_text(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(key, ws)


backtest_manager = BacktestConnectionManager()
