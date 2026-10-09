@echo off
REM ============================================================
REM  PYTHON + DEPENDENCY ONE-CLICK INSTALLER (PREVIEW PREP)
REM  Downloads + installs Python 3.11 x64 silently if missing,
REM  then runs CAD backend installer.
REM  If Python already installed, skips straight to backend install.
REM ============================================================
setlocal
cd /d "%~dp0"

echo ============================================================
echo   Checking for real Python installation (x64)...
echo ============================================================
echo.

REM ---------------- Find real Python (NOT the Store stub) ----------------
set "PYEXE="
set "VFY=no"

if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
    set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    goto :verify
)
if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" (
    set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
    goto :verify
)
if exist "%LOCALAPPDATA%\Programs\Python\Python39\python.exe" (
    set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
    goto :verify
)
if exist "C:\Python311\python.exe" set "PYEXE=C:\Python311\python.exe"  & goto :verify
if exist "C:\Python310\python.exe" set "PYEXE=C:\Python310\python.exe"  & goto :verify
if exist "C:\Python39\python.exe"  set "PYEXE=C:\Python39\python.exe"   & goto :verify

REM Fall back to PATH lookup, but validate it's not the WindowsApps stub
where python >nul 2>nul
if %ERRORLEVEL%==0 (
    for /f "delims=" %%i in ('where python ^| findstr /v /i "WindowsApps"') do set "PYEXE=%%i"
    if defined PYEXE goto :verify
)

:verify
if defined PYEXE (
    "%PYEXE%" -c "import sys; v=sys.version_info; sys.exit(0 if (v.major==3 and v.minor>=9 and v.minor<=12) else 1)" 2>nul
    if %ERRORLEVEL%==0 set "VFY=yes"
)

if "%VFY%"=="yes" (
    echo ✅ Real Python found at:
    echo    %PYEXE%
    echo.
    goto :install_vcredist
)

REM ---------------- Python NOT found -> download + install ----------------
echo ❌ REAL Python NOT found.
echo    (The "python" in PATH is likely the Microsoft Store placeholder stub.)
echo.
echo ⚠️   Python will now be installed silently using official installer.
echo     This may take ~1-3 minutes.
echo.
pause

set "PY_INST_EXE=%TEMP%\python-3.11.9-amd64.exe"
set "PY_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"

if not exist "%PY_INST_EXE%" (
    echo [1/3] Downloading Python 3.11.9 x64...
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%PY_URL%', '%PY_INST_EXE%')"
    if errorlevel 1 (
        echo [ERROR] Python download failed.
        echo   Please manually install Python from:
        echo   https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
        echo   ☑️  Tick "Add Python to PATH" during install ^!
        pause
        exit /b 1
    )
)

echo [2/3] Installing Python (quiet mode, adds to PATH + installs pip)...
"%PY_INST_EXE%" /quiet InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_tcltk=1 Include_test=0 Include_launcher=1
if errorlevel 1 (
    echo [ERROR] Python installer failed.
    pause
    exit /b 1
)

set "PYEXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
echo [3/3] Python installed at: %PYEXE%
echo.

:install_vcredist
REM ---------------- Install VC++ Redistributable (needed for cadquery + onnx) ----------------
where VC_redist.x64.exe >nul 2>nul
echo Checking Visual C++ Redistributable (cadquery/onnx need this)...
REM Quick heuristic: try importing a c-extension. If it fails, silently install VCRedist.
"%PYEXE%" -c "import numpy, ctypes; ctypes.windll.LoadLibrary('msvcp140.dll')" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  VC++ runtimes missing — installing VC++ 2022 Redistributable x64...
    set "VC_EXE=%TEMP%\VC_redist.x64.exe"
    if not exist "%VC_EXE%" (
        powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('https://aka.ms/vs/17/release/vc_redist.x64.exe', '%VC_EXE%')"
    )
    if exist "%VC_EXE%" (
        "%VC_EXE%" /install /quiet /norestart
        echo VC++ install done (exit %ERRORLEVEL%).
    )
) else (
    echo ✅ VC++ runtime OK.
)

REM ---------------- Launch actual backend installer ----------------
echo.
echo ============================================================
echo   Starting CAD Backend install + run...
echo ============================================================
echo.

REM Refresh PATH so newly-installed python is visible in this batch session
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"

REM Call our full install-and-run script
call "%~dp0install_and_run.bat"

exit /b %ERRORLEVEL%
