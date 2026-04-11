# sysinfo — codespace & stack audit

Cross-platform, **read-only** audit: OS/hardware/container hints, common language runtimes, and repo markers (`package.json`, `go.mod`, `pyproject.toml`, lockfiles). **Stdlib-only** Python (3.8+); no `pip install` required for the audit script itself.

## Files

| File | Role |
|------|------|
| `sysinfo.py` | Main logic |
| `sysinfo.sh` | Bash launcher (Linux, macOS, Git Bash, Codespaces) |
| `sysinfo.ps1` | PowerShell 7+ launcher (Windows) |

## How to run

```bash
chmod +x sysinfo.sh
./sysinfo.sh

# Or:
python3 sysinfo.py
```

```powershell
.\sysinfo.ps1
# Or:
python sysinfo.py
```

You can run from **any subdirectory** of the project: the tool resolves a single **workspace root** and writes to **`<workspace_root>/.sysinfo/`**.

### Workspace root (default)

Resolution order:

1. **`--workspace /path/to/root`** — explicit directory  
2. **`SYSINFO_WORKSPACE_ROOT`** — environment variable  
3. **`ROADMAP_AGENT_PROJECT_ROOT`** — same as Roadmap-Agent’s project root  
4. Walk **upward from the current working directory** for the first directory that has:
   - **`.sysinfo-root`** (empty marker file you can add anywhere you want the root to be), or  
   - **`.git`**, or  
   - **`.rma`**  
5. If nothing matches, **cwd** is the workspace root  

The JSON/Markdown report includes an **Audit paths** table (`workspace_root`, `output_dir`, `resolution`) so automation and MCP hosts can see how the root was chosen.

### Output directory (default)

Unless you override with **`--output-dir`**, files are written to:

**`<workspace_root>/.sysinfo/`**

- `os-info.json` — OS, hardware, container hints, **`python_environment`** (venv/conda detection + activation hints)  
- `stack.json` — tool versions + detected project files  
- `full-report.md` — Markdown report (same content as console, including section emoji)  
- `audit-timestamp.txt` — UTC ISO timestamp  

Override the output folder only (workspace metadata still uses auto-detect unless you also set `--workspace`):

```bash
python3 sysinfo.py --output-dir /path/to/custom-out
```

Print only (no files):

```bash
python3 sysinfo.py --no-write
```

Machine-readable JSON on stdout:

```bash
python3 sysinfo.py --json
```

### Windows console emoji

The script prints UTF-8 to **stdout** even on cp1252 consoles. For best rendering, use **Windows Terminal** or run with `PYTHONUTF8=1` / `python -X utf8`.

## Integrate as an MCP tool (Roadmap-Agent)

1. Set **`ROADMAP_AGENT_PROJECT_ROOT`** (or **`SYSINFO_WORKSPACE_ROOT`**) to the app repo, **or** rely on `.git` / `.rma` discovery when the host runs the tool with `cwd` inside that tree.  
2. Register a tool that runs `sysinfo.py` with no extra path arguments if env is already set, for example:

```json
{
  "command": "python",
  "args": ["/absolute/path/to/sysinfo/sysinfo.py"]
}
```

3. Read **`stack.json`** / **`os-info.json`** under **`<workspace>/.sysinfo`**, or use the `audit.workspace_root` / `audit.output_dir` fields in those files.

## Optional: refresh `.rma/stack.md`

`sysinfo` does **not** overwrite Roadmap-Agent files by default. To sync a human summary into `.rma/stack.md`:

1. Run the audit (outputs land in **`<workspace>/.sysinfo`** automatically).  
2. Merge or summarize into `.rma/stack.md` (CI, `rma` wrapper, or MCP `run_shell` with approval).

```bash
python sysinfo/sysinfo.py
# review before committing:
cat .sysinfo/full-report.md >> .rma/stack.md
```

Prefer a **short** stack blurb from `stack.json` for `stack.md` so the file stays readable.

## Safety

- Read-only: no network, no package installs, no file modifications outside the chosen output directory.  
- Subprocess calls use short timeouts; missing tools are reported as not detected, not as fatal errors.
