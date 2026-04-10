#!/usr/bin/env bash
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SELF_DIR/roadmap-agent.sh" "$@"
