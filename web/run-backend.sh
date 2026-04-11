#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
export RMA_WEB_APP_ROOT="$repo"

proj="${ROADMAP_AGENT_PROJECT_ROOT:-$repo}"
if [[ -d "$proj" ]]; then
  proj="$(cd "$proj" && pwd)"
fi

export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-120}"

py=""
if [[ -x "$proj/.rma/venv/bin/python" ]]; then
  py="$proj/.rma/venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  py="$(command -v python3)"
else
  py="$(command -v python)"
fi

if [[ -z "$py" ]]; then
  echo "ERROR: python3 not found. Create .rma/venv or install Python." >&2
  exit 1
fi

cd "$here/backend"
"$py" -m pip install --retries 8 --default-timeout="$PIP_DEFAULT_TIMEOUT" -r "$repo/requirements-web.txt"
listen_host="${RMA_WEB_HOST:-127.0.0.1}"
listen_port="${RMA_WEB_PORT:-8765}"
exec "$py" -m uvicorn app.main:app --host "$listen_host" --port "$listen_port" --reload
