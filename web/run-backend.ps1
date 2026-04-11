# Start FastAPI dev server (reload). Run from anywhere; resolves repo root automatically.
# Uses project .rma\venv\Scripts\python.exe when present (Windows). Avoids activating a
# WSL/Linux venv from PowerShell (that causes "did not find executable at '/usr/bin\python.exe'").
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repo = Resolve-Path (Join-Path $here "..")
$backend = Join-Path $here "backend"
$req = Join-Path $repo "requirements-web.txt"

$projRoot = $repo.Path
if ($env:ROADMAP_AGENT_PROJECT_ROOT -and (Test-Path -LiteralPath $env:ROADMAP_AGENT_PROJECT_ROOT)) {
  $projRoot = (Resolve-Path $env:ROADMAP_AGENT_PROJECT_ROOT).Path
}

$venvWin = Join-Path $projRoot ".rma\venv\Scripts\python.exe"
$venvUnix = Join-Path $projRoot ".rma\venv\bin\python"

if ((Test-Path -LiteralPath $venvUnix) -and -not (Test-Path -LiteralPath $venvWin)) {
  Write-Host @"
WARN: .rma\venv looks like a Linux/WSL venv (bin\python) but you are in PowerShell.
      pip/python will break. Remove it and recreate from Windows:
        Remove-Item -Recurse -Force "$projRoot\.rma\venv"
      Then run: .\launchers\rma.ps1 web-api   (Git Bash) or use setup-venv from Windows Python.
"@ -ForegroundColor Yellow
  exit 1
}

$py = $null
if (Test-Path -LiteralPath $venvWin) {
  $py = $venvWin
}
else {
  $pyCmd = Get-Command py -ErrorAction SilentlyContinue
  if ($pyCmd) {
    $py = "py"
    $pyArgsPrefix = @("-3")
  }
  else {
    $p = Get-Command python -ErrorAction SilentlyContinue
    if (-not $p) { $p = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($p) { $py = $p.Source }
  }
}

if (-not $py) {
  Write-Error "Python not found. Install Python 3, or create .rma\venv (e.g. rma web-api / rma setup-venv from Git Bash)."
  exit 1
}

if (-not (Test-Path -LiteralPath $venvWin)) {
  Write-Host "INFO: No Windows venv at $venvWin — using: $py (consider: rma web-api to create .rma\venv)" -ForegroundColor DarkYellow
}

$env:RMA_WEB_APP_ROOT = $repo.Path
if (-not $env:PIP_DEFAULT_TIMEOUT) { $env:PIP_DEFAULT_TIMEOUT = "120" }

Set-Location $backend
if ($py -eq "py") {
  & py @("-3", "-m", "pip", "install", "--retries", "8", "--default-timeout=$($env:PIP_DEFAULT_TIMEOUT)", "-r", $req)
  & py @("-3", "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8765", "--reload")
}
else {
  & $py -m pip install --retries 8 "--default-timeout=$($env:PIP_DEFAULT_TIMEOUT)" -r $req
  & $py -m uvicorn app.main:app --host 127.0.0.1 --port 8765 --reload
}
