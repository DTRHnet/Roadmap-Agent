# End-to-end example: list-sharing app with ROADMAP-AGENT

This walkthrough is **illustrative**. Commands, transcripts, and file excerpts are **fictional** but aligned with how ROADMAP-AGENT is meant to be used: you bring the tool into a **new or existing repo**, initialize **`.rma/`**, run **`doctor`**, then loop **`plan` → `execute-one` → `analyze`**, using **MemPalace** (mine → retrieve context) so plans and agents are grounded in **your actual tree**. Adjust paths to your OS (PowerShell examples below; on Linux/macOS use `./roadmap-agent` or `rma` as installed).

**Product we are pretending to build:** a web app for **creating and sharing lists**, including **public lists**, **categories**, and **permissions** (owners, editors, viewers, **mutual** co-management of shared lists).

**What success looks like:** you **ship a working app** by iterating—each cycle refines **Markdown context**, refreshes **palace memory**, regenerates **detailed** roadmaps, and lands **real code** with **`execute-one`**-sized steps. Structured logs and `plan.md` are **steering and audit artifacts**, not the end goal.

---

## 1 — What you are aiming for

| Area | Expectation |
|------|-------------|
| **Roadmap state** | `.rma/roadmaps/plan.md`, `tasks.md`, and `run.md` stay aligned with real work: phases for auth, list CRUD, sharing, visibility, roles—**prefer depth** (dependencies, risks, acceptance hints) over one-line bullets. |
| **Context files** | `.rma/description.md`, `ui.md`, `stack.md`, `other.md` are the **contract** the agent and MemPalace-backed **`plan`** interpret; keep them explicit so roadmaps are detailed and **questions** surface where you left gaps. |
| **MemPalace** | After `setup-local-models-mempalace`, **`mempalace mine`** (often **`--dry-run`** from the menu) previews ingest; a **full** ingest updates the palace so **`plan`** and IDE agents retrieve **current** code and docs—not stale guesses. |
| **Loop** | **`execute-one`** drives **implementation**; **`analyze`** reconciles repo reality with `tasks.md` / `run.md`. Use an **AI agent** (in Cursor or the terminal) to **read** `.rma/*.md`, **expand** plans, and **prompt you** on auth, visibility, or compliance when the Markdown is silent—do not let the model invent critical product law. |

### How the agent should behave (intent)

- **Interpret** the four context files as source of truth; **use** MemPalace search over mined files to align tasks with filenames, routes, and schema.
- **Produce very detailed roadmaps** in `plan.md` / `tasks.md` when context is rich—break work into reviewable slices with clear ordering and risks.
- **Ask you** when something important is underspecified (e.g. “public list” vs “unlisted link,” or OAuth vs email-only)—record answers back into `.rma/other.md` or `description.md` so the next **`plan`** is sharper.

---

## 2 — Bring ROADMAP-AGENT into your project

You do **not** merge your product into the RoadmapAgent repo. Typical patterns:

### Option A — Clone ROADMAP-AGENT once, use `rma` from PATH

Install persistence (see [`QUICKSTART.md`](../QUICKSTART.md)), then work entirely inside **`C:\Users\dev\Projects\ListHub`** (your app repo). `rma` resolves the **project root** from your cwd.

### Option B — Vendor a copy inside the app repo (team convention)

```text
C:\Users\dev\Projects\ListHub\
  tools\
    Roadmap-Agent\          # clone or subtree of ROADMAP-AGENT
  src\
  ...
```

Run setup scripts from `tools\Roadmap-Agent\scripts\windows\...` or add `tools\Roadmap-Agent\bin` to PATH for that repo only.

### Option C — Git submodule

```powershell
cd C:\Users\dev\Projects\ListHub
git submodule add https://github.com/DTRHnet/Roadmap-Agent.git tools/Roadmap-Agent
```

