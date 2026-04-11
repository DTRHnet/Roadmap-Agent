#!/usr/bin/env bash
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"
exec bash "$REPO_ROOT/scripts/unix/roadmap-agent.sh" "$@"
