#Requires -Version 5.1
<#
.SYNOPSIS
    MT5 EA Platform — One-Click Start Script
.DESCRIPTION
    Validates the environment and starts the MT5 EA Platform server,
    then opens the Web UI in your default browser.
    Run setup.ps1 first if you haven't already.
#>

$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "MT5 EA Platform — Running"

function Write-OK   { param($T); Write-Host "  [OK]   $T" -ForegroundColor Green }
function Write-WARN { param($T); Write-Host "  [WARN] $T" -ForegroundColor Yellow }
function Write-FAIL { param($T); Write-Host "  [FAIL] $T" -ForegroundColor Red }
function Write-INFO { param($T); Write-Host "  [....] $T" -ForegroundColor Cyan }

Clear-Host
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │       MT5 EA Platform  —  Starting Up           │" -ForegroundColor Cyan
Write-Host "  └─────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# ── Preflight checks ──────────────────────────────────────────────────────

# 1. .env exists
if (-not (Test-Path ".env")) {
    Write-FAIL ".env not found. Run setup.ps1 first to configure the platform."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}
Write-OK ".env configuration found"

# 2. Python 3.11+
$pyCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python 3\.(1[1-9]|\d{2})") {
            $pyCmd = $cmd
            Write-OK "Python found: $ver"
            break
        }
    } catch { }
}

if (-not $pyCmd) {
    Write-FAIL "Python 3.11+ not found. Run setup.ps1 first."
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# 3. Read port from .env
$port = "8000"
$host_ = "0.0.0.0"
Get-Content ".env" | ForEach-Object {
    if ($_ -match "^PORT\s*=\s*(\d+)")  { $port  = $Matches[1] }
    if ($_ -match "^HOST\s*=\s*(.+)")   { $host_ = $Matches[1].Trim() }
}

# Use localhost for browser regardless of bind address
$browserUrl = "http://localhost:$port"
Write-OK "Server will bind on ${host_}:$port"

# 4. Check if port already in use
$portInUse = $false
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect("localhost", [int]$port)
    $tcp.Close()
    $portInUse = $true
} catch { }

if ($portInUse) {
    Write-WARN "Port $port is already in use — the server may already be running."
    Write-Host ""
    $open = Read-Host "  Open $browserUrl in the browser? (Y/n)"
    if ($open -ne "n" -and $open -ne "N") {
        Start-Process $browserUrl
    }
    Write-Host ""
    exit 0
}

# 5. main.py present
if (-not (Test-Path "main.py")) {
    Write-FAIL "main.py not found. Run this script from the tradest project root."
    Read-Host "  Press Enter to exit"
    exit 1
}
Write-OK "main.py found"

# ── Launch ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Starting MT5 EA Platform..." -ForegroundColor White
Write-Host ""
Write-Host "  Web UI  :  $browserUrl" -ForegroundColor Cyan
Write-Host "  API     :  $browserUrl/docs   (Swagger UI)" -ForegroundColor Gray
Write-Host "  Logs    :  $browserUrl/logs   (Platform logs)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Press Ctrl+C to stop the server." -ForegroundColor DarkGray
Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# Open browser after 3-second delay (background job)
Start-Job -ScriptBlock {
    param($url)
    Start-Sleep -Seconds 3
    Start-Process $url
} -ArgumentList $browserUrl | Out-Null

# Start server (blocking — keeps this window open)
& $pyCmd main.py

# Server exited
Write-Host ""
Write-Host "  Server stopped." -ForegroundColor DarkGray
Read-Host "  Press Enter to exit"