**Expectation:** Your **app root** (`ListHub`) is where `.rma/`, `.env`, and `git` live. ROADMAP-AGENT only needs to find **bash** (Windows: WSL/Git Bash) and your **Python/MemPalace** venv when you use `plan` / mine.

---

## 3 — One-time: Python, MemPalace, `.env`

From **`ListHub`** (your app root):

```powershell
Copy-Item .\tools\Roadmap-Agent\.env.example .env   # or from cloned ROADMAP-AGENT root
.\tools\Roadmap-Agent\scripts\windows\setup-local-models-mempalace.ps1
```

**Mock output (abbreviated):**

```text
[INFO] Starting local model setup for MemPalace.
[INFO] Log: C:\Users\dev\Projects\ListHub\.rma\logs\setup-local-models.log
[INFO] Using Python: C:\Users\dev\Projects\ListHub\.rma\venv\Scripts\python.exe
[INFO] Installing/refreshing required packages: mempalace, chromadb
[INFO] Imports verified: mempalace, chromadb
[INFO] Ollama: host http://127.0.0.1:11434 reachable; model llama3.1:latest present.
[INFO] Setup finished with 0 errors, 0 warnings.
```

Edit **`.env`** for your machine, for example:

```env
RMA_LLM_PROVIDER=ollama
RMA_OLLAMA_HOST=http://127.0.0.1:11434
RMA_OLLAMA_MODEL=llama3.1:latest
# Optional: mine only ./docs and ./src
# RMA_MEMPALACE_MINE_DIR=.
```

**Expectation:** `rma doctor` shows Python venv, Ollama reachable, and **[MemPalace]** checks passing when strict mode is on.

---

## 4 — `init`: scaffold `.rma/`

```powershell
cd C:\Users\dev\Projects\ListHub
rma init
```

If prompted to overwrite, confirm only if you intend to reset templates.

**What appears (conceptually):**

- `.rma/description.md`, `ui.md`, `stack.md`, `other.md`
- `.rma/roadmaps/plan.md`, `tasks.md`, `run.md`
- `.rma/state/` as needed by your version

---

## 5 — Fill context so the roadmap matches “ListHub”

Edit the Markdown by hand (this is the **source of truth** for the tool’s view of your product). For **ready-made structure** you can adapt, see the sample bundles under **[`rma-context-samples/`](rma-context-samples/)** (for example **`list-sharing/`** aligns with this doc).

**`.rma/description.md` (excerpt):**

```markdown
# ListHub

ListHub lets users create lists, organize items into categories, and share lists
with others. Lists can be private, link-shared, or public. Permissions include
owner, editor, and viewer; multiple users can co-manage a list (mutual editors).

## MVP scope
- Auth (email or OAuth TBD)
- Lists + items + categories
- Share links + public catalog
- Role-based access and invitations
```

**`.rma/stack.md` (excerpt):**

```markdown
# Stack (proposed)

- Backend: Node + PostgreSQL (or SQLite for dev)
- API: REST or tRPC
- Frontend: React or Next.js
- Auth: session/JWT + refresh strategy TBD
```

**`.rma/ui.md` (excerpt):**

```markdown
# UI notes

- Dashboard: my lists + shared with me
- List detail: items, drag reorder, category tabs
- Sharing panel: visibility (private / link / public), invite by email, role picker
```

**Expectation:** The more concrete these files are, the better **`plan`** and **`analyze`** outputs will be. Vague one-liners produce vague tasks—and weak MemPalace-backed retrieval—so **invest** in these files the same way you would a PRD for a cofounder.

---

## 6 — `doctor`

```powershell
rma doctor
```

**Mock output:**

```text
Project: ListHub | branch: main | origin: git@github.com:acme/ListHub.git
--- doctor ---
bash: ok
git: ok
python (venv): C:\Users\dev\Projects\ListHub\.rma\venv\Scripts\python.exe
RMA_LLM_PROVIDER=ollama | RMA_OLLAMA_HOST=http://127.0.0.1:11434 | model=llama3.1:latest
Ollama HTTP: reachable
[MemPalace] imports: ok | command: mempalace (resolved)
Persistence: (optional) ...
doctor: complete (exit 0)
```

