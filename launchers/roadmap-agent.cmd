REM Launchers live in launchers/; repo root is parent of this directory.
@echo off
setlocal
for %%I in ("%~dp0..") do set "REPO=%%~fI"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%REPO%\scripts\windows\roadmap-agent.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO%\scripts\windows\roadmap-agent.ps1" %*
)
