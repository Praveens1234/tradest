#Requires -Version 5.1
<#
.SYNOPSIS
    MT5 EA Platform — One-Click Setup Script
.DESCRIPTION
    Checks Python 3.11+, installs dependencies, generates your API key,
    auto-detects MetaTrader 5, creates .env, and optionally builds the Web UI.
    Run this once before using start.ps1.
#>

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "MT5 EA Platform — Setup"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ███╗   ███╗████████╗███████╗    ███████╗ █████╗     ██████╗ ██╗      █████╗ ████████╗███████╗ ██████╗ ██████╗ ███╗   ███╗" -ForegroundColor Cyan
    Write-Host "  ████╗ ████║╚══██╔══╝██╔════╝    ██╔════╝██╔══██╗    ██╔══██╗██║     ██╔══██╗╚══██╔══╝██╔════╝██╔═══██╗██╔══██╗████╗ ████║" -ForegroundColor Cyan
    Write-Host "  ██╔████╔██║   ██║   ███████╗    █████╗  ███████║    ██████╔╝██║     ███████║   ██║   █████╗  ██║   ██║██████╔╝██╔████╔██║" -ForegroundColor Cyan
    Write-Host "  ██║╚██╔╝██║   ██║   ╚════██║    ██╔══╝  ██╔══██║    ██╔═══╝ ██║     ██╔══██║   ██║   ██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║" -ForegroundColor Cyan
    Write-Host "  ██║ ╚═╝ ██║   ██║   ███████║    ███████╗██║  ██║    ██║     ███████╗██║  ██║   ██║   ██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║" -ForegroundColor Cyan
    Write-Host "  ╚═╝     ╚═╝   ╚═╝   ╚══════╝    ╚══════╝╚═╝  ╚═╝   ╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "                          MetaTrader 5 Expert Advisor Automation Platform" -ForegroundColor White
    Write-Host "                                        Setup Wizard v1.0" -ForegroundColor Gray
    Write-Host ""
}

function Write-Section {
    param($Step, $Title)
    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  STEP $Step  $Title" -ForegroundColor White
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function Write-OK   { param($T); Write-Host "  [OK]   $T" -ForegroundColor Green }
function Write-SKIP { param($T); Write-Host "  [SKIP] $T" -ForegroundColor DarkGray }
function Write-WARN { param($T); Write-Host "  [WARN] $T" -ForegroundColor Yellow }
function Write-FAIL { param($T); Write-Host "  [FAIL] $T" -ForegroundColor Red }
function Write-INFO { param($T); Write-Host "  [....] $T" -ForegroundColor Cyan }

Write-Banner

# ── Step 1: Verify Python 3.11+ ───────────────────────────────────────────
Write-Section 1 "Verify Python 3.11+"

$pyCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]; $minor = [int]$Matches[2]
            if ($major -ge 3 -and $minor -ge 11) {
                $pyCmd = $cmd
                Write-OK "Found $ver  (using command: $cmd)"
                break
            } else {
                Write-WARN "$ver found — Python 3.11+ is required"
            }
        }
    } catch { }
}

