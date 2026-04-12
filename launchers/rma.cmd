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
REM Summary: Windows CMD alias — delegates to roadmap-agent.cmd with the same arguments.
REM Notes: Keeps one implementation path for the PowerShell bridge.
REM Last updated: 2026-04-10 | Version: v1.1.1-b

@echo off
setlocal
set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%roadmap-agent.cmd" %*
