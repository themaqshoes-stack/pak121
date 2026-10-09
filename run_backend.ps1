#Requires -Version 5.1
<#
.SYNOPSIS
  CAD Backend runner for Windows (PowerShell).
  Auto-detects uv / py / python, installs deps, starts server.
  - Bypasses ExecutionPolicy for the venv activator.
  - Keeps the window open on error so you can read it.
#>
$ErrorActionPreference = "Stop"

$Port = 8000
$HostAddr = "0.0.0.0"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Image-to-STEP CAD Backend Starter (PowerShell)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Project dir: $ProjectDir"
Write-Host ""

function Pause-OnError {
    param([string]$msg)
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Write-Host ""
    Write-Host -NoNewline "Press Enter to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

function Activate-Venv {
    $activate = Join-Path $ProjectDir ".venv\Scripts\Activate.ps1"
    if (Test-Path $activate) {
        Write-Host "Activating venv..." -ForegroundColor DarkGray
        & powershell -NoProfile -ExecutionPolicy Bypass -Command ". `"$activate`"" 2>$null | Out-Null
        # Re-exec the activate in-process via dot-source (Bypass is needed per-machine)
        try {
            . $activate
        }
        catch {
            # Activation via dot-source may be blocked. Fallback: use venv python directly.
            Write-Host "ℹ️   Could not dot-source Activate.ps1; will use venv python directly." -ForegroundColor Yellow
            $script:PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
        }
    }
}

$PythonExe = $null

# ------- Option 1: uv -------
$uv = Get-Command uv -ErrorAction SilentlyContinue
if ($uv) {
    Write-Host "[1/3] ✅ uv detected. Syncing dependencies..." -ForegroundColor Green
    try {
        & $uv.Source sync 2>&1 | Tee-Object -Variable uvOut
        if ($LASTEXITCODE -ne 0) { throw "uv sync failed (exit $LASTEXITCODE)" }
    }
    catch { Pause-OnError $_.Exception.Message }

    Write-Host ""
    Write-Host "[2/3] 🚀 Starting CAD backend with uv  ->  http://$HostAddr`:$Port" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
    Write-Host ""
    try {
        & $uv.Source run uvicorn cad_backend:app --host $HostAddr --port $Port --reload
    }
    catch { Pause-OnError $_.Exception.Message }
    exit $LASTEXITCODE
}

# ------- Option 2: py launcher -------
$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }

if ($py) {
    Write-Host "[1/3] Using python: $($py.Source)" -ForegroundColor Green
    if (-not (Test-Path (Join-Path $ProjectDir ".venv"))) {
        Write-Host "Creating .venv..." -ForegroundColor DarkGray
        try {
            & $py.Source -m venv (Join-Path $ProjectDir ".venv")
            if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
        }
        catch { Pause-OnError $_.Exception.Message }
    }

    Activate-Venv
    if (-not $PythonExe) { $PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe" }
    if (-not (Test-Path $PythonExe)) { Pause-OnError "venv python not found at $PythonExe" }

    Write-Host ""
    Write-Host "[2/3] Installing requirements via pip..." -ForegroundColor Green
    try {
        & $PythonExe -m pip install --upgrade pip
        & $PythonExe -m pip install -r (Join-Path $ProjectDir "requirements.txt")
        if ($LASTEXITCODE -ne 0) { throw "pip install failed (exit $LASTEXITCODE)" }
    }
    catch { Pause-OnError $_.Exception.Message }

    Write-Host ""
    Write-Host "[3/3] 🚀 Starting CAD backend  ->  http://$HostAddr`:$Port" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray
    Write-Host "Tip: after startup, open http://localhost:$Port/health to verify." -ForegroundColor DarkGray
    Write-Host ""
    try {
        & $PythonExe -m uvicorn cad_backend:app --host $HostAddr --port $Port --reload
    }
    catch { Pause-OnError $_.Exception.Message }
    exit $LASTEXITCODE
}

Pause-OnError @"
Neither 'uv' nor 'py' nor 'python' found in PATH.

👉 Install Python 3.9.18 from:
   https://www.python.org/downloads/release/python-3918/
   ☑️  Tick "Add Python to PATH" during install.

Then re-run this script, or install uv directly:
   powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
"@
