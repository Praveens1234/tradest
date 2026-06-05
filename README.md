# MT5 EA Platform

**MetaTrader 5 Expert Advisor Automation Platform** — A full-stack system for managing, compiling, and backtesting MetaTrader 5 Expert Advisors via a REST API, WebSocket streams, React Web UI, and MCP (Model Context Protocol) server.

![Python 3.11+](https://img.shields.io/badge/Python-3.11%2B-blue?logo=python)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115%2B-009688?logo=fastapi)
![React 18](https://img.shields.io/badge/React-18-61DAFB?logo=react)
![SQLite](https://img.shields.io/badge/SQLite-WAL-003B57?logo=sqlite)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## Overview

The MT5 EA Platform automates the full lifecycle of MetaTrader 5 Expert Advisor development:

- **Upload & edit** `.mq5` / `.mqh` source files in a browser-based Monaco code editor
- **Compile** EAs using MetaEditor64 and view structured error/warning output in real time
- **Backtest** strategies via the MT5 Strategy Tester with live progress monitoring over WebSocket
- **Analyse results** — download HTML reports, Excel XML files, and CSV trade ledgers
- **Browse files** with a full-featured file manager (create, rename, copy, move, delete, zip download)
- **Integrate via MCP** — expose 30+ tools to AI assistants (Claude, Cursor, etc.) over stdio

---

## Features

| Feature | Description |
|---|---|
| EA Management | Create, upload, read, update, delete MQ5/MQH Expert Advisor files |
| Real-time Compile | MetaEditor64 CLI compilation with structured error/warning streaming via WebSocket |
| Backtesting | Full MT5 Strategy Tester lifecycle: INI generation → terminal launch → process monitor → report capture |
| File Manager | Tree browse, read/write, mkdir, rename, copy, move, soft-delete, ZIP download, content search |
| Dual Auth | JWT Bearer tokens (web session) + static X-API-Key (CLI/MCP/mobile) |
| MCP Server | 32+ tools over stdio for AI assistant integration (Claude, Cursor, etc.) |
| React Web UI | SPA served from the API process — Monaco editor, backtest dashboard, logs viewer, usage log |
| Centralized Log Registry | All `logging.*` calls captured to SQLite, served via REST and live WebSocket tail |
| SQLite | Zero-dependency persistence with WAL mode + async SQLAlchemy 2.0 |
| Auto-detection | 5-tier MT5 installation detection (registry → known paths → AppData → PATH → glob scan) |
| PowerShell Scripts | `setup.ps1` (one-click install + API key generation) and `start.ps1` (one-click launch) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Client Layer                         │
│  React SPA (browser)  |  MCP Client  |  REST / curl     │
└─────────┬──────────────────┬──────────────┬─────────────┘
          │ HTTP / WebSocket │ stdio        │ HTTP
          │                  │              │
┌─────────▼──────────────────▼──────────────▼─────────────┐
│              FastAPI / Uvicorn (api/main.py)              │
│                                                           │
│  ┌─────────────────┐   ┌───────────┐   ┌──────────────┐  │
│  │  REST Routes    │   │ WebSocket │   │    Auth      │  │
│  │  /auth /ea      │   │ /ws/...   │   │  JWT + Key   │  │
│  │  /files         │   │           │   │              │  │
│  │  /backtest      │   └───────────┘   └──────────────┘  │
│  │  /health /usage │                                      │
│  └────────┬────────┘                                      │
└───────────┼───────────────────────────────────────────────┘
            │
┌───────────▼───────────────────────────────────────────────┐
│                  Core Service Layer                        │
│                                                           │
│  compiler.py           ea_manager.py    backtest_ctrl.py  │
│  file_manager/         usage_store.py   report_exporter   │
│  cli_automation/       ledger_exporter  setup/            │
└───────────┬───────────────────────────────────────────────┘
            │
┌───────────▼───────────────┐      ┌────────────────────────┐
│  SQLite  (aiosqlite +     │      │  MQL5 Workspace        │
│  SQLAlchemy 2.0 async)    │      │  (file system)         │
│  EAFile | CompileLog      │      │  Experts/  MQL5/       │
│  BacktestRun | UsageEvent │      └────────────────────────┘
└───────────────────────────┘
            │
      ┌─────▼───────────┐
      │  MT5 Terminal   │
      │  terminal64.exe │
      │  metaeditor64   │
      └─────────────────┘
```

---

## Prerequisites

- **Python 3.11+**
- **Node.js 18+** (only required to build the Web UI)
- **MetaTrader 5** (Windows only; required for compile and backtest — the API itself runs cross-platform)

---

## Quick Start

### Windows (automated — recommended)

```powershell
git clone https://github.com/praveens1234/tradest.git
cd tradest

# One-click setup: installs deps, generates API key, detects MT5, creates .env
.\setup.ps1

# One-click launch (every time after setup)
.\start.ps1
```

### Manual (all platforms)

```bash
# 1. Clone
git clone https://github.com/praveens1234/tradest.git
cd tradest

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Generate an API key (shown once — save it!)
python main.py --setup-key

# 4. Configure environment
cp .env.example .env
# Edit .env and set API_KEY_HASH (from step 3 output)

# 5. Auto-detect MT5 (Windows only)
python main.py --detect-mt5

# 6. Start the server
python main.py

# Server is running at http://localhost:8000
```

---

## Environment Variables

Copy `.env.example` to `.env` and configure:

| Variable | Default | Description |
|---|---|---|
| `API_KEY_HASH` | _(empty)_ | bcrypt hash of your API key — generate with `--setup-key` |
| `JWT_SECRET` | _(auto)_ | HMAC-SHA256 secret for JWT signing; auto-generated on first run |
| `JWT_EXPIRY_HOURS` | `24` | JWT token validity window in hours |
| `HOST` | `0.0.0.0` | Server bind address |
| `PORT` | `8000` | Server listen port |
| `TERMINAL_PATH` | _(empty)_ | Absolute path to `terminal64.exe` |
| `METAEDITOR_PATH` | _(empty)_ | Absolute path to `metaeditor64.exe` |
| `MQL5_ROOT` | _(empty)_ | MQL5 data root (Experts/, Include/, etc.) |
| `WORKSPACE_DIR` | `workspace` | Local fallback workspace when MQL5_ROOT is unset |
| `EXPORTS_DIR` | `exports` | Directory for backtest report output |
| `DB_PATH` | `platform.db` | SQLite database file path |

---

## Running the App

```bash
# Start server (default: 0.0.0.0:8000)
python main.py

# Custom host and port
python main.py --host 127.0.0.1 --port 9000

# Utility commands
python main.py --setup-key    # Generate a new API key hash
python main.py --detect-mt5   # Auto-detect and write MT5 paths to .env
```

---

## API Authentication

Two authentication methods are accepted on all protected endpoints:

### Method 1: Bearer JWT (Web UI session)

Obtain a token by posting your raw API key to `/auth/login`:

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"api_key": "your-raw-api-key"}'
# → {"token": "eyJ...", "expires_in": 86400}
```

Then include in requests:
```
Authorization: Bearer eyJ...
```

### Method 2: X-API-Key (Direct / MCP / CLI)

Send the raw API key directly in a header:
```
X-API-Key: your-raw-api-key
```

---

## Web UI

The React SPA is bundled and served at `/` by FastAPI when `web_ui_dist/` exists.

**Development:**
```bash
cd web_ui
npm install
npm run dev        # http://localhost:5173 — proxies /api, /ws, /auth to port 8000
```

**Build for production:**
```bash
cd web_ui
npm run build      # outputs to ../web_ui_dist
```

### Web UI Routes

| Path | Description |
|---|---|
| `/login` | API key login |
| `/dashboard` | Overview metrics and quick actions |
| `/files` | File manager |
| `/compiler` | EA code editor + compile |
| `/backtest/setup` | Configure backtest parameters |
| `/backtest/monitor/:runId` | Live backtest progress |
| `/results` | Backtest result metrics |
| `/ledger` | Trade-by-trade breakdown |
| `/history` | Backtest run history |
| `/logs` | Platform log viewer with live tail and level filtering |
| `/usage` | API usage log |
| `/settings` | MT5 path configuration |
| `/setup` | Initial setup wizard |

---

## MCP Server

The MCP server exposes 32+ tools via stdio transport for use with AI assistants.

**Run the MCP server:**
```bash
python mcp_server/server.py
```

**Claude Desktop configuration** (`~/.config/claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "mt5-ea-platform": {
      "command": "python",
      "args": ["/absolute/path/to/tradest/mcp_server/server.py"],
      "env": {
        "API_KEY_HASH": "your-bcrypt-hash",
        "DB_PATH": "/absolute/path/to/tradest/platform.db",
        "WORKSPACE_DIR": "/absolute/path/to/tradest/workspace"
      }
    }
  }
}
```

Available tool categories: **Auth**, **EA**, **Files**, **Backtest**, **Usage** — see [API_DOCUMENTATION.md](./API_DOCUMENTATION.md#mcp-server-tools) for the full list.

---

## Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio anyio httpx

# Run all tests
pytest tests/ -v

# Run a specific module
pytest tests/test_ea.py -v

# Run with coverage (requires pytest-cov)
pytest tests/ --cov=. --cov-report=term-missing
```

The test suite includes **109 tests** across 8 modules covering all API endpoints, core business logic, security (path traversal, auth), log registry, and edge cases.

---

## Project Structure

```
tradest/
├── api/
│   ├── main.py                    # FastAPI app: CORS, routes, WebSocket, static SPA
│   ├── middleware/
│   │   └── auth.py                # require_auth: Bearer JWT + X-API-Key
│   ├── routes/
│   │   ├── auth.py                # POST /auth/login
│   │   ├── ea.py                  # /ea/* CRUD, upload, compile, logs
│   │   ├── files.py               # /files/* tree, read/write, rename, zip
│   │   ├── backtest.py            # /backtest/* run, status, result, history
│   │   ├── usage.py               # GET /health, GET /usage/events
│   │   └── logs.py                # GET /logs/recent, DELETE /logs/clear
│   └── websockets/
│       ├── compile_ws.py          # Live compile log streaming
│       ├── backtest_ws.py         # Live backtest status streaming
│       ├── upload_ws.py           # Upload progress streaming
│       └── logs_ws.py             # Live platform log tail broadcast
├── core/
│   ├── compiler.py                # MetaEditor64 CLI + UTF-16-LE log parser
│   ├── ea_manager.py              # EA file + DB CRUD
│   ├── backtest_controller.py     # Full backtest lifecycle orchestration
│   ├── usage_store.py             # Usage event logging and query
│   ├── log_registry.py            # DBLogHandler: captures all logging.* to SQLite + WS
│   ├── report_exporter.py         # HTML/XML report capture
│   ├── ledger_exporter.py         # Trade ledger CSV export
│   ├── file_manager/
│   │   ├── fs_navigator.py        # Directory tree, list, search, path guard
│   │   ├── fs_operations.py       # Read/write/rename/copy/move/delete/meta
│   │   ├── file_uploader.py       # Upload with conflict detection
│   │   ├── conflict_resolver.py   # Duplicate detection + suggested names
│   │   ├── zip_exporter.py        # Folder ZIP (zipfile fallback)
│   │   └── pwsh_runner.py         # PowerShell runner
│   ├── cli_automation/
│   │   ├── ini_generator.py       # MT5 Strategy Tester INI + SET file generation
│   │   ├── terminal_launcher.py   # Launch terminal64.exe with /config:
│   │   ├── process_monitor.py     # psutil-based process health monitoring
│   │   ├── result_watcher.py      # watchdog: detect HTML/XML report files
│   │   └── result_parser.py       # BeautifulSoup HTML + ElementTree XML parser
│   └── setup/
│       ├── mt5_detector.py        # 5-tier MT5 path detection
│       └── mt5_installer.py       # Silent MT5 installer
├── db/
│   ├── models.py                  # EAFile, CompileLog, BacktestRun, BacktestResult, UsageEvent, PlatformLog
│   └── database.py                # Async SQLite engine, session factory, init_db
├── mcp_server/
│   └── server.py                  # FastMCP stdio server — 32+ tools
├── web_ui/
│   ├── src/
│   │   ├── pages/                 # Login, Dashboard, FileManager, Compiler, Backtest…
│   │   ├── components/            # Sidebar, Editor, Charts, UploadDropzone…
│   │   ├── api/                   # Axios client + endpoint wrappers
│   │   └── store/                 # Zustand state: auth, backtest, files
│   ├── package.json
│   └── vite.config.js
├── tests/
│   ├── conftest.py                # Shared fixtures: DB, client, workspace
│   ├── test_auth.py               # Authentication tests (8)
│   ├── test_ea.py                 # EA CRUD and compile tests (15)
│   ├── test_files.py              # File Manager tests (19)
│   ├── test_backtest.py           # Backtest lifecycle tests (12)
│   ├── test_usage.py              # Usage events and health tests (12)
│   ├── test_core.py               # Core unit tests (23)
│   ├── test_mcp.py                # MCP server tests (12)
│   └── test_logs.py               # Log registry endpoint tests (8)
├── main.py                        # Entry point: argparse → uvicorn
├── config.py                      # Pydantic BaseSettings
├── requirements.txt               # Python dependencies
├── pytest.ini                     # Test configuration
├── setup.ps1                      # Windows: one-click install + API key setup
├── start.ps1                      # Windows: one-click launch with browser open
├── .env.example                   # Environment variable template
└── API_DOCUMENTATION.md           # Complete API reference
```

---

## License

MIT License — see [LICENSE](./LICENSE) for details.
