#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
export RMA_WEB_APP_ROOT="$repo"
cd "$here/backend"
python3 -m pip install -q -r "$repo/requirements-web.txt"
exec python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8765 --reload
