@echo off
REM Thin wrapper — forwards to scripts\windows\setup-rma.ps1
REM Last updated: 2026-04-10 | Version: v1.0.0
setlocal
set "ROOT=%~dp0"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\windows\setup-rma.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\windows\setup-rma.ps1" %*
)
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
