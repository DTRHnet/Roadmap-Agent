# Troubleshooting

Common ROADMAP-AGENT issues and resolutions.

## 1) `WARN: Missing .rma/...`

Cause:

- metadata not initialized or files removed.

Fix:

```bash
roadmap-agent init
```

Then populate:

- `.rma/description.md`
- `.rma/ui.md`
- `.rma/stack.md`
- `.rma/other.md`

## 2) `fzf` not found / menu does not open

Cause:

- `fzf` missing or not available in current terminal PATH.

Fix:

- re-run `roadmap-agent` and allow auto-install prompt behavior.
- or install manually from [fzf releases](https://github.com/junegunn/fzf/releases).
- restart terminal session.

## 3) `execute-one` says no plan found

Cause:

- plan file not generated yet.

Fix:

```bash
roadmap-agent plan
roadmap-agent execute-one
```

## 4) Agent is locked

Cause:

- interrupted execution left stale lock state.

Fix:

```bash
roadmap-agent unlock
```

Then rerun `execute-one`.

## 5) `plan` or safe mine fails / doctor shows MemPalace WARN

Cause:

- **`mempalace` CLI** not on `PATH` (often missing pip install into `.rma/venv`), or Python cannot **`import mempalace`** / **`import chromadb`**.
- **`RMA_REQUIRE_MEMPALACE=1`** (default) surfaces this in **doctor** and the runtime warnings panel.

Fix:

- Run **`scripts/unix/setup-local-models-mempalace.sh`** or **`scripts/windows/setup-local-models-mempalace.ps1`** from the project root so the venv gets the packages and the `mempalace` console script.
- Ensure **`configure_python_runtime`** runs (normal `rma` / `roadmap-agent` entry) so the venv’s `bin` is on `PATH`, or set **`RMA_MEMPALACE_BIN`** to the full path of the `mempalace` executable.
- **Dev-only:** set **`RMA_ALLOW_PLAN_FALLBACK=1`** if you need a generic markdown plan when MemPalace is broken (logged to `EXEC_LOG`). This does **not** apply to **mine** — mine always requires a working CLI.

## 6) Git metadata not showing expected values

Cause:

- not in git repo, no commits yet, or no tags.

Fix:

- initialize git and create at least one commit
- add release tags to enable release version/date display

## 7) Shell script issues on Windows

Cause:

- script execution mode mismatch.

Fix:

- use `roadmap-agent.cmd` or `rma.ps1` on Windows
- use `roadmap-agent`/`.sh` in bash-compatible environments

## 8) Docker run cannot access project files

Cause:

- missing volume mount.

Fix:

```bash
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

## 9) What to collect before filing an issue

- command used
- exact output/error
- OS and shell
- whether `.rma/` exists
- `git status` state
- whether `fzf` and `mempalace` are installed
