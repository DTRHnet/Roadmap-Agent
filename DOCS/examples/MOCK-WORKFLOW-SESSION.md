# Mock workflow session (illustrative)

These transcripts are **fictional** examples of what you might see end-to-end: install ROADMAP-AGENT globally on Windows, prepare a project, run **`init`**, run **`doctor`**, use the **interactive hub**, then **roadmap** commands. As of v1.0.0, **`plan`** and **mine** require a real MemPalace stack — align the **[MemPalace]** lines with your environment. Timestamps and paths are representative, not captured from a single real run.

---

## 1 — Clone the tool and install persistence (Windows, user scope)

```text
PS C:\Users\dev\src> git clone https://github.com/DTRHnet/Roadmap-Agent.git
Cloning into 'Roadmap-Agent'...
remote: Enumerating objects: 842, done.

PS C:\Users\dev\src> cd Roadmap-Agent

PS C:\Users\dev\src\Roadmap-Agent> .\launchers\setup-rma.ps1 -Scope User
ROADMAP-AGENT Setup
Repo root: C:\Users\dev\src\Roadmap-Agent
Scope: User

----------------------------------------------------------------------------
   ROBOCOPY     ::     Robust File Copy for Windows
----------------------------------------------------------------------------
  Source : C:\Users\dev\src\Roadmap-Agent\
  Dest   : C:\Users\dev\AppData\Local\Roadmap-Agent\
----------------------------------------------------------------------------

User PATH already contains: C:\Users\dev\AppData\Local\Roadmap-Agent\bin
Persistence install complete.
Current session PATH updated — try: rma --help

Setup completed.
Try in this shell: rma --help

PS C:\Users\dev\src\Roadmap-Agent> rma --help
ROADMAP-AGENT — commands: init, status, doctor, plan, analyze, analyze-init, execute-one, unlock,
  persistence, persistence-check, help, man
  (no command) — interactive menu
```

---

## 2 — Optional: Python / MemPalace stack in a project (abbreviated)

```text
PS C:\Users\dev\Projects\InvoiceApp> .\scripts\windows\setup-local-models-mempalace.ps1
[INFO] Starting local model setup for MemPalace.
[INFO] Log: C:\Users\dev\Projects\InvoiceApp\.rma\logs\setup-local-models.log
[INFO] Using Python: C:\Users\dev\Projects\InvoiceApp\.rma\venv\Scripts\python.exe
[INFO] Installing/refreshing required packages: mempalace, chromadb
[INFO] Verifying Python imports for mempalace/chromadb...
[INFO] Imports verified: mempalace, chromadb
[INFO] Ollama: host http://127.0.0.1:11434 reachable; model llama3.1:latest present.
[INFO] Setup finished with 0 errors, 0 warnings.
```

---

## 3 — New project: `.env` and `init`

```text
PS C:\Users\dev\Projects\InvoiceApp> copy ..\.env.example .env

PS C:\Users\dev\Projects\InvoiceApp> rma init
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
▓   RMA  AGENT      ▓
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
Roadmap Agent
A DTRHnet Project https://dtrh.net
App Version : v1.0.0
Last Release: v1.0.0
Release Date: 2026-04-10

WARN: .rma/ already exists. Overwrite scaffolding? [y/N]: n
Skipped destructive re-init. Existing .rma/ left unchanged.

PS C:\Users\dev\Projects\InvoiceApp> rma init
...
WARN: .rma/ already exists. Overwrite scaffolding? [y/N]: y
Created .rma/description.md, ui.md, stack.md, other.md (templates)
Created .rma/roadmaps/plan.md, tasks.md, run.md
Init complete.
```


---D[p[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]what is this ]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]

## 4 — `doctor` (environment + persistence sanity)

