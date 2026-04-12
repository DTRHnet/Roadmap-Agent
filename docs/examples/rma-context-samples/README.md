# Sample `.rma` context files (by project type)

These folders are **not** live `.rma/` trees. They are **reference copies** of the four canonical context files ROADMAP-AGENT expects after `rma init`:

| File | Role |
|------|------|
| `description.md` | Product intent, users, goals, non-goals |
| `ui.md` | Screens, flows, accessibility, tone (for *your* app—not the ROADMAP-AGENT CLI unless this repo is the subject). For a **CLI product**, describe **command UX** here instead. |
| `stack.md` | Languages, frameworks, infra, how you build and test |
| `other.md` | Constraints, compliance, integrations, conventions |

**How to use:** run `rma init` in your project root, then **replace** the generated `.rma/description.md`, `.rma/ui.md`, `.rma/stack.md`, and `.rma/other.md` with content adapted from one of the samples below (merge sections, don’t blindly overwrite if you already have good notes). Each sample folder is a **detailed exemplar**—**trim** sections you do not need for MVP; keep **Goals**, **Non-goals**, and **`Open:`** lines tight so `plan` stays focused.

| Sample folder | Product sketch |
|---------------|----------------|
| [`weather-app/`](weather-app/) | Mobile-first weather: locations, hourly/daily, alerts, widgets |
| [`list-sharing/`](list-sharing/) | Collaborative lists: sharing, public lists, categories, roles |
| [`devtools-cli/`](devtools-cli/) | Developer CLI: subcommands, JSON output, config files, CI hooks |

Each sample folder includes a **`README.md`** with a **from-scratch bootstrap** for that stack (Flutter, Node/Postgres, or Rust) and a short section on **ROADMAP-AGENT’s Python `.rma` venv** when you use `plan` / MemPalace alongside the app.

See also: **[`END-TO-END-LIST-SHARING-APP.md`](../END-TO-END-LIST-SHARING-APP.md)** for a full workflow narrative.

---

## MCP — Model Context Protocol (often confused with “MCR”)

ROADMAP-AGENT **ships an optional MCP server** so IDE agents can read roadmap context and run `rma` tools. See **[`docs/MCP-SERVER.md`](../../MCP-SERVER.md)** and **[`rma_mcp/client-config.example.json`](../../../rma_mcp/client-config.example.json)** for setup (**streamable-http** from the CLI hub, or **stdio** for Cursor/Claude).

Your **Markdown contract** still lives on disk under **`.rma/`**. MCP is **transport** for tools and resources; it does not replace the four context files.

**Practical ways to bring context into the loop:**

1. **Filesystem / repo context** — Assistants can read `.rma/description.md`, `.rma/ui.md`, `.rma/stack.md`, `.rma/other.md`, and `.rma/roadmaps/*.md` directly from the workspace.
2. **ROADMAP-AGENT MCP** — Exposes `roadmap://context` and tools such as `rma_plan` / `rma_analyze` against **`ROADMAP_AGENT_PROJECT_ROOT`**.
3. **MemPalace vs MCP** — **MemPalace** indexes **chunked embeddings** over mined files. **MCP** is a **wire protocol** for tools in the IDE. They solve different layers: use both if you want **vector search** and **structured tool calls** in the same workflow.

If by **“MCR”** you meant a **project-specific acronym** (for example *Markdown Context Repository*), treat these sample folders as **templates** for that idea: one consistent Markdown bundle per product, checked into `docs/` or copied into `.rma/`.

---

## Formatting tips (quick)

- Start each file with a single `# Title` line; use `##` sections consistently.
- In **`description.md`**, separate **Goals** from **Non-goals** so `plan` does not over-scope.
- In **`ui.md`**, describe **screens and flows** (or **CLI** behavior), not library versions (those go in **`stack.md`**).
- In **`other.md`**, put **secrets policy**, **third-party APIs**, and **“never do X”** rules.

Full editorial guidance: [`docs/MANUAL.md`](../../MANUAL.md) → *Writing and maintaining context files*.

---

## Boilerplate anatomy (what “good” looks like)

These samples are intentionally **long**. Use them to see how depth improves **`plan`**, **`analyze`**, and **`analyze-init`**—then **delete** what does not apply. Aim for this shape:

| File | Put here | Why it helps `plan` |
|------|----------|---------------------|
| **`description.md`** | Summary, **problem**, personas with **short scenarios**, **Goals** / **Non-goals**, **MVP vs later**, **success criteria**, **glossary**, **`Open:`** | Boundaries and **undecided** items become tasks instead of guesses. |
| **`ui.md`** | Information architecture, **screen-by-screen** (or **command-by-command** for CLIs), permissions, a11y, empty/error/loading, **copy tone** | UX constraints land in **actionable** implementation tasks. |
| **`stack.md`** | Versions, **layer table**, repo layout, **dev/CI commands**, observability, **env var names** (never values), deployment sketch | **`analyze`** matches the real tree when this stays current. |
| **`other.md`** | Security, privacy, API/error conventions, branching, third parties + limits, ID/timezone conventions | Stops agents from proposing **unsafe** or **non-compliant** shortcuts. |

**`Open:`** lines are deliberate: ROADMAP-AGENT and [`MANUAL.md`](../../MANUAL.md) treat unresolved decisions as **signals**—either you decide and edit the file, or **`plan`** should surface tasks to **resolve** them. Remove **`Open:`** once closed so the next cycle does not re-litigate.

**Trimming:** For a weekend prototype, keep **Summary**, **Goals**, **Non-goals**, and one **`stack.md`** command block; add personas and **`Open:`** when you invite collaborators or run `plan` regularly.