if (-not $pyCmd) {
    Write-FAIL "Python 3.11+ is not installed or not on PATH."
    Write-Host ""
    Write-Host "  Please install Python 3.11 or later from:" -ForegroundColor White
    Write-Host "  https://www.python.org/downloads/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Make sure to check 'Add Python to PATH' during installation." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# ── Step 2: Install Python dependencies ───────────────────────────────────
Write-Section 2 "Install Python Dependencies"
Write-INFO "Running: pip install -r requirements.txt"

try {
    & $pyCmd -m pip install -r requirements.txt --quiet --disable-pip-version-check
    Write-OK "All Python dependencies installed successfully"
} catch {
    Write-FAIL "pip install failed: $_"
    Write-Host ""
    Write-Host "  Try running manually:" -ForegroundColor Gray
    Write-Host "    $pyCmd -m pip install -r requirements.txt" -ForegroundColor Gray
    Read-Host "  Press Enter to exit"
    exit 1
}

# ── Step 3: Generate API Key ───────────────────────────────────────────────
Write-Section 3 "Generate API Key"
Write-INFO "Generating a new API key..."

$keyOutput = & $pyCmd main.py --setup-key 2>&1 | Out-String
$rawKey  = $null
$keyHash = $null

foreach ($line in ($keyOutput -split "`n")) {
    if ($line -match "Raw key\s*[:\|]\s*(.+)")  { $rawKey  = $Matches[1].Trim() }
    if ($line -match "Hash\s*[:\|]\s*(\`\$.+)") { $keyHash = $Matches[1].Trim() }
    if ($line -match "bcrypt hash\s*[:\|]\s*(\`\$.+)") { $keyHash = $Matches[1].Trim() }
}

if (-not $rawKey -or -not $keyHash) {
    Write-Host $keyOutput
    Write-WARN "Could not auto-parse the key from output above."
    $rawKey  = Read-Host "  Enter your raw API key"
    $keyHash = Read-Host "  Enter your bcrypt hash"
}

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║                *** SAVE YOUR API KEY ***             ║" -ForegroundColor Magenta
Write-Host "  ║                                                      ║" -ForegroundColor Magenta
Write-Host "  ║  RAW API KEY  (use this to log in):                  ║" -ForegroundColor Magenta
Write-Host "  ║                                                      ║" -ForegroundColor White
Write-Host "  ║    $rawKey" -ForegroundColor Yellow
Write-Host "  ║                                                      ║" -ForegroundColor White
Write-Host "  ║  This key is shown ONCE. Write it down or copy it.  ║" -ForegroundColor Magenta
Write-Host "  ║  You will need it to log in to the Web UI.          ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

Read-Host "  >>> Press Enter once you have saved your API key <<<"

# ── Step 4: Detect MetaTrader 5 ───────────────────────────────────────────
Write-Section 4 "Auto-detect MetaTrader 5"
Write-INFO "Scanning for MT5 installation (registry, known paths, AppData, PATH, glob)..."

$mt5Output    = & $pyCmd main.py --detect-mt5 2>&1 | Out-String
$terminalPath = ""
$metaedPath   = ""
$mql5Root     = ""

foreach ($line in ($mt5Output -split "`n")) {
    if ($line -match "TERMINAL_PATH\s*=\s*(.+)")    { $terminalPath = $Matches[1].Trim() }
    if ($line -match "METAEDITOR_PATH\s*=\s*(.+)")  { $metaedPath   = $Matches[1].Trim() }
    if ($line -match "MQL5_ROOT\s*=\s*(.+)")        { $mql5Root     = $Matches[1].Trim() }
}

if ($terminalPath) {
    Write-OK "Terminal    : $terminalPath"
    Write-OK "MetaEditor  : $metaedPath"
    Write-OK "MQL5 Root   : $mql5Root"
} else {
    Write-WARN "MT5 not found automatically."
    Write-Host ""
    Write-Host "  If MT5 is installed, you can enter paths manually below, or" -ForegroundColor Gray
    Write-Host "  leave blank and configure them later in the Web UI → Settings." -ForegroundColor Gray
    Write-Host ""
    $terminalPath = Read-Host "  terminal64.exe path (leave blank to skip)"
    $metaedPath   = Read-Host "  metaeditor64.exe path (leave blank to skip)"
    $mql5Root     = Read-Host "  MQL5 data folder path (leave blank to skip)"
}

# ── Step 5: Create .env ───────────────────────────────────────────────────
Write-Section 5 "Create .env Configuration File"

$envExists = Test-Path ".env"
$writeEnv  = $true

if ($envExists) {
    $choice = Read-Host "  .env already exists. Overwrite? (y/N)"
    if ($choice -ne "y" -and $choice -ne "Y") {
        Write-SKIP ".env not overwritten — updating API_KEY_HASH only"
        $existing = Get-Content ".env" -Raw
        $existing = $existing -replace "(?m)^API_KEY_HASH=.*$", "API_KEY_HASH=$keyHash"
        $existing | Set-Content ".env" -Encoding UTF8 -NoNewline
        Write-OK "API_KEY_HASH updated in existing .env"
        $writeEnv = $false
    }
}

if ($writeEnv) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    @"
# MT5 EA Platform — Environment Configuration
# Generated by setup.ps1 on $stamp

# ── Authentication ─────────────────────────────────────────────────────────
API_KEY_HASH=$keyHash
JWT_SECRET=
JWT_EXPIRY_HOURS=24

# ── Server ─────────────────────────────────────────────────────────────────
HOST=0.0.0.0
PORT=8000

# ── MetaTrader 5 Paths ─────────────────────────────────────────────────────
TERMINAL_PATH=$terminalPath
METAEDITOR_PATH=$metaedPath
MQL5_ROOT=$mql5Root

# ── Storage ────────────────────────────────────────────────────────────────
WORKSPACE_DIR=workspace
EXPORTS_DIR=exports
DB_PATH=platform.db
"@ | Set-Content ".env" -Encoding UTF8
    Write-OK ".env created successfully"
}

# ── Step 6: Build Web UI ──────────────────────────────────────────────────
Write-Section 6 "Build Web UI (Optional)"

$buildUI = Read-Host "  Build the React Web UI? Requires Node.js 18+. (y/N)"
if ($buildUI -eq "y" -or $buildUI -eq "Y") {
    $nodeOK = $false
    try {
        $nodeVer = & node --version 2>&1
        if ($nodeVer -match "v(\d+)\.") {
            if ([int]$Matches[1] -ge 18) {
                $nodeOK = $true
                Write-OK "Node.js $nodeVer found"
            } else {
                Write-WARN "Node.js $nodeVer found — version 18+ required"
            }
        }
    } catch { Write-WARN "node command not found" }

    if ($nodeOK) {
        Push-Location web_ui
        Write-INFO "Installing npm dependencies..."
        & npm install --silent
        Write-INFO "Building production bundle..."
        & npm run build
        Pop-Location

        if (Test-Path "web_ui_dist\index.html") {
            Write-OK "Web UI built successfully  →  web_ui_dist/"
        } else {
            Write-WARN "Build may have failed — check output above"
        }
    } else {
        Write-WARN "Skipping Web UI build (Node.js 18+ required)"
        Write-Host "  Install Node.js from https://nodejs.org  then run:" -ForegroundColor Gray
        Write-Host "    cd web_ui && npm install && npm run build" -ForegroundColor Gray
    }
} else {
    Write-SKIP "Web UI build skipped"
    Write-Host "  Build later with:  cd web_ui && npm install && npm run build" -ForegroundColor Gray
}

# ── Done ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✓  Setup complete!  MT5 EA Platform is ready to start." -ForegroundColor Green
Write-Host "  ═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Your API Key  :  $rawKey" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1.  Run .\start.ps1  to start the server" -ForegroundColor Gray
Write-Host "    2.  Open http://localhost:8000 in your browser" -ForegroundColor Gray
Write-Host "    3.  Log in with the API key shown above" -ForegroundColor Gray
Write-Host ""
Read-Host "  Press Enter to exit"
