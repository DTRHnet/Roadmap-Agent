# Start FastAPI dev server (reload). Run from anywhere; resolves repo root automatically.
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repo = Resolve-Path (Join-Path $here "..")
$backend = Join-Path $here "backend"
$req = Join-Path $repo "requirements-web.txt"
Set-Location $backend
$env:RMA_WEB_APP_ROOT = $repo.Path
python -m pip install -q -r $req
python -m uvicorn app.main:app --host 127.0.0.1 --port 8765 --reload