```text
PS C:\Users\dev\Projects\InvoiceApp> rma doctor
Project: InvoiceApp | branch: feature/rma | origin: git@github.com:acme/InvoiceApp.git
--- doctor ---
bash: /usr/bin/bash (via WSL)
git: ok
python (venv): C:\Users\dev\Projects\InvoiceApp\.rma\venv\Scripts\python.exe
RMA_LLM_PROVIDER=ollama | RMA_OLLAMA_HOST=http://127.0.0.1:11434 | model=llama3.1:latest
Ollama HTTP: reachable
Persistence: installed scripts in sync with repo (User scope)
WARN panel: no blocking issues
doctor: complete (exit 0)
```

---

## 5 — Interactive hub (no `fzf`: fallback text menu, simulated)

```text
PS C:\Users\dev\Projects\InvoiceApp> $env:RMA_DISABLE_FZF="1"; rma

ROADMAP-AGENT HUB
App Version: v1.0.0
Last Release: v1.0.0
Release Date: 2026-04-10
Press Enter to continue:

--- Runtime warnings (summary) ---
[ ] All required .rma/*.md present
[ ] .env loaded
[i] Git remote: git@github.com:acme/InvoiceApp.git

I    Open AI / MemPalace submenu
II   Quick status (project + tasks)
III  Persistence check / install hints
IV   Exit

Select [I-IV]: II

--- Quick status ---
Project: InvoiceApp | main | tasks pending: 3 | last run: none
Press Enter to continue:

Select [I-IV]: I

--- AI submenu (excerpt) ---
I    Setup local models (MemPalace script)
II   Safe mine (mempalace / simulated)
III  Health check (mempalace/chromadb)
...

Select: III

MemPalace version: 0.4.2
ChromaDB version: 0.5.15
```

---

## 6 — Roadmap commands: `status`, `plan`, `analyze`

```text
PS C:\Users\dev\Projects\InvoiceApp> rma status
Project: InvoiceApp | branch: feature/rma
Tasks: 3 pending | 0 completed (from .rma/roadmaps/tasks.md)
Last execution log: .rma/logs/roadmap-agent-execution.log (empty)

PS C:\Users\dev\Projects\InvoiceApp> rma plan
Wrote dry-run plan to .rma/roadmaps/plan.md

PS C:\Users\dev\Projects\InvoiceApp> rma analyze
Scanning markdown and key config files...
Synced .rma/roadmaps/tasks.md and run.md from repository signals.
analyze: complete
```

---

## 7 — `execute-one` (confirmation gate, mock)

```text
PS C:\Users\dev\Projects\InvoiceApp> rma execute-one
Pending tasks:
  1) Add PDF export regression test
  2) Document API rate limits in README
  3) Harden webhook signature verification

Select task index [1-3]: 2

About to run guided step for: "Document API rate limits in README"
Proceed? [y/N]: y

[simulated] Would run project-defined execution for task #2
Log append: .rma/logs/roadmap-agent-execution.log
execute-one: completed step (dry guidance — adjust script for real commands)
```

---

## 8 — Mock append to `.rma/logs/roadmap-agent-execution.log`

```text
2026-04-10T14:22:01Z  execute-one  task_id=2  summary="Document API rate limits in README"  result=acknowledged
2026-04-10T14:22:02Z  unlock       state=idle
```

---

## 9 — Mock append to `.rma/logs/agent.log` (agency / agent-style notes)

```text
2026-04-10T14:21:55Z  session_start  cwd=C:\Users\dev\Projects\InvoiceApp  user=dev
2026-04-10T14:21:56Z  hub_menu       selection=quick_status
2026-04-10T14:22:00Z  ai_submenu     action=health_check  mempalace=0.4.2  chromadb=0.5.15
2026-04-10T14:22:01Z  roadmap        command=execute-one  task=2  outcome=confirmed
```

---

## How to use this doc

- Treat these blocks as **documentation samples**, not fixtures for automated tests.
- Real output varies by OS, `fzf` vs fallback, MemPalace presence, and LLM configuration.
- For live behavior, run **`rma doctor`** and **`rma`** in your own project root after **`rma init`**.

See also: [QUICKSTART.md](../QUICKSTART.md), [MANUAL.md](../MANUAL.md).
