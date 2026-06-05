# API Documentation — MT5 EA Platform

**Version:** 1.0.0  
**Base URL:** `http://localhost:8000`  
**Content-Type:** `application/json` (unless noted otherwise)  
**Interactive Docs:** `http://localhost:8000/docs` (Swagger UI) · `http://localhost:8000/redoc`

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Auth Endpoints](#2-auth-endpoints)
3. [EA Management](#3-ea-management)
4. [File Manager](#4-file-manager)
5. [Backtest](#5-backtest)
6. [Usage & Health](#6-usage--health)
7. [Platform Logs](#7-platform-logs)
8. [WebSocket API](#8-websocket-api)
9. [MCP Server Tools](#9-mcp-server-tools)
10. [Data Models](#10-data-models)
11. [Error Reference](#11-error-reference)


---

## 1. Authentication

All endpoints except `GET /health` and `POST /auth/login` require authentication. Two methods are accepted:

### Method 1 — Bearer JWT

Obtain a token via `POST /auth/login`, then include it in the `Authorization` header:

```
Authorization: Bearer <token>
```

Tokens are signed with HMAC-SHA256 (`HS256`) and expire after `JWT_EXPIRY_HOURS` (default 24 hours).

### Method 2 — X-API-Key

Send the raw API key (generated with `python main.py --setup-key`) directly:

```
X-API-Key: <raw-api-key>
```

This is the recommended method for MCP clients, CLI scripts, and mobile apps where a session token is impractical.

### Authentication Error Response

All authentication failures return:

```http
HTTP 401 Unauthorized
WWW-Authenticate: Bearer

{
  "detail": "Invalid or missing authentication"
}
```

---

## 2. Auth Endpoints

### POST /auth/login

Exchange an API key for a JWT Bearer token.

**Auth required:** No

**Request body:**

```json
{
  "api_key": "string"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `api_key` | string | Yes | Raw API key (generated with `--setup-key`) |

**Response `200 OK`:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 86400
}
```

| Field | Type | Description |
|---|---|---|
| `token` | string | JWT Bearer token |
| `expires_in` | integer | Token validity in seconds (default: 86400 = 24h) |

**Error responses:**

| Status | Condition |
|---|---|
| `401` | Wrong API key |
| `503` | API key not configured on the server |
| `422` | Missing or malformed request body |

**Example:**

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"api_key": "my-secret-key"}'
```

---

## 3. EA Management

All endpoints are prefixed with `/ea` and require authentication.

---

### GET /ea/list

List all registered Expert Advisors.

**Response `200 OK`:**

```json
[
  {
    "id": 1,
    "name": "MyStrategy",
    "path": "Experts/MyStrategy.mq5",
    "type": "mq5",
    "updated_at": "2024-06-01 12:00:00"
  }
]
```

---

### GET /ea/{ea_id}

Get EA details including source code.

**Path parameters:**

| Parameter | Type | Description |
|---|---|---|
| `ea_id` | integer | EA database ID |

**Response `200 OK`:**

```json
{
  "id": 1,
  "name": "MyStrategy",
  "path": "Experts/MyStrategy.mq5",
  "type": "mq5",
  "content": "//+--...\nvoid OnTick(){}"
}
```

**Errors:** `404` if EA not found.

---

### POST /ea/create

Create a new EA file from source code.

**Request body:**

```json
{
  "name": "MyStrategy",
  "content": "//+--...\nvoid OnTick(){}",
  "type": "mq5"
}
```

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | string | Yes | — | EA name (no extension) |
| `content` | string | Yes | — | MQL5 source code |
| `type` | string | No | `"mq5"` | File extension (`mq5` or `mqh`) |

**Response `200 OK`:**

```json
{
  "id": 1,
  "name": "MyStrategy",
  "path": "Experts/MyStrategy.mq5",
  "type": "mq5"
}
```

**Errors:** `409` if an EA with this name already exists.

---

### POST /ea/upload

Upload a `.mq5` or `.mqh` file as multipart form data.

**Content-Type:** `multipart/form-data`

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `override` | boolean | `false` | Overwrite if file already exists |
| `new_name` | string | `""` | Save under a different filename |

**Form fields:**

| Field | Type | Description |
|---|---|---|
| `file` | file | The MQ5/MQH file to upload |

**Response `200 OK`:**

```json
{
  "id": 1,
  "name": "UploadedEA",
  "path": "Experts/UploadedEA.mq5"
}
```

**Errors:** `409` if file already exists and `override=false`.

**Example:**

```bash
curl -X POST http://localhost:8000/ea/upload \
  -H "X-API-Key: your-key" \
  -F "file=@MyStrategy.mq5"
```

---

### PUT /ea/{ea_id}

Update the source code of an existing EA.

**Request body:**

```json
{
  "content": "//+--...\nvoid OnTick(){ Print(1); }"
}
```

**Response `200 OK`:**

```json
{
  "id": 1,
  "name": "MyStrategy",
  "updated_at": "2024-06-01 14:30:00"
}
```

**Errors:** `404` if EA not found.

---

### DELETE /ea/{ea_id}

Delete an EA file and its database record. The file is moved to `_trash/` (soft delete).

**Response `200 OK`:**

```json
{
  "deleted": true
}
```

**Errors:** `404` if EA not found.

---

### POST /ea/{ea_id}/compile

Compile an EA using MetaEditor64. Blocks until compilation completes (up to 120 seconds).  
Connect to `WS /ws/compile/{ea_id}` before calling this endpoint to receive live log streaming.

**Response `200 OK`:**

```json
{
  "ea_id": 1,
  "status": "success",
  "errors": [],
  "warnings": [
    {
      "file": "Experts/MyStrategy.mq5",
      "line": 42,
      "col": 5,
      "message": "deprecated function call"
    }
  ],
  "raw_log": "...",
  "compiled_at": "2024-06-01T14:31:00Z"
}
```

| Field | Type | Values | Description |
|---|---|---|---|
| `status` | string | `success`, `warning`, `error` | Compile outcome |
| `errors` | array | LogEntry[] | Compilation errors |
| `warnings` | array | LogEntry[] | Compilation warnings |
| `raw_log` | string | — | Full raw MetaEditor log output |
| `compiled_at` | string | ISO 8601 | Timestamp |

**LogEntry object:**

```json
{
  "file": "Experts/MyStrategy.mq5",
  "line": 10,
  "col": 3,
  "message": "undeclared identifier 'x'"
}
```

**Errors:** `404` if EA not found or source file missing.

---

### GET /ea/{ea_id}/compile/logs

Get all compile logs for an EA, ordered newest-first.

**Response `200 OK`:**

```json
[
  {
    "id": 3,
    "timestamp": "2024-06-01 14:31:00",
    "status": "success",
    "errors": [],
    "warnings": []
  }
]
```

---

### GET /ea/{ea_id}/compile/logs/last

Get the most recent compile log for an EA.

**Response `200 OK`:**

```json
{
  "id": 3,
  "timestamp": "2024-06-01 14:31:00",
  "status": "success",
  "errors": [],
  "warnings": [],
  "raw_log": "..."
}
```

**Errors:** `404` if no compile logs exist for this EA.

---

## 4. File Manager

All endpoints are prefixed with `/files` and require authentication.  
All `path` values are **relative to the workspace root** (`MQL5_ROOT` or `WORKSPACE_DIR`). Path traversal attempts (`../`) are blocked: read operations return `404`, write/mutate operations return `400`.

---

### GET /files/tree

Get the full directory tree from the workspace root.

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `path` | string | `""` | Sub-path to use as tree root |
| `depth` | integer | `8` | Maximum recursion depth |

**Response `200 OK` — FileNode:**

```json
{
  "name": "workspace",
  "path": "",
  "is_dir": true,
  "extension": "",
  "size": 0,
  "children": [
    {
      "name": "Experts",
      "path": "Experts",
      "is_dir": true,
      "extension": "",
      "size": 0,
      "children": [
        {
          "name": "MyStrategy.mq5",
          "path": "Experts/MyStrategy.mq5",
          "is_dir": false,
          "extension": "mq5",
          "size": 1234,
          "children": null
        }
      ]
    }
  ]
}
```

---

### GET /files/list

List the direct contents of a directory.

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `path` | string | `""` | Directory path (relative to workspace root) |

**Response `200 OK`:** Array of FileNode objects (no `children` populated).

---

### GET /files/read

Read a text file's content.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | Yes | File path relative to workspace root |

**Response `200 OK`:**

```json
{
  "path": "Experts/MyStrategy.mq5",
  "content": "//+--...\nvoid OnTick(){}"
}
```

**Errors:** `404` if path not found or traversal blocked.

---

### GET /files/meta

Get file metadata.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | Yes | File or directory path |

**Response `200 OK`:**

```json
{
  "name": "MyStrategy.mq5",
  "path": "Experts/MyStrategy.mq5",
  "is_dir": false,
  "size_bytes": 1234,
  "created_at": "2024-06-01T10:00:00Z",
  "modified_at": "2024-06-01T14:00:00Z",
  "extension": "mq5"
}
```

---

### GET /files/search

Search files by name or content.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `q` | string | Yes | Search query (case-insensitive) |
| `path` | string | No | Scope search to this subdirectory |

Searches both **filename** and **file content** (for `.mq5`, `.mqh`, `.txt`, `.log`, `.csv`, `.ini` files).

**Response `200 OK`:** Array of FileNode objects for matching files.

---

### GET /files/download

Download a file as a binary attachment.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | Yes | File path relative to workspace root |

**Response `200 OK`:**
- Content-Type: `application/octet-stream`
- Content-Disposition: `attachment; filename="<filename>"`

---

### GET /files/download-zip

Download a file or folder as a ZIP archive.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | Yes | File or directory path |

**Response `200 OK`:**
- Content-Type: `application/zip`
- Content-Disposition: `attachment; filename="<folder>.zip"`

---

### POST /files/write

Write or overwrite a text file.

**Request body:**

```json
{
  "path": "Experts/NewStrategy.mq5",
  "content": "void OnTick(){}",
  "override": false,
  "new_name": ""
}
```

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `path` | string | Yes | — | Target file path (relative to workspace) |
| `content` | string | Yes | — | File content (UTF-8 text) |
| `override` | boolean | No | `false` | Overwrite if exists |
| `new_name` | string | No | `""` | Alternative filename (rename on save) |

**Response `200 OK`:**

```json
{
  "path": "Experts/NewStrategy.mq5"
}
```

**Errors:** `409` if file exists and `override=false`.

---

### POST /files/upload

Upload a file via multipart form data.

**Content-Type:** `multipart/form-data`

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `path` | string | `""` | Destination directory |
| `override` | boolean | `false` | Overwrite if exists |
| `new_name` | string | `""` | Alternative filename |

**Form fields:**

| Field | Type | Description |
|---|---|---|
| `file` | file | The file to upload |

**Response `200 OK`:**

```json
{
  "filename": "strategy.mq5",
  "path": "Experts/strategy.mq5",
  "size_bytes": 2048
}
```

**Errors:** `409` if file exists and `override=false`.

---

### POST /files/mkdir

Create a directory (including nested paths).

**Request body:**

```json
{
  "path": "Experts/Subfolder"
}
```

**Response `200 OK`:**

```json
{
  "path": "Experts/Subfolder"
}
```

---

### PUT /files/rename

Rename a file or directory.

**Request body:**

```json
{
  "path": "Experts/OldName.mq5",
  "new_name": "NewName.mq5",
  "override": false
}
```

**Response `200 OK`:**

```json
{
  "path": "Experts/NewName.mq5"
}
```

**Errors:** `409` if target name exists and `override=false`.

---

### PUT /files/copy

Copy a file or directory to a new location.

**Request body:**

```json
{
  "source": "Experts/SourceEA.mq5",
  "destination": "Experts/CopyEA.mq5",
  "override": false
}
```

**Response `200 OK`:**

```json
{
  "path": "Experts/CopyEA.mq5"
}
```

---

### PUT /files/move

Move a file or directory to a new location.

**Request body:**

```json
{
  "source": "Experts/OldLocation.mq5",
  "destination": "Archive/OldLocation.mq5",
  "override": false
}
```

**Response `200 OK`:**

```json
{
  "path": "Archive/OldLocation.mq5"
}
```

---

### DELETE /files/delete

Delete a file or directory.

**Request body:**

```json
{
  "path": "Experts/UnwantedEA.mq5",
  "soft": true
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `path` | string | — | Path to delete |
| `soft` | boolean | `true` | If true, move to `_trash/` instead of permanent deletion |

**Response `200 OK`:**

```json
{
  "message": "Moved to trash: UnwantedEA.mq5"
}
```

---

### POST /files/compile

Compile a `.mq5` file by its workspace path.  
The file must already be registered in the database (via `/ea/upload` or `/ea/create`).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `path` | string | Yes | Workspace-relative path to the `.mq5` file |

**Response `200 OK`:**

```json
{
  "ea_id": 1,
  "status": "success",
  "errors": [],
  "warnings": [],
  "raw_log": "...",
  "compiled_at": "2024-06-01T14:31:00Z"
}
```

See `POST /ea/{ea_id}/compile` for full field descriptions.

**Errors:** `404` if path is not registered.

---

## 5. Backtest

All endpoints are prefixed with `/backtest` and require authentication.

---

### POST /backtest/run

Launch a new backtest. Returns immediately with a `run_id`; the backtest executes in the background.  
Connect to `WS /ws/backtest/{run_id}` to receive live status updates.

**Request body:**

```json
{
  "ea_id": 1,
  "ea_name": "",
  "symbol": "EURUSD",
  "period": "H1",
  "from_date": "2024.01.01",
  "to_date": "2024.12.31",
  "model": 1,
  "deposit": 10000.0,
  "currency": "USD",
  "leverage": 100,
  "ea_set_params": {},
  "login": "",
  "password": "",
  "server": ""
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `ea_id` | integer\|null | `null` | EA database ID (used to resolve name if `ea_name` is empty) |
| `ea_name` | string | `""` | EA name as it appears in the MT5 Experts folder |
| `symbol` | string | `"EURUSD"` | Trading symbol |
| `period` | string | `"H1"` | Timeframe: `M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`, `W1`, `MN1` |
| `from_date` | string | `"2024.01.01"` | Backtest start date (format: `YYYY.MM.DD`) |
| `to_date` | string | `"2024.12.31"` | Backtest end date (format: `YYYY.MM.DD`) |
| `model` | integer | `1` | Testing model: `0`=Every Tick, `1`=1 Min OHLC, `2`=Open Prices, `3`=Math, `4`=Real Ticks |
| `deposit` | float | `10000.0` | Starting deposit |
| `currency` | string | `"USD"` | Account currency |
| `leverage` | integer | `100` | Account leverage (e.g. 100 = 1:100) |
| `ea_set_params` | object | `{}` | EA input parameters (key-value pairs written to `.set` file) |
| `login` | string | `""` | Broker account login (optional) |
| `password` | string | `""` | Broker account password (optional) |
| `server` | string | `""` | Broker server name (optional) |

**Response `200 OK`:**

```json
{
  "run_id": 42,
  "status": "pending"
}
```

**Errors:** `400` if neither `ea_id` nor `ea_name` is provided.

---

### GET /backtest/{run_id}/status

Get the current execution status of a backtest run.

**Response `200 OK`:**

```json
{
  "run_id": 42,
  "status": "running",
  "pid": 12345,
  "started_at": "2024-06-01 14:00:00",
  "finished_at": null
}
```

| Field | Type | Values | Description |
|---|---|---|---|
| `status` | string | `pending`, `running`, `done`, `failed`, `cancelled` | Current state |
| `pid` | integer\|null | — | OS process ID of the running MT5 terminal |

**Errors:** `404` if run not found.

---

### GET /backtest/{run_id}/result

Get parsed result metrics and trades from a completed backtest.

**Response `200 OK`:**

```json
{
  "run_id": 42,
  "metrics": {
    "net_profit": 1234.56,
    "profit_factor": 1.85,
    "expected_payoff": 12.3,
    "max_drawdown": 250.0,
    "total_trades": 100
  },
  "trades": [
    {
      "ticket": 1,
      "open_time": "2024.01.05 10:00",
      "close_time": "2024.01.05 14:00",
      "profit": 25.0,
      "symbol": "EURUSD"
    }
  ],
  "html_path": "C:\\Users\\User\\tradest\\exports\\42\\report.html",
  "xml_path": "C:\\Users\\User\\tradest\\exports\\42\\report.xml",
  "csv_path": "C:\\Users\\User\\tradest\\exports\\42\\ledger.csv"
}
```

**Errors:** `404` if result is not yet available (run still in progress or failed).

---

### GET /backtest/{run_id}/reports

Get the available report file list with sizes for a completed backtest.

**Response `200 OK`:**

```json
{
  "run_id": 42,
  "metrics": { "net_profit": 1234.56 },
  "trades": [],
  "files": {
    "html": { "path": "C:\\Users\\User\\tradest\\exports\\42\\report.html", "size_bytes": 45000 },
    "xml": { "path": "C:\\Users\\User\\tradest\\exports\\42\\report.xml", "size_bytes": 120000 },
    "csv": { "path": "C:\\Users\\User\\tradest\\exports\\42\\ledger.csv", "size_bytes": 5000 }
  }
}
```

**Errors:** `404` if no reports exist for this run.

---

### GET /backtest/{run_id}/report/html

Download the HTML backtest report.

**Response `200 OK`:**
- Content-Type: `text/html`
- Content-Disposition: `attachment; filename="report_42.html"`

---

### GET /backtest/{run_id}/report/excel

Download the Excel XML (Open XML format) backtest report.

**Response `200 OK`:**
- Content-Type: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- Content-Disposition: `attachment; filename="report_42.xml"`

---

### GET /backtest/{run_id}/report/csv

Download the trade ledger as a CSV file.

**Response `200 OK`:**
- Content-Type: `text/csv`
- Content-Disposition: `attachment; filename="ledger_42.csv"`

---

### DELETE /backtest/{run_id}/cancel

Cancel a running backtest by cancelling its background asyncio task.

**Response `200 OK`:**

```json
{
  "cancelled": true,
  "run_id": 42
}
```

Note: `cancelled` is `false` if the task had already completed or was not found in the active task registry.

---

### GET /backtest/history

List past backtest runs, ordered newest-first.

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `skip` | integer | `0` | Pagination offset |
| `limit` | integer | `50` | Maximum records to return |

**Response `200 OK`:**

```json
[
  {
    "run_id": 42,
    "ea_id": 1,
    "status": "done",
    "parameters": {
      "ea_name": "MyStrategy",
      "symbol": "EURUSD",
      "period": "H1",
      "from_date": "2024.01.01",
      "to_date": "2024.12.31"
    },
    "started_at": "2024-06-01 14:00:00",
    "finished_at": "2024-06-01 14:08:32"
  }
]
```

---

## 6. Usage & Health

---

### GET /health

System health check. **No authentication required.**

**Response `200 OK`:**

```json
{
  "status": "ok",
  "terminal_path": "C:\\MT5\\terminal64.exe",
  "terminal_ok": true,
  "metaeditor_path": "C:\\MT5\\metaeditor64.exe",
  "metaeditor_ok": true,
  "mql5_root": "C:\\Users\\User\\AppData\\Roaming\\MetaQuotes\\Terminal\\...",
  "mql5_ok": true,
  "cpu_percent": 4.2,
  "memory_mb": 312.5
}
```

| Field | Type | Values | Description |
|---|---|---|---|
| `status` | string | `ok`, `degraded` | `ok` when all three MT5 paths are valid; `degraded` otherwise |
| `terminal_ok` | boolean | — | Whether `terminal64.exe` exists at the configured path |
| `metaeditor_ok` | boolean | — | Whether `metaeditor64.exe` exists at the configured path |
| `mql5_ok` | boolean | — | Whether the MQL5 root directory exists |
| `cpu_percent` | float | — | Current CPU utilisation (%) |
| `memory_mb` | float | — | Current memory usage (MB) |

---

### GET /usage/events

Query the API usage/activity log. **Authentication required.**

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `limit` | integer | `100` | Maximum records to return (max: 1000) |
| `action` | string | `null` | Filter by exact action name (e.g. `compile`, `backtest`) |
| `date` | string | `null` | Filter events on or after this date (ISO format: `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS`) |

**Response `200 OK`:**

```json
[
  {
    "id": 1,
    "interface": "API",
    "action": "compile",
    "ea_id": 3,
    "run_id": null,
    "duration_ms": 2341,
    "status": "ok",
    "error_msg": null,
    "timestamp": "2024-06-01 14:31:00"
  }
]
```

| Field | Type | Values | Description |
|---|---|---|---|
| `interface` | string | `API`, `MCP`, `WebUI`, `Flutter` | Which interface triggered the event |
| `action` | string | — | Action performed (e.g. `compile`, `backtest_run`) |
| `status` | string | `ok`, `error` | Outcome |

---

## 7. Platform Logs

The platform captures every Python `logging.*` call to the `platform_logs` SQLite table and broadcasts new entries live over WebSocket. Log entries include the logger name, level, message, and optional structured context.

---

### GET /logs/recent

Fetch recent platform log entries, newest first. **Authentication required.**

**Query parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `limit` | integer | `100` | Maximum entries to return (1–500) |
| `level` | string | `null` | Filter by level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `logger` | string | `null` | Filter by logger name substring (e.g. `core.compiler`) |

**Request example:**

```bash
curl http://localhost:8000/logs/recent?limit=50&level=ERROR \
  -H "X-API-Key: your-raw-api-key"
```

**Response `200 OK`:**

```json
[
  {
    "id": 1023,
    "level": "ERROR",
    "logger_name": "core.backtest_controller",
    "message": "Backtest run #7 failed: terminal_path not configured",
    "context": {},
    "timestamp": "2024-06-01T14:31:00.123456"
  },
  {
    "id": 1022,
    "level": "INFO",
    "logger_name": "core.compiler",
    "message": "Compilation started for EA #3",
    "context": { "ea_id": 3 },
    "timestamp": "2024-06-01T14:30:55.000000"
  }
]
```

| Field | Type | Description |
|---|---|---|
| `id` | integer | Auto-increment primary key |
| `level` | string | Log level (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`) |
| `logger_name` | string | Python logger name (e.g. `core.compiler`, `api.routes.ea`) |
| `message` | string | Log message text |
| `context` | object | Optional structured context attached to the log record |
| `timestamp` | string | ISO 8601 UTC timestamp |

---

### DELETE /logs/clear

Delete all entries from the `platform_logs` table. **Authentication required.**

**Request example:**

```bash
curl -X DELETE http://localhost:8000/logs/clear \
  -H "X-API-Key: your-raw-api-key"
```

**Response `200 OK`:**

```json
{ "cleared": true }
```

---

## 8. WebSocket API

WebSocket connections do not require a separate authentication handshake — they use the same host and do not carry auth headers in the upgrade request.

---

### WS /ws/compile/{ea_id}

Subscribe to live compile log streaming for a specific EA. Connect **before** calling `POST /ea/{ea_id}/compile`.

**Messages from server (JSON text frames):**

```json
// Error entry
{
  "type": "error",
  "file": "Experts/MyStrategy.mq5",
  "line": 42,
  "col": 3,
  "message": "undeclared identifier 'x'"
}

// Warning entry
{
  "type": "warning",
  "file": "Experts/MyStrategy.mq5",
  "line": 18,
  "col": 1,
  "message": "deprecated function"
}

// Compilation complete
{
  "type": "complete",
  "status": "success"
}
```

`status` values: `success`, `warning`, `error`

---

### WS /ws/backtest/{run_id}

Subscribe to live backtest status for a specific run. Connect **before** calling `POST /backtest/run`.

**Messages from server (JSON text frames):**

```json
// Backtest started
{
  "status": "running",
  "pid": 12345,
  "run_id": 42
}

// Periodic resource update (every 5 seconds)
{
  "status": "running",
  "pid": 12345,
  "elapsed_s": 30,
  "resources": {
    "cpu_percent": 45.2,
    "memory_mb": 512.0
  }
}

// Completed successfully
{
  "status": "done",
  "run_id": 42,
  "metrics": {
    "net_profit": 1234.56,
    "profit_factor": 1.85
  }
}

// Failed
{
  "status": "failed",
  "run_id": 42,
  "error": "terminal_path not configured"
}

// Cancelled
{
  "status": "cancelled",
  "run_id": 42
}
```

---

### WS /ws/upload/{upload_id}

Subscribe to upload progress for a specific upload session.

**Messages from server (JSON text frames):**

```json
// Upload started
{
  "filename": "MyStrategy.mq5",
  "percent": 0
}

// Upload complete
{
  "filename": "MyStrategy.mq5",
  "percent": 100
}
```

`upload_id` is a client-chosen string identifier (e.g. a UUID).

---

### WS /ws/logs

Live tail of platform log entries. Every log record written to the database is immediately broadcast to all connected clients.

**Connection URL:** `ws://localhost:8000/ws/logs`

No path parameters required. Send any text frame as a keep-alive ping.

**Messages from server (JSON text frames):**

```json
{
  "id": 1024,
  "level": "WARNING",
  "logger_name": "core.compiler",
  "message": "MetaEditor not found at: C:\\MT5\\metaeditor64.exe",
  "context": {},
  "timestamp": "2024-06-01T14:32:10.456789"
}
```

Entries arrive in real time as the platform processes requests. Use the `level` and `logger_name` fields for client-side filtering. The Web UI's **Logs** page uses this endpoint for its live-tail feature.

---

## 9. MCP Server Tools

The MCP server (`python mcp_server/server.py`) exposes tools over the stdio transport for use with AI assistants. Tools are organized into five categories.

---

### Auth Tools

#### `auth_check(api_key: str) → dict`

Validate an API key against the server configuration.

```json
// Valid key
{"valid": true}

// Wrong key
{"valid": false}

// Server has no API key configured
{"valid": false, "error": "API key not configured"}
```

---

### EA Tools

#### `ea_create(name: str, code: str, type: str = "mq5") → dict`

Create a new EA file.

```json
{"id": 1, "name": "MyEA", "path": "Experts/MyEA.mq5"}
```

#### `ea_upload(filename: str, content_base64: str) → dict`

Upload a `.mq5` file from base64-encoded content.

```json
{"id": 1, "name": "MyEA", "path": "Experts/MyEA.mq5"}
// On conflict:
{"conflict": true, "existing_path": "...", "suggested_name": "MyEA_1.mq5"}
```

#### `ea_read(ea_id: int) → dict`

Read EA source code by ID.

```json
{"id": 1, "name": "MyEA", "content": "//+--..."}
```

#### `ea_update(ea_id: int, code: str) → dict`

Update EA source code.

```json
{"id": 1, "updated_at": "2024-06-01 14:00:00"}
```

#### `ea_list() → list`

List all registered EAs.

```json
[{"id": 1, "name": "MyEA", "path": "Experts/MyEA.mq5", "type": "mq5"}]
```

#### `ea_delete(ea_id: int, confirm: bool = False) → dict`

Delete an EA. Must pass `confirm=True`.

```json
{"deleted": true}
```

#### `ea_compile(ea_id: int) → dict`

Compile an EA by ID.

```json
{
  "ea_id": 1,
  "status": "success",
  "errors": [],
  "warnings": [],
  "raw_log": "...",
  "compiled_at": "2024-06-01T14:31:00Z"
}
```

#### `ea_compile_log(ea_id: int) → dict`

Get the latest compile log for an EA.

---

### File Tools

#### `file_tree(path: str = "") → dict`

Get directory tree from workspace root.

#### `file_list(path: str) → list`

List directory contents.

#### `file_read(path: str) → dict`

Read file content as text.

```json
{"path": "Experts/ea.mq5", "content": "..."}
```

#### `file_meta(path: str) → dict`

Get file metadata.

#### `file_search(query: str, path: str = "") → list`

Search files by name or content.

#### `file_write(path: str, content: str, override: bool = False, new_name: str = "") → dict`

Write or create a file.

```json
{"path": "Experts/ea.mq5"}
// On conflict:
{"conflict": true, "detail": "..."}
```

#### `file_upload(path: str, content_base64: str, override: bool = False, new_name: str = "") → dict`

Upload a file from base64 content.

#### `file_mkdir(path: str) → dict`

Create a directory.

#### `file_rename(path: str, new_name: str, override: bool = False) → dict`

Rename a file or directory.

#### `file_copy(source: str, destination: str, override: bool = False) → dict`

Copy a file or directory.

#### `file_move(source: str, destination: str, override: bool = False) → dict`

Move a file or directory.

#### `file_delete(path: str, confirm: bool = False) → dict`

Soft-delete a file. Must pass `confirm=True`.

#### `file_download_zip(path: str) → dict`

ZIP a folder and return base64-encoded bytes.

```json
{"content_base64": "UEsDB...", "size_bytes": 4096}
```

#### `file_compile(path: str) → dict`

Compile a `.mq5` file by its workspace path.

---

### Backtest Tools

#### `backtest_run(ea_id, symbol, period, from_date, to_date, model, deposit, currency, leverage) → dict`

Launch a backtest. Returns immediately with `run_id`.

```json
{"run_id": 42, "status": "pending"}
```

| Parameter | Type | Default |
|---|---|---|
| `ea_id` | int | — |
| `symbol` | str | `"EURUSD"` |
| `period` | str | `"H1"` |
| `from_date` | str | `"2024.01.01"` |
| `to_date` | str | `"2024.12.31"` |
| `model` | int | `1` |
| `deposit` | float | `10000.0` |
| `currency` | str | `"USD"` |
| `leverage` | int | `100` |

#### `backtest_status(run_id: int) → dict`

Get current backtest status.

#### `backtest_result(run_id: int) → dict`

Get result metrics and trade count.

```json
{"run_id": 42, "metrics": {...}, "trades_count": 150}
```

#### `backtest_report_html(run_id: int) → dict`

Get HTML report path.

#### `backtest_report_excel(run_id: int) → dict`

Get Excel XML report path.

#### `backtest_report_csv(run_id: int) → dict`

Get CSV ledger path.

#### `backtest_cancel(run_id: int) → dict`

Cancel a running backtest.

#### `backtest_history(limit: int = 20, ea_id: int | None = None) → list`

List past backtest runs.

---

### Usage Tools

#### `usage_log(limit: int = 50, action: str | None = None) → list`

Query the usage/activity log.

```json
[
  {
    "id": 1,
    "interface": "MCP",
    "action": "ea_compile",
    "status": "ok",
    "timestamp": "2024-06-01 14:31:00"
  }
]
```

---

## 10. Data Models

### EAFile

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `name` | string | EA name (without extension) |
| `path` | string | Workspace-relative file path |
| `type` | string | File extension (`mq5`, `mqh`) |
| `created_at` | datetime | Creation timestamp (UTC) |
| `updated_at` | datetime | Last update timestamp (UTC) |

### CompileLog

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `ea_id` | integer | Foreign key → EAFile |
| `timestamp` | datetime | Compile timestamp |
| `status` | string | `success`, `warning`, `error` |
| `errors_json` | text | JSON array of LogEntry |
| `warnings_json` | text | JSON array of LogEntry |
| `raw_log` | text | Full MetaEditor output |

### LogEntry (embedded in CompileLog)

```json
{
  "file": "Experts/MyEA.mq5",
  "line": 42,
  "col": 3,
  "message": "undeclared identifier 'x'"
}
```

### BacktestRun

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `ea_id` | integer\|null | Foreign key → EAFile (nullable) |
| `parameters_json` | text | Serialized BacktestParams |
| `test_type` | string | Always `"backtest"` |
| `status` | string | `pending`, `running`, `done`, `failed`, `cancelled` |
| `pid` | integer\|null | OS process ID of MT5 terminal |
| `started_at` | datetime\|null | When the run began |
| `finished_at` | datetime\|null | When the run ended |

### BacktestResult

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `run_id` | integer | Foreign key → BacktestRun (unique) |
| `metrics_json` | text | Parsed strategy metrics as JSON object |
| `trades_json` | text | Parsed trade list as JSON array |
| `html_path` | string\|null | Path to HTML report |
| `xml_path` | string\|null | Path to Excel XML report |
| `csv_path` | string\|null | Path to CSV ledger |

### UsageEvent

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `interface` | string | `API`, `MCP`, `WebUI`, `Flutter` |
| `action` | string | Action performed |
| `ea_id` | integer\|null | Related EA ID |
| `run_id` | integer\|null | Related run ID |
| `duration_ms` | integer\|null | Execution time in milliseconds |
| `status` | string | `ok`, `error` |
| `error_msg` | text\|null | Error message if status is `error` |
| `timestamp` | datetime | UTC timestamp |

### PlatformLog

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key |
| `level` | string | `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `logger_name` | string | Python logger name (e.g. `core.compiler`) |
| `message` | text | Log message text |
| `context` | object | Optional JSON context attached at log time |
| `timestamp` | datetime | UTC timestamp |

### ConflictInfo (conflict response)

```json
{
  "conflict": true,
  "existing_path": "/absolute/path/to/existing/file.mq5",
  "modified_at": "2024-06-01T12:00:00Z",
  "size_bytes": 2048,
  "suggested_name": "MyEA_1.mq5"
}
```

### FileNode (file tree)

```json
{
  "name": "MyStrategy.mq5",
  "path": "Experts/MyStrategy.mq5",
  "is_dir": false,
  "extension": "mq5",
  "size": 1234,
  "children": null
}
```

`children` is `null` for files, and a (possibly empty) array for directories when `depth > 0`.

---

## 11. Error Reference

| HTTP Code | Error Name | When it Occurs | Response Body |
|---|---|---|---|
| `400` | Bad Request | Path traversal attempt; `ea_name` missing from backtest; invalid request body | `{"detail": "...description..."}` |
| `401` | Unauthorized | Missing, expired, or invalid Bearer JWT or X-API-Key header | `{"detail": "Invalid or missing authentication"}` |
| `404` | Not Found | EA/run/file/compile-log not found; path resolved outside workspace | `{"detail": "...not found..."}` |
| `409` | Conflict | File already exists (`override=false`); duplicate EA name on create | `{"detail": {"conflict": true, "suggested_name": "...", ...}}` |
| `422` | Unprocessable Entity | Pydantic request body validation failure (wrong types, missing required fields) | `{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}` |
| `503` | Service Unavailable | `POST /auth/login` called when `API_KEY_HASH` is not configured in server settings | `{"detail": "API key not configured"}` |

### Conflict Response Detail

When a `409` response is returned for a file conflict, the `detail` field contains a `ConflictInfo` object:

```json
{
  "detail": {
    "conflict": true,
    "existing_path": "/workspace/Experts/MyEA.mq5",
    "modified_at": "2024-06-01T12:00:00Z",
    "size_bytes": 2048,
    "suggested_name": "MyEA_1.mq5"
  }
}
```

Use `suggested_name` to offer the user a rename option, or re-submit with `override=true` to overwrite.
