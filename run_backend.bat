@echo off
REM ============================================================
REM  Image-to-STEP CAD Backend - ONE-CLICK RUNNER (Windows)
REM  Tries: 1) uv  -> 2) py -m pip venv -> 3) python -m pip venv
REM ============================================================
setlocal
cd /d "%~dp0"

set PORT=8000
set HOST=0.0.0.0

where uv >nul 2>nul
if %ERRORLEVEL%==0 (
    echo [1/3] uv found. Syncing dependencies...
    call uv sync
    if errorlevel 1 goto :error
    echo.
    echo [2/3] Starting CAD backend with uv on http://%HOST%:%PORT% ...
    call uv run uvicorn cad_backend:app --host %HOST% --port %PORT% --reload
    goto :eof
)

where py >nul 2>nul
if %ERRORLEVEL%==0 (
    echo [1/3] Python Launcher (py) found. Creating venv with py...
    if not exist .venv call py -3.9 -m venv .venv
    if errorlevel 1 call py -m venv .venv
    if errorlevel 1 goto :error
    call .venv\Scripts\activate.bat
    echo [2/3] Installing requirements via pip...
    python -m pip install --upgrade pip
    python -m pip install -r requirements.txt
    if errorlevel 1 goto :error
    echo.
    echo [3/3] Starting CAD backend on http://%HOST%:%PORT% ...
    python -m uvicorn cad_backend:app --host %HOST% --port %PORT% --reload
    goto :eof
)

where python >nul 2>nul
if %ERRORLEVEL%==0 (
    echo [1/3] python.exe found. Creating venv...
    if not exist .venv call python -m venv .venv
    if errorlevel 1 goto :error
    call .venv\Scripts\activate.bat
    echo [2/3] Installing requirements via pip...
    python -m pip install --upgrade pip
    python -m pip install -r requirements.txt
    if errorlevel 1 goto :error
    echo.
    echo [3/3] Starting CAD backend on http://%HOST%:%PORT% ...
    python -m uvicorn cad_backend:app --host %HOST% --port %PORT% --reload
    goto :eof
)

echo.
echo [ERROR] Neither "uv" nor "py" nor "python" found in PATH.
echo         Please install Python 3.9.18 from https://www.python.org/downloads/release/python-3918/
echo         (Check "Add Python to PATH" during installation, then re-run this script.)
echo.
pause
exit /b 1

:error
echo.
echo [ERROR] Last command failed with exit code %ERRORLEVEL%. See messages above.
echo.
echo TIP: Try running check_setup.py first to see exactly what is missing:
echo        python check_setup.py
echo.
pause
exit /b %ERRORLEVEL%
