# MT5 EA Platform — Flutter Mobile Client

A Material You–designed Flutter mobile application for the MT5 EA Automation Platform. Manage Expert Advisors, run and monitor backtests, browse server files, and analyse results — all from your Android device.

---

## Features

| Screen | Description |
|--------|-------------|
| **Login** | Connect to any MT5 EA Platform server with JWT auth |
| **Dashboard** | Live system health (Terminal, MetaEditor, MQL5, CPU/RAM) + recent backtests |
| **EA Manager** | List, create, compile, edit, and delete Expert Advisors |
| **EA Detail** | Full-screen code editor with syntax-preserving scrollable view |
| **Run Backtest** | Configure EA, symbol, timeframe, date range, model, and account settings |
| **Backtest Monitor** | Real-time progress via WebSocket; live log stream; cancel support |
| **Results** | Equity curve chart, 8+ performance metrics, download reports (HTML/Excel/CSV) |
| **History** | Filterable + searchable list of all backtest runs |
| **Trade Ledger** | Sortable trade-by-trade table with profit/loss highlighting |
| **File Browser** | Navigate server file system; view source files inline |
| **Usage Log** | Filter API events by status |
| **Settings** | Server URL, connection test, app version |

---

## Architecture

```
flutter_app/lib/
├── main.dart                  # ProviderScope + runApp
├── app.dart                   # MaterialApp.router + Material You theme
├── core/
│   ├── api_client.dart        # Dio HTTP client with JWT interceptor
│   ├── storage_service.dart   # SharedPreferences (token, server URL, last params)
│   └── app_colors.dart        # Semantic color constants (success, warning)
├── config/
│   └── router.dart            # GoRouter with auth redirect
├── features/
│   ├── auth/                  # Login screen + Riverpod auth provider
│   ├── dashboard/             # Health + recent runs
│   ├── ea/                    # EA list, detail, provider
│   ├── backtest/              # Setup, monitor (WebSocket), results
│   ├── history/               # Run history with search/filter
│   ├── trade_ledger/          # Sortable trades table
│   ├── files/                 # File browser
│   ├── usage/                 # API usage log
│   └── settings/              # Server config + about
└── shared/
    ├── models/                # BacktestRun, BacktestResult, EAModel
    └── widgets/               # AppScaffold, StatCard, StatusBadge, ShimmerLoading
```

**Key dependencies:**
- `flutter_riverpod 2.5.1` — state management (FutureProvider + StateNotifier)
- `go_router 13.2.0` — declarative routing with auth guards
- `dio 5.4.0` — HTTP with JWT interceptor
- `web_socket_channel 2.4.5` — real-time backtest monitoring
- `fl_chart 0.68.0` — equity curve charts
- `shimmer 3.0.0` — skeleton loading states
- `url_launcher 6.3.0` — open HTML reports in browser
- `package_info_plus 8.0.0` — dynamic app version
- `shared_preferences 2.2.3` — token + preferences persistence
- `intl 0.19.0` — date formatting

---

## Prerequisites

- Flutter 3.22+ (tested with 3.24.5)
- Dart 3.3+
- Android SDK / Android Studio (for device builds)
- A running [MT5 EA Platform](../README.md) server

---

## Setup

### 1. Install dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Configure server URL

The default server URL is `http://192.168.1.10:8000`. You can change it on the Login screen before connecting — the app persists your choice across sessions.

### 3. Authenticate

Enter the **Server URL** and the **API Key** configured on your server (the plaintext key from which `API_KEY_HASH` in `.env` was generated). The app exchanges this for a 24-hour JWT token stored locally.

---

## Building

### Debug APK (no signing required)

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (requires signing)

```bash
# Generate a keystore (first time only)
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key

# Build
flutter build apk --release \
  --dart-define=BUILD_MODE=release
```

Configure signing in `android/app/build.gradle` or via `android/key.properties`.

### CI/CD

The GitHub Actions workflow at `.github/workflows/flutter.yml` automatically:
1. Sets up Flutter 3.24.5
2. Scaffolds the Android project
3. Injects the INTERNET permission
4. Builds a release APK (or debug if no keystore secret is set)
5. Uploads the APK as an artifact for 30 days

---

## API Integration

All endpoints are on the configured server URL. The `ApiClient` singleton injects `Authorization: Bearer <token>` on every request.

| Feature | Endpoints |
|---------|-----------|
| Auth | `POST /auth/login` |
| Health | `GET /health` |
| EA CRUD | `GET /ea/list`, `GET /ea/{id}`, `PUT /ea/{id}`, `POST /ea/{id}/compile`, `DELETE /ea/{id}`, `POST /ea/create` |
| Backtest | `POST /backtest/run`, `GET /backtest/{id}/status`, `GET /backtest/{id}/result`, `DELETE /backtest/{id}/cancel`, `GET /backtest/history` |
| Reports | `GET /backtest/{id}/report/html|excel|csv` |
| Files | `GET /files/list`, `GET /files/read` |
| Usage | `GET /usage/events` |
| WebSocket | `WS /ws/backtest/{id}` (live progress) |

> **Note:** WebSocket endpoints do not require auth headers — they are unauthenticated on the server side.

---

## Persistence

The app stores the following in `SharedPreferences`:

| Key | Value |
|-----|-------|
| `auth_token` | JWT token (cleared on logout) |
| `server_url` | Server base URL (persists across logout) |
| `last_ea_id` | EA ID used in the last backtest |
| `last_symbol` | Symbol used in the last backtest |
| `last_period` | Timeframe used in the last backtest |
| `last_from_date` | From-date used in the last backtest |
| `last_to_date` | To-date used in the last backtest |
| `last_deposit` / `last_currency` / `last_leverage` / `last_model` | Account settings |

---

## Screenshots

> _Add screenshots here after first device run._

| Login | Dashboard | EA Manager | Backtest |
|-------|-----------|------------|---------|
| | | | |

---

## Development Notes

- **Theme:** Material You (`ColorScheme.fromSeed`) with dark brightness. Seed color: `#3B82F6`.
- **State:** All data fetching via `FutureProvider.autoDispose`. Mutations via `StateNotifier`.
- **Navigation:** GoRouter with auth guard. Unauthenticated users are always redirected to `/login`.
- **Error messages:** Server `detail` field is extracted from DioException responses via `ApiClient.extractError()`.