**Expectation:** Fix anything marked **WARN** before relying on **`plan`** or **mine**.

---

## 7 — First `plan` (MemPalace-backed)

```powershell
rma plan
```

**Mock `plan.md` snippet (illustrative):**

```markdown
## Current focus
Establish data model and API skeleton for lists, items, categories, and membership roles.

## Suggested sequence
1. Schema: users, lists, list_members (role), items, categories
2. Migration tooling and seed script for dev
3. Minimal REST: CRUD list + item under auth
4. Sharing: visibility enum + share token; public read-only endpoint
5. Invitations: email stub + accept flow
6. UI: dashboard + list detail + sharing panel

## Risks
- Permission edge cases (demote owner, last owner)
- Public list abuse — rate limits later
```

**Expectation:** Your real output depends on the LLM, MemPalace context, and `.rma` files. Aim for **much more detail** than the snippet when context is mature. If MemPalace is unavailable and you have not set **`RMA_ALLOW_PLAN_FALLBACK=1`**, **`plan`** fails fast — that is by design in v0.4.0+.

**Refinements:** Use your **IDE agent** to expand sections or list unresolved decisions as multiple-choice; capture answers in `.rma/*.md` and re-run **`plan`**.

**Built-in CLI prompts:** On an **interactive terminal**, **`rma plan`** asks you about bullets in **`.rma/open-questions.md`** and lines with **`Open:`** in the four context files; answers append to **`other.md`** before MemPalace runs. Use **`rma plan --no-interactive`** or **`RMA_PLAN_INTERACTIVE=0`** in CI.

---

## 8 — Align `tasks.md` / `run.md` (optional `analyze-init`)

If templates are empty or stale:

```powershell
rma analyze-init
```

Review diffs; then:

```powershell
rma analyze
```

**Mock `tasks.md` excerpt:**

```markdown
## Now
- [ ] Add Prisma schema for User, List, ListMember, Item, Category
- [ ] Auth middleware: attach user id to request

## Next
- [ ] List CRUD routes with ownership checks
- [ ] Sharing: visibility + public slug
```

---

## 9 — `execute-one`: one bite at a time

```powershell
rma execute-one
```

**Mock transcript:**

```text
execute-one: selecting next actionable task from tasks.md ...
Task: Add Prisma schema for User, List, ListMember, Item, Category

Suggested commands (you run in your repo):
  npx prisma init
  # edit prisma/schema.prisma ...

Log written to .rma/logs/...
```

**Expectation:** **`execute-one`** is the **execution spine**: it picks the next task, applies guardrails, and logs. **You** (or your IDE agent following `tasks.md` / `plan.md`) **write the code** that ships the feature—this is not a magic “generate full app” button. The **point** of the loop is to **build the product iteratively**: each pass should leave the repo **closer to a runnable app**, with MemPalace + `.rma` context **driving what to do next** intelligently. Use an agent to **implement** the selected task (tests, migrations, UI) while you review; merge **important product decisions** into `.rma` when the agent asks.

After coding, run **`analyze`** again so **`tasks.md`** reflects reality.

---

## 10 — MemPalace **mine** (preview vs full ingest)

### From the interactive AI submenu (safe / dry-run)

```powershell
rma
# Navigate to AI → safe mine (menu II / III depending on version)
```

Underlying idea (see also [`roadmap-mining-and-loop.svg`](../roadmap-mining-and-loop.svg)):

```bash
mempalace mine "C:\Users\dev\Projects\ListHub" --limit 200 --dry-run
```

**Mock output:**

```text
[dry-run] Would process 142 files under .
[dry-run] Skipping node_modules/ (ignored)
[dry-run] Sample: src/routes/lists.ts, prisma/schema.prisma, README.md
...
dry-run complete — no vectors written
```

