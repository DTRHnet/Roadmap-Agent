REM Forwarder to scripts\windows\setup-rma.ps1 (repo root = parent of launchers/)
@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\windows\setup-rma.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\windows\setup-rma.ps1" %*
)
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
