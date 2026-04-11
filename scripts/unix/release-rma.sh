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
# Summary: Maintainer release pipeline — VERSION + CHANGELOG section → notes file, git tag, docker build, git push, gh release.
# Notes: Run from toolkit repo root (or via `roadmap-agent release`). Requires clean tag for first push; optional docker and GitHub CLI. See `release --help` and DOCS/RELEASING.md. Set RMA_RELEASE_REPO_ROOT to the toolkit root when running from a temp LF-normalized copy (CRLF-safe).
# Last updated: 2026-04-10 | Version: v1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${RMA_RELEASE_REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd "$RMA_RELEASE_REPO_ROOT" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
cd "$REPO_ROOT"

VERSION_FILE="$REPO_ROOT/VERSION"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
DRY_RUN=0
SKIP_DOCKER=0
SKIP_TAG=0
SKIP_PUSH=0
SKIP_GH=0
ASSUME_YES=0
IMAGE_NAME="${RMA_RELEASE_IMAGE_NAME:-roadmap-agent}"

usage() {
  cat <<'EOF'
Usage: release-rma.sh [options]

  Reads VERSION and extracts the matching ## [x.y.z] section from CHANGELOG.md,
  then (unless skipped or --dry-run):
    - creates an annotated git tag v<x.y.z>
    - builds Docker image(s) <name>:<x.y.z> and <name>:latest
    - git push origin v<x.y.z>
    - gh release create (requires GitHub CLI, authenticated)

Options:
  --dry-run Print planned steps only; do not run git/docker/gh
  --skip-docker          Do not run docker build
  --skip-tag             Do not create git tag
  --skip-push            Do not git push the tag
  --skip-github-release  Do not run gh release create
  -y, --yes              Non-interactive; proceed without confirmation

Environment:
  RMA_RELEASE_IMAGE_NAME   Docker image basename (default: roadmap-agent)

Requires:
  git, docker (unless --skip-docker), gh (unless --skip-github-release), clean-ish repo recommended.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --skip-docker) SKIP_DOCKER=1; shift ;;
    --skip-tag) SKIP_TAG=1; shift ;;
    --skip-push) SKIP_PUSH=1; shift ;;
    --skip-github-release) SKIP_GH=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

log() { printf '%s\n' "$1"; }
warn() { printf 'WARN: %s\n' "$1" >&2; }

read_version() {
  [[ -f "$VERSION_FILE" ]] || { warn "Missing $VERSION_FILE"; return 1; }
  tr -d '\r' < "$VERSION_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n1 | sed 's/^v//'
}

extract_changelog_body() {
  local ver="$1"
  [[ -f "$CHANGELOG" ]] || { warn "Missing $CHANGELOG"; return 1; }
  awk -v ver="$ver" '
    $0 ~ "^## \\[" ver "\\]" { p=1; next }
    p && $0 ~ /^## / { exit }
    p { print }
  ' "$CHANGELOG"
}

VER="$(read_version)" || exit 1
[[ -n "$VER" ]] || { warn "VERSION is empty"; exit 1; }

NOTES_BODY="$(extract_changelog_body "$VER")"
if [[ -z "${NOTES_BODY// }" ]]; then
  warn "No CHANGELOG section matching ## [$VER] — add a dated release block before releasing."
  exit 1
fi

TAG="v${VER}"
NOTES_FILE="${TMPDIR:-/tmp}/rma-release-notes-${VER}.txt"
{
  printf '%s\n\n' "## ROADMAP-AGENT ${VER}"
  printf '%s\n' "$NOTES_BODY"
  printf '\n---\n_See [CHANGELOG.md](CHANGELOG.md) in the repository for full history._\n'
} > "$NOTES_FILE"

log "=== ROADMAP-AGENT release ==="
log "Repository: $REPO_ROOT"
log "Version:    $VER (tag $TAG)"
log "Image:      ${IMAGE_NAME}:${VER} / ${IMAGE_NAME}:latest"
log ""
log "— Generated release notes (${NOTES_FILE}) —"
cat "$NOTES_FILE"
log ""
log "— End notes —"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] Would run: git tag; docker build; git push; gh release create"
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  warn "Not a git repository."
  exit 1
fi

if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  warn "Working tree is not clean. Commit or stash before tagging, or use --dry-run."
  if [[ "$ASSUME_YES" -eq 0 ]]; then
    read -r -p "Continue anyway? [y/N] " _c
    [[ "${_c:-}" =~ ^[Yy]$ ]] || exit 1
  fi
fi

if [[ "$ASSUME_YES" -eq 0 ]] && [[ -t 0 ]]; then
  read -r -p "Proceed with tag ${TAG}, Docker build, and GitHub release? [y/N] " _go
  [[ "${_go:-}" =~ ^[Yy]$ ]] || { log "Aborted."; exit 1; }
fi

if [[ "$SKIP_TAG" -eq 0 ]]; then
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    warn "Tag $TAG already exists locally."
  else
    git tag -a "$TAG" -m "ROADMAP-AGENT ${VER}"
    log "Created tag $TAG"
  fi
else
  log "[skip] git tag"
fi

if [[ "$SKIP_DOCKER" -eq 0 ]]; then
  if command -v docker >/dev/null 2>&1; then
    docker build -f "$REPO_ROOT/Dockerfile" -t "${IMAGE_NAME}:${VER}" -t "${IMAGE_NAME}:latest" "$REPO_ROOT"
    log "Docker build OK: ${IMAGE_NAME}:${VER}, ${IMAGE_NAME}:latest"
    log "Push manually if needed, e.g.: docker push ${IMAGE_NAME}:${VER}"
  else
    warn "docker not found; skipping image build."
  fi
else
  log "[skip] docker build"
fi

if [[ "$SKIP_PUSH" -eq 0 ]]; then
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    if git remote get-url origin >/dev/null 2>&1; then
      if git push origin "$TAG"; then
        log "Pushed $TAG"
      else
        warn "git push origin $TAG failed (tag may already exist on remote)."
      fi
    else
      warn "No git remote 'origin'; skipped push. Add remote and run: git push origin $TAG"
    fi
  else
    warn "Tag $TAG missing; cannot push."
  fi
else
  log "[skip] git push"
fi

if [[ "$SKIP_GH" -eq 0 ]]; then
  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      if gh release view "$TAG" >/dev/null 2>&1; then
        warn "GitHub release for $TAG may already exist; skipping gh release create."
        log "To update notes: gh release edit $TAG --notes-file \"$NOTES_FILE\""
      else
        gh release create "$TAG" --title "ROADMAP-AGENT ${VER}" --notes-file "$NOTES_FILE"
        log "GitHub release created for $TAG"
      fi
    else
      warn "gh not authenticated — run: gh auth login"
      log "Create release manually with notes from: $NOTES_FILE"
    fi
  else
    warn "GitHub CLI (gh) not installed — skipping gh release create."
    log "Install: https://cli.github.com/ — or upload notes from: $NOTES_FILE"
  fi
else
  log "[skip] gh release create"
fi

log ""
log "Release pipeline finished. Notes file kept at: $NOTES_FILE"
exit 0