**Expectation:** **`--dry-run`** does not update the palace; it shows what a full run would target. For a **full** ingest, run **`mempalace mine`** yourself **without** `--dry-run` when you are ready (longer, writes embeddings).

### Why mine for ListHub?

Mining ingests **your repo text** so MemPalace-backed **`plan`**, retrieval, and **agents** working beside ROADMAP-AGENT can use **current** file names, routes, and schema hints—not stale guesses. **Refresh** the palace after meaningful refactors so **detailed** roadmaps stay tied to the tree.

---

## 11 — The loop you repeat until MVP

```text
  .rma context (edit as product evolves; agent asks when unclear)
           │
           ▼
   mine (dry-run or full) ──► plan (very detailed roadmaps)
           │                      │
           └──────────────────────┘
                      │
                      ▼
        execute-one ──► ship code (you + agent) ──► analyze
           ▲                                        │
           └──────────── iterate ◄───────────────────┘
```

**Cadence (suggestion):**

- **Daily:** `execute-one` + **`analyze`** after real commits; keep **`.rma`** and **agent Q&A** in sync when decisions land.
- **Weekly or after big refactors:** **`plan`** again; **mine** (full ingest when needed) so MemPalace matches the repo.
- **Before a release:** `analyze`, tighten `run.md` checklist; re-read **`plan.md`** for gaps and **prompt** yourself or the agent for any unresolved **important** questions.

---

## 12 — Permissions and “mutual management” (what to document in `.rma`)

So **`plan`** / **`analyze`** do not hallucinate a simpler model, spell out in **`other.md`** or **`description.md`**:

- **Roles:** e.g. `OWNER`, `EDITOR`, `VIEWER`.
- **Mutual editors:** two or more `EDITOR`s without a single “assignee” bottleneck; conflicts resolved by last-write or explicit locking (your choice — document it).
- **Public lists:** read-only for anonymous users unless you add public comments later.

**Expectation:** Roadmap tasks should mention **authorization checks** in API and UI, not just CRUD.

---

## 13 — When something goes wrong

| Symptom | What to check |
|--------|----------------|
| `plan` fails | `rma doctor`, MemPalace venv, `RMA_ALLOW_PLAN_FALLBACK` (dev only), Ollama/model |
| `mine` errors on directory | MemPalace requires a **positional path**; set **`RMA_MEMPALACE_MINE_DIR`** or run from repo root |
| Stale tasks | Run **`analyze`**; edit **`tasks.md`** by hand if the model drifts |
| Too much scope in one task | Split in **`tasks.md`**; use smaller **`execute-one`** steps |

See [`TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) and [`ROADMAP-WORKFLOW.md`](../ROADMAP-WORKFLOW.md).

---

## 14 — Summary

1. **Import** ROADMAP-AGENT via PATH, vendor copy, or submodule—your **app repo** stays the cwd for **`rma`**.  
2. **Setup** MemPalace + `.env`; **`doctor`** until clean.  
3. **`init`**, then **author** `.rma/*.md` for ListHub (lists, sharing, categories, permissions)—this is what **`plan`** and agents **interpret** for **detailed** roadmaps.  
4. **`mine` → `plan` → `execute-one` → `analyze`** in a tight loop: palace + Markdown **drive** intelligent iteration; **`execute-one`** tracks **real implementation** work toward a **shippable app**.  
5. **Use an agent** to expand plans, implement tasks, and **ask you** important questions when context is thin; **capture answers** in `.rma` and re-run **`plan`**. The outcome is **working software** in your repo—not documentation for its own sake.

For a shorter generic transcript (install → hub), see [`MOCK-WORKFLOW-SESSION.md`](MOCK-WORKFLOW-SESSION.md). For the mining vs roadmap diagram, see [`../roadmap-mining-and-loop.svg`](../roadmap-mining-and-loop.svg).
