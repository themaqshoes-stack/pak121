# Run inside PowerShell — no more "term not recognized" errors.
# Run this ONCE per PowerShell session, then type short names:
#
#   Run-Check      -> python check_setup.py
#   Run-Install    -> runs install_and_run.bat
#   Run-Backend    -> runs install_and_run.bat (alias)
#   Run-PSBackend  -> powershell -File run_backend.ps1 (with bypass)

function Invoke-InProject {
    param([scriptblock]$Code)
    $here = Split-Path -Parent $MyInvocation.PSCommandPath
    Push-Location $here
    try { & $Code } finally { Pop-Location }
}

function Run-Check     { Invoke-InProject { python check_setup.py } }
function Run-Install   { Invoke-InProject { & ".\install_and_run.bat" } }
function Run-Backend   { Run-Install }
function Run-PSBackend {
    $f = Join-Path (Split-Path -Parent $MyInvocation.PSCommandPath) "run_backend.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $f
}

Set-Alias start-cad Run-Backend -Scope Global
Set-Alias install-cad Run-Install -Scope Global -Option AllScope -Force

Write-Host "✅ CAD helpers loaded in this session. Type: " -ForegroundColor Green
Write-Host "    Run-Check     -> check if python + deps are installed" -ForegroundColor Cyan
Write-Host "    Run-Install   -> install deps (if needed) + start backend" -ForegroundColor Cyan
Write-Host "    Run-Backend   -> same as Run-Install" -ForegroundColor Cyan
Write-Host "    start-cad     -> same (short alias)" -ForegroundColor Cyan
Write-Host ""
