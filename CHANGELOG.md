# Changelog

All notable changes to ROADMAP-AGENT are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and uses semantic versioning intent.

## [Unreleased]

### Added

- **`release`** CLI and **hub option VI**: run [`scripts/unix/release-rma.sh`](scripts/unix/release-rma.sh) to build release notes from **`CHANGELOG.md`**, create **`VERSION`** git tag, **`docker build`**, **`git push`**, and **`gh release create`** (when `gh` is available). See **`docs/RELEASING.md`**.
- **Hub VII / VIII** and CLI **`web-api`** (**`web-backend`**) / **`web-frontend`**: start the optional web stack from the same entrypoint as the rest of ROADMAP-AGENT — ensure **`.rma/venv`** (create with **`python3 -m venv`** if missing), **`pip install -r requirements-web.txt`** before **uvicorn**, and **`npm install`** before **Vite** (`scripts/unix/roadmap-agent.sh`).

### Documentation

- **Companion web UI**: expanded **[`web/README.md`](web/README.md)** (prerequisites, `RMA_WEB_*`, dev vs single-port vs Docker, security); linked and summarized from **[`README.md`](README.md)**, **[`docs/MANUAL.md`](docs/MANUAL.md)** (*Companion web UI*), **[`docs/QUICKSTART.md`](docs/QUICKSTART.md)**, **[`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md)**, **[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)**, **[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)**; **`.env.example`** comments for **`RMA_WEB_*`**.

## [1.0.0] - 2026-04-10

First **stable** semver release: project bootstrap, multi-provider agent, documented env, and layout polish.

### Added

- **`RUN.sh`**, **`RUN.ps1`**, **`RUN.cmd`**: one-shot workspace bootstrap (detect environment, optional persistence upgrade prompt, seed `.env`, run MemPalace venv setup for **current directory** as `ROADMAP_AGENT_PROJECT_ROOT`, then hand off to `roadmap-agent`). Setup scripts honor **`ROADMAP_AGENT_PROJECT_ROOT`** so venv and `.rma` stay in the project tree when the toolkit lives elsewhere; venv launchers set **`ROADMAP_AGENT_APP_ROOT`** to the toolkit and **`ROADMAP_AGENT_PROJECT_ROOT`** to the managed repo.
- **`.env.example`**: expanded comments for every supported variable, runtime roots, agent vs plan LLM usage, and WSL/Ollama notes.
- **`roadmap-agent agent` / `run-agent`**: honor **`RMA_LLM_PROVIDER`** end-to-end (**ollama**, **openllama**, **claude**), matching **`plan`** (previously the agent loop only called Ollama).
- **`rma tools --json`**: broader **`env`** list for external agents (OpenAI/Anthropic keys, `ROADMAP_AGENT_APP_ROOT`, etc.).
- **Hub** options **IV** (create/refresh Python venv + MemPalace deps) and **V** (pick a project `.env*` file and copy to `.env`, with backup). CLI: **`setup-venv`**, **`pick-env`**.
- **Windows persistence**: after `robocopy`, normalize **`scripts/unix/*.sh`** and root bash launchers to **LF** (`Sync-UnixShellScriptsToLf`) so WSL/bash are not broken by CRLF. **`roadmap-agent.ps1`** detects CRLF in `roadmap-agent.sh` and runs a normalized temp copy with a clear note.
- **`.gitattributes`**: force **LF** for `*.sh` and bash launchers so clones on Windows stay POSIX-safe.
- **Local model setup** (`setup-local-models-mempalace`): after the venv exists, installs **`rma`** and **`roadmap-agent`** shims into **`venv/bin`** (Unix) or **`venv/Scripts`** (`*.cmd` + `*.ps1`, Windows) so activating the venv puts the CLI on `PATH` for that project.
- **[`docs/RELEASING.md`](docs/RELEASING.md)**: how to tag releases, publish archives, and build the Docker image (this project is script-first; there is no mandatory compiled binary).

### Changed

- **Windows setup**: canonical **`scripts/windows/setup-rma.ps1`**; **`launchers/setup-rma.ps1`** / **`launchers/setup-rma.cmd`** are thin forwarders (same CLI as before).
- **Persistence sync checks** include **`RUN.*`**, **`setup-rma.*`**, and the canonical setup script path.

### Fixed

- **`roadmap-agent plan`** no longer invokes non-existent **`mempalace plan`** (upstream CLI has `init`, `mine`, `search`, `wake-up`, etc.). Plans are generated with the configured **LLM** and `.rma` context; optional **`mempalace wake-up --palace .rma/mempalace`** enriches the prompt when the palace directory exists.

## [0.4.0] - 2026-04-10

### Added

- **`roadmap-agent plan`** interactive **open questions**: when `RMA_PLAN_INTERACTIVE=1` (default) and stdin is a TTY, prompts for bullets in `.rma/open-questions.md` and for lines containing `Open:` in `.rma/description|ui|stack|other.md`; answers append to `.rma/other.md` before MemPalace runs. Use **`plan --no-interactive`** or **`RMA_PLAN_INTERACTIVE=0`** for CI. Env: **`RMA_PLAN_INTERACTIVE`**, **`RMA_PLAN_INTERACTIVE_MAX`**. **`init`** creates optional `.rma/open-questions.md` stub; **`doctor`** prints these vars.
- README section **MemPalace mining and the roadmap loop** (what mining is, directory / `--limit` / `--dry-run`, how it relates to `plan` → `execute-one` → `analyze`) and diagram [`img/roadmap-mining-and-loop.svg`](img/roadmap-mining-and-loop.svg).
- [`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md) — walkthrough: import tool, MemPalace, context files, **`plan`** (including interactive prompts), mining, **`execute-one`** / **`analyze`**.
- [`docs/examples/rma-context-samples/`](docs/examples/rma-context-samples/) — three sample projects (**`weather-app`**, **`list-sharing`**, **`devtools-cli`**) with `description.md`, `ui.md`, `stack.md`, `other.md`; index covers **MCP** vs MemPalace.

### Changed

- README, [`docs/examples/END-TO-END-LIST-SHARING-APP.md`](docs/examples/END-TO-END-LIST-SHARING-APP.md), and [`docs/ROADMAP-WORKFLOW.md`](docs/ROADMAP-WORKFLOW.md): clarify **iterated implementation** toward a real app—detailed MemPalace-backed roadmaps, prompting on gaps, **`execute-one`** as implementation spine. [`docs/MANUAL.md`](docs/MANUAL.md): **`plan`** section documents interactive questions; general context-file rule for driving detailed plans.

### Fixed

- [`img/roadmap-mining-and-loop.svg`](img/roadmap-mining-and-loop.svg): XML validity so the diagram renders in browsers and on GitHub.
- AI submenu **II / III** (`mempalace mine`): required project directory (`mempalace mine <dir>`), upstream **`--dry-run`**. Optional **`RMA_MEMPALACE_MINE_DIR`**.

## [0.3.0] - 2026-04-10

### Changed (Breaking)

- **MemPalace is required** for real `plan` and **safe mine** operations: removed simulated safe-mine log lines, removed placeholder `EXEC_LOG` entries when the setup script was missing, and removed silent `2>/dev/null` swallowing on `mempalace plan`.
- **`roadmap-agent plan`** now exits with a non-zero status if MemPalace cannot produce a plan, unless **`RMA_ALLOW_PLAN_FALLBACK=1`** is set (writes an explicit markdown template and logs the fallback to `EXEC_LOG`).
- New environment variables (see `.env.example` and `--help`): **`RMA_REQUIRE_MEMPALACE`** (default `1`), **`RMA_MEMPALACE_BIN`**, **`RMA_ALLOW_PLAN_FALLBACK`** (default `0`). `doctor` and the runtime warnings panel include a **[MemPalace]** section when strict mode is on.

### Removed

- [`scripts/windows/_tmp_noheader.ps1`](scripts/windows/_tmp_noheader.ps1) (unused; MemPalace logic lives in the Unix runtime).

### Added

- `resolve_mempalace_cmd`, `mempalace_python_imports_ok`, `mempalace_assert_ready`, and `write_plan_fallback_template` in [`scripts/unix/roadmap-agent.sh`](scripts/unix/roadmap-agent.sh).

## [0.2.0] - 2026-04-10

### Added

- `scripts/windows/refresh-rma-path.ps1` and **`launchers/refresh-rma-path.ps1`** to rebuild `PATH` in the current PowerShell session from Machine + User registry values (so `rma` works in the same window after persistence install).
- Windows `install-persistence.ps1` and `setup-rma.ps1` call the PATH refresh helper after a successful install.
- `VERSION` file at the repository root; `app_version` in the Unix runtime reads it first (then git tag, then dev snapshot).
- Expanded documentation set with practical usage guides in `docs/`.
- `docs/QUICKSTART.md` — per-OS quick start (Windows, Linux, macOS, Docker).
- Rewrote `docs/MANUAL.md` as a detailed operator manual (table of contents, commands, interactive mode, `.rma` authoring, LLM/env/persistence, security).
- Manual command support via `roadmap-agent man`.
- Unix manpage source at `docs/man/roadmap-agent.1`.
- Windows persistence installer script at `scripts/windows/install-persistence.ps1`.
- GitHub-oriented banner image `roadmap-agent-github-banner.png`.
- `docs/examples/MOCK-WORKFLOW-SESSION.md` — illustrative mock transcripts.

### Changed

- `README.md`: refreshed presentation; documentation index and MemPalace notes; linked `docs/QUICKSTART.md` and `docs/MANUAL.md` from Quick Start and the documentation index.
- Reorganized repository by operating system:
  - Windows runtime/scripts in `scripts/windows/`
  - Linux/macOS runtime/scripts in `scripts/unix/`
  - Docker entrypoint moved to `docker/entrypoint.sh`
- Updated root launchers to route into new OS-specific runtime locations.
- Updated Dockerfile paths and executable targets to match new layout.
- Updated menu display labels from `SUB::...` format to Roman numerals for cleaner UX.
- Added persistence health-check option (`persistence-check`) and menu entry to detect and optionally remediate missing global persistence.
- Implemented a Defender-safe Windows bridge runtime in `scripts/windows/roadmap-agent.ps1` that delegates full CLI execution to `scripts/unix/roadmap-agent.sh` through `bash` while keeping Windows persistence installation local.
- `docs/GETTING-STARTED.md`: links to `QUICKSTART.md` / `MANUAL.md`; Windows persistence notes updated for `setup-rma.ps1` user vs machine scope and PATH refresh.

## [0.1.0] - 2026-04-10

### Added

- Cross-platform launchers for Windows, Linux/macOS, and Docker.
- Core ROADMAP-AGENT runtime scripts:
  - `roadmap-agent.ps1`
  - `roadmap-agent.sh`
- Alias launchers:
  - `rma`, `rma.cmd`, `rma.ps1`, `rma.sh`
- Interactive `fzf`-driven menu with Local AI Memory Palace actions.
- `.rma/` initialization and required-file validation.
- Roadmap status, plan (dry run), execute-one, and unlock commands.
- MemPalace helper scripts:
  - `scripts/setup-local-models-mempalace.ps1`
  - `scripts/setup-local-models-mempalace.sh`
- Menu header project awareness:
  - project/branch/remote/goal signal/roadmap path
- Compact initial banner with:
  - app version auto-detection
  - last release version
  - release date
- Hub + AI submenu navigation flow.

### Notes

- Interactive behavior requires `fzf` and attempts local auto-install when missing.
- Some actions run in best-effort mode when external dependencies are unavailable.
