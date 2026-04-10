REM '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
REM  ____   ___    ____  ___    ___ ___   ____  ____          ____   ____    ___  ____   ______ 
REM |    \ /   \  /    ||   \  |   |   | /    ||    \        /    | /    |  /  _]|    \ |      |
REM |  D  )     ||  o  ||    \ | _   _ ||  o  ||  o  )_____ |  o  ||   __| /  [_ |  _  ||      |
REM |    /|  O  ||     ||  D  ||  \_/  ||     ||   _/|     ||     ||  |  ||    _]|  |  ||_|  |_|
REM |    \|     ||  _  ||     ||   |   ||  _  ||  |  |_____||  _  ||  |_ ||   [_ |  |  |  |  |  
REM |  .  \     ||  |  ||     ||   |   ||  |  ||  |         |  |  ||     ||     ||  |  |  |  |  
REM |__|\_|\___/ |__|__||_____||___|___||__|__||__|         |__|__||___,_||_____||__|__|  |__|  
REM                                                                                             
REM A DTRHnet Project                                              2026 <admin[at]dtrh[dot]net>
REM -------------------------------------------------------------------------------------------
REM Summary: Windows CMD launcher that routes to PowerShell runtime.
REM Last updated: 2026-04-10 | Version: v0.4.0

@echo off
setlocal
set SCRIPT_DIR=%~dp0
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\\windows\\roadmap-agent.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\\windows\\roadmap-agent.ps1" %*
)
