# '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#  ____   ___    ____  ___    ___ ___   ____  ____          ____   ____    ___  ____   ______ 
# |    \ /   \  /    ||   \  |   |   | /    ||    \        /    | /    |  /  _]|    \ |      |
# |  D  )     ||  o  ||    \ | _   _ ||  o  ||  o  )_____ |  o  ||   __| /  [_ |  _  ||      |
# |    /|  O  ||     ||  D  ||  \_/  ||     ||   _/|     ||     ||  |  ||    _]|  |  ||_|  |_|
# |    \|     ||  _  ||     ||   |   ||  _  ||  |  |_____||  _  ||  |_ ||   [_ |  |  |  |  |  
# |  .  \     ||  |  ||     ||   |   ||  |  ||  |         |  |  ||     ||     ||  |  |  |  |  
# |__|\_|\___/ |__|__||_____||___|___||__|__||__|         |__|__||___,_||_____||__|__|  |__|  
#                                                                                             
# A DTRHnet Project                                              2026 <admin[at]dtrh[dot]net>
# -------------------------------------------------------------------------------------------
# Summary: Windows helper script for local MemPalace model setup.
# Last updated: 2026-04-10 | Version: v0.1.0

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LogDir = Join-Path $RootDir ".rma/logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

Write-Host "Starting local model setup for MemPalace..."
if (Get-Command python -ErrorAction SilentlyContinue) {
    try { python -m pip install --upgrade pip | Out-Null } catch {}
    try { python -m pip install mempalace chromadb | Out-Null } catch {}
}
Add-Content -Path (Join-Path $LogDir "setup-local-models.log") -Value "$(Get-Date -Format o) local-model-setup complete (best effort)"
Write-Host "Local model setup complete (best effort)."
