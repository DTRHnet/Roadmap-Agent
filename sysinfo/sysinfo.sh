#!/usr/bin/env bash
# Thin launcher: runs sysinfo.py with the same Python that resolves `python3` or `python`.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$SCRIPT_DIR/sysinfo.py" "$@"
fi
if command -v python >/dev/null 2>&1; then
  exec python "$SCRIPT_DIR/sysinfo.py" "$@"
fi
echo "sysinfo.sh: no python3/python on PATH" >&2
exit 127
