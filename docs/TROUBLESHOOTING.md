# Troubleshooting

Common ROADMAP-AGENT issues and resolutions.

## 1) `WARN: Missing .rma/...`

Cause:

- metadata not initialized or files removed.

Fix:

```bash
./launchers/roadmap-agent init
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

- use `launchers/roadmap-agent.cmd` or `launchers/rma.ps1` on Windows
- use `launchers/roadmap-agent` / `launchers/rma.sh` in bash-compatible environments

## 8) Docker run cannot access project files

Cause:

- missing volume mount.

Fix:

```bash
docker run --rm -it -v "$PWD:/workspace" roadmap-agent
```

## 9) pip / `.rma/venv` broken: `/usr/bin\python.exe`, or mixed WSL vs Windows

**Cause:** **`.rma/venv`** was created with one Python family (e.g. **WSL/Linux** → `bin/python` and `home = /usr/...` in `pyvenv.cfg`) but **PowerShell** or **Git Bash + Windows Python** then used the same folder. Windows `pip` can error with `did not find executable at '/usr/bin\python.exe'`. The opposite (only **`Scripts\python.exe`**) is unusable from **Linux/WSL** bash alone.

**Fix:**

- Use **one** environment per clone for the venv (always WSL, always Git Bash, or always PowerShell + Windows Python).
- Delete the broken venv and recreate from that shell:
  - **PowerShell:** `Remove-Item -Recurse -Force .\.rma\venv`
  - **Bash (Unix/WSL):** `rm -rf .rma/venv`
- Then run **`rma web-api`** / hub **Web & MCP → Start API**, or **`web/run-backend.ps1`**. The Unix runtime **removes and recreates** a mismatched venv automatically: **Git Bash** vs **Linux `bin/python`**, and **Linux/WSL** vs **Windows `Scripts\\python.exe`** (detection uses **file existence** on `/mnt/c/...` so NTFS venvs are not missed). **`pip install`** uses **`PIP_DEFAULT_TIMEOUT`** (default **120** seconds) and **`--retries 8`** on the MemPalace setup path (**`RUN.ps1`**, **`RUN.sh`**, **`setup-local-models-mempalace.*`**, web stack). Override before bootstrap: `$env:PIP_DEFAULT_TIMEOUT = "180"` (PowerShell) or `export PIP_DEFAULT_TIMEOUT=180` (bash); optional mirror: **`PIP_INDEX_URL`**.
- **`web/run-backend.ps1`** exits with a clear message if it sees only a Linux-style **`bin\python`** while you are in PowerShell.

## 10) Web UI: API errors, 401, or blank UI

**Symptoms:** browser shows **Unauthorized** /401 on save, **Doctor** or **Env** fails, Vite shows proxy errors, or Docker shows only JSON/OpenAPI.

**Checks:**

- **`RMA_WEB_ADMIN_TOKEN`**: if the backend was started with a token, open the UI field **Admin token** and paste the same value (sent as **`X-RMA-Web-Token`** on mutating requests).
- **Project root** in the UI must be an existing directory (your app repo with `.rma/` / `.env`).
- **Backend reachability:** dev mode expects API at **http://127.0.0.1:8765**; ensure **`web/run-backend.ps1`** or **`web/run-backend.sh`** is running.
- **Windows + `rma`:** the backend shells out to **`scripts/windows/roadmap-agent.ps1`** and still needs **Git Bash / WSL** behavior consistent with the CLI. Prefer **`web/run-backend.ps1`** over Docker on Windows when bridge tools are hard to reach from a container.
- **CORS:** if you use a non-default dev URL, set **`RMA_WEB_CORS_ORIGINS`** (comma-separated) to include that origin.
- **Docker:** without **`web/frontend/dist`** in the build context, open **http://127.0.0.1:8765/docs** or run **`npm run dev`** on the host against the mapped port. See **[`web/README.md`](../web/README.md)**.

## 11) Windows: `npm ci` / `npm install` **EPERM** on `node_modules` (`.node` native addon)

**Symptoms:** `npm error syscall unlink`, `EPERM`, path under `web/frontend/node_modules/...` (often `@rolldown/...` or similar). After that, **`npm run build`** may fail with **TS2688** (*Cannot find type definition file for 'vite/client' or 'node'*) because packages never finished installing.

**Cause:** Another process has the file open—common on Windows: **Vite dev server** (`npm run dev`), **antivirus** real-time scan, **IDE** indexing, or a **stuck Node** process.

**Fix:**

1. Stop **`npm run dev`**, close any **preview** processes, and exit other terminals using that folder.
2. Optional: add the repo (or `web/frontend/node_modules`) to AV **exclusions** for dev machines.
3. From **`web/frontend`**, remove the broken tree and reinstall (PowerShell):

   ```powershell
   cd web\frontend
   Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
   npm cache verify
   npm install
   npm run build
   ```

4. If **`Remove-Item`** still fails, close **Cursor/VS Code** for that workspace (or reboot), then delete **`node_modules`** in **File Explorer** and run **`npm install`** again.

**Docker `Dockerfile.web`:** run **`docker build`** from the **repository root** (where **`docker/`** and **`requirements-web.txt`** live), not from `web/frontend`:

```powershell
cd C:\path\to\RoadmapAgent
docker build -f docker/Dockerfile.web -t rma-web:1.1.1-b .
```

A line like `...1.1.1-b .cd web/frontend` is two commands accidentally joined; there must be a **space** after the **`.`** build context, and the **`cd`** is a separate step **before** `docker build` if you need it.

**`COPY requirements-web.txt` / not found:** the build context directory (the **`.`** at the end of `docker build`) must be the **repository root**, where **`requirements-web.txt`** lives. If you run from **`web/frontend`**, that file is outside the context—`cd` to the repo root first.

**`error from sender: open .rma\venv\lib64: The file cannot be accessed by the system`:** Docker Desktop is uploading the whole repo; **`.rma/venv`** often contains **symlinks** (e.g. `lib64`) that Windows cannot read for the context tarball. The repo’s **`.dockerignore`** excludes **`.rma/`** so local venvs are not sent. Re-run **`docker build -f docker/Dockerfile.web -t … .`** from the root after pulling the latest tree (or ensure **`.dockerignore`** is present).

## 12) What to collect before filing an issue

- command used
- exact output/error
- OS and shell
- whether `.rma/` exists
- `git status` state
- whether `fzf` and `mempalace` are installed
