#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/.rma/logs"
mkdir -p "$LOG_DIR"

echo "Starting local model setup for MemPalace..."
if command -v python >/dev/null 2>&1; then
  python -m pip install --upgrade pip >/dev/null 2>&1 || true
  python -m pip install mempalace chromadb >/dev/null 2>&1 || true
fi
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") local-model-setup complete (best effort)" >> "$LOG_DIR/setup-local-models.log"
echo "Local model setup complete (best effort)."
