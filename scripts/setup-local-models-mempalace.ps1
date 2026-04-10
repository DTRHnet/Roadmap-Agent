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
