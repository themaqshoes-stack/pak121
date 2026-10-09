@echo off
REM ============================================================
REM  CAD BACKEND - FULL INSTALL + RUN - MOST RELIABLE (Windows CMD)
REM  No uv needed. No py launcher needed. Uses python.exe directly.
REM ============================================================
setlocal enableextensions enabledelayedexpansion
cd /d "%~dp0"

set "PORT=8000"
set "HOST=0.0.0.0"

echo ============================================================
echo   CAD Backend - Installer + Runner
echo   Folder: %cd%
echo ============================================================
echo.

REM --- Find python.exe ---
set "PYEXE="
where python >nul 2>nul
if %ERRORLEVEL%==0 set "PYEXE=python"
if not defined PYEXE (
    where py >nul 2>nul
    if %ERRORLEVEL%==0 set "PYEXE=py"
)
REM Try common install locations
if not defined PYEXE if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PYEXE if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
if not defined PYEXE if exist "%LOCALAPPDATA%\Programs\Python\Python39\python.exe"  set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
if not defined PYEXE if exist "C:\Python39\python.exe"                               set "PYEXE=C:\Python39\python.exe"
if not defined PYEXE if exist "C:\Python310\python.exe"                              set "PYEXE=C:\Python310\python.exe"
if not defined PYEXE if exist "C:\Python311\python.exe"                              set "PYEXE=C:\Python311\python.exe"

if not defined PYEXE (
    echo.
    echo [ERROR] python.exe not found.
    echo.
    echo 👉 Install Python from https://www.python.org/downloads/
    echo    (Recommended: Python 3.10 or 3.11 x64
    echo    IMPORTANT: Tick "Add Python to PATH" BEFORE clicking Install.
    echo.
    echo    Then re-run this script.
    echo.
    pause
    exit /b 1
)

echo [1/5] Using Python at: %PYEXE%
"%PYEXE%" --version
echo.

REM --- Create / reuse venv ---
echo [2/5] Setting up virtual environment (.venv)...
if not exist .venv (
    "%PYEXE%" -m venv .venv
    if errorlevel 1 goto :err
)

set "VENV_PY=%cd%\.venv\Scripts\python.exe"
if not exist "%VENV_PY%" (
    echo [ERROR] venv python missing at: %VENV_PY%
    pause
    exit /b 1
)

REM --- Upgrade pip ---
echo [3/5] Upgrading pip...
"%VENV_PY%" -m pip install --upgrade pip
if errorlevel 1 goto :err

REM --- Install requirements ---
echo [4/5] Installing dependencies (this may take 3-10 minutes)...
"%VENV_PY%" -m pip install -r requirements.txt
if errorlevel 1 (
    echo.
    echo [WARN] Full requirements.txt failed. Trying staged install (safer)...
    echo.
    "%VENV_PY%" -m pip install --upgrade pip setuptools wheel six
    "%VENV_PY%" -m pip install "numpy==1.26.4"
    "%VENV_PY%" -m pip install "opencv-python==4.10.0.84"
    "%VENV_PY%" -m pip install "onnxruntime==1.19.2"
    "%VENV_PY%" -m pip install "rembg==2.0.61"
    "%VENV_PY%" -m pip install "python-dotenv==1.0.1"
    "%VENV_PY%" -m pip install "fastapi==0.115.0"
    "%VENV_PY%" -m pip install "uvicorn[standard]==0.30.6"
    "%VENV_PY%" -m pip install "python-multipart==0.0.9"
    if errorlevel 1 goto :err
    echo.
    echo [INFO] Core deps OK. Now trying cadquery...
    "%VENV_PY%" -m pip install "cadquery==2.5.2"
    if errorlevel 1 (
        echo.
        echo [ERROR] cadquery failed to install. Possible fixes:
        echo   1. Ensure 64-bit Python only (NOT 32-bit - uninstall 32-bit and install x64)
        echo   2. Install VC++ Redist x64: https://aka.ms/vs/17/release/vc_redist.x64.exe
        echo   3. OR use Miniconda + conda-forge:
        echo        conda create -n cad python=3.11 -y ^&^& conda activate cad ^&^& conda install -c conda-forge cadquery -y
        echo.
        pause
        exit /b 1
    )
)

REM --- Verify imports ---
echo.
echo [5/5] Verifying imports...
"%VENV_PY%" check_setup.py
if errorlevel 1 goto :err

echo.
echo ============================================================
echo   All good.
echo   Starting CAD Backend...
echo   URL : http://localhost:%PORT%/health
echo   API : http://localhost:%PORT%/api/v1/convert/image-to-step
echo   Press Ctrl+C to stop.
echo ============================================================
echo.

"%VENV_PY%" -m uvicorn cad_backend:app --host %HOST% --port %PORT% --reload
goto :eof

:err
echo.
echo ============================================================
echo  [ERROR] Last step failed (exit %errorlevel%).
echo ============================================================
echo.
echo 👉 Scroll UP to see the exact red error lines.
echo.
echo  If you see RED error - screenshot/copy it and send to fix.
echo.
pause
exit /b %errorlevel%
