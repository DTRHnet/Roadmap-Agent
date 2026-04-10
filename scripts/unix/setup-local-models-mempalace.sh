#!/usr/bin/env bash
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
# Summary: Unix helper script for local MemPalace model setup.
# Last updated: 2026-04-10 | Version: v0.1.0

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
