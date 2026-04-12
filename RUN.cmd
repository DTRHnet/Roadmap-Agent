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
REM Summary: CMD stub that runs RUN.ps1 via pwsh or Windows PowerShell.
REM Notes: Prefer RUN.ps1 directly from PowerShell; this file is for double-click and cmd.exe users.
REM Last updated: 2026-04-10 | Version: v1.1.1-b

@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PS=%ProgramFiles%\PowerShell\7\pwsh.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN.ps1" %*
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%
