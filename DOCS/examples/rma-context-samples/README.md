# Sample `.rma` context files (by project type)

These folders are **not** live `.rma/` trees. They are **reference copies** of the four canonical context files ROADMAP-AGENT expects after `rma init`:

| File | Role |
|------|------|
| `description.md` | Product intent, users, goals, non-goals |
| `ui.md` | Screens, flows, accessibility, tone (for *your* app—not the ROADMAP-AGENT CLI unless this repo is the subject) |
| `stack.md` | Languages, frameworks, infra, how you build and test |
| `other.md` | Constraints, compliance, integrations, conventions |

**How to use:** run `rma init` in your project root, then **replace** the generated `.rma/description.md`, `.rma/ui.md`, `.rma/stack.md`, and `.rma/other.md` with content adapted from one of the samples below (merge sections, don’t blindly overwrite if you already have good notes).

| Sample folder | Product sketch |
|---------------|----------------|
| [`weather-app/`](weather-app/) | Mobile-first weather: locations, hourly/daily, alerts, widgets |
| [`list-sharing/`](list-sharing/) | Collaborative lists: sharing, public lists, categories, roles |
| [`devtools-cli/`](devtools-cli/) | Developer CLI: subcommands, JSON output, config files, CI hooks |

See also: **[`END-TO-END-LIST-SHARING-APP.md`](../END-TO-END-LIST-SHARING-APP.md)** for a full workflow narrative.

---

## MCP — Model Context Protocol (often confused with “MCR”)

ROADMAP-AGENT itself does **not** ship an MCP server. Your **Markdown context** lives on disk under **`.rma/`**, which is ideal for **MCP**-capable clients (for example **Cursor**) that can read project files as **resources** or feed them into **tools**.

**Practical ways to bring MCP into the loop:**

1. **Filesystem / repo context** — Configure your MCP client so assistants can read `.rma/description.md`, `.rma/ui.md`, `.rma/stack.md`, `.rma/other.md`, and `.rma/roadmaps/*.md`. No extra server is required if the client already indexes the workspace.
2. **Custom MCP resource server** — If you use a small MCP server that exposes “project memory,” point it at the same paths (or symlink `docs/examples/rma-context-samples/<sample>/` into `.rma/` while prototyping).
3. **MemPalace vs MCP** — **MemPalace** handles **chunked embeddings** and search over mined files. **MCP** is a **wire protocol** for tools and resources in the IDE. They solve different layers: use both if you want **vector search** (MemPalace) **and** **structured tool calls** (MCP) in the same workflow.

If by **“MCR”** you meant a **project-specific acronym** (for example *Markdown Context Repository*), treat these sample folders as **templates** for that idea: one consistent Markdown bundle per product, checked into `docs/` or copied into `.rma/`.

---

## Formatting tips (quick)

- Start each file with a single `# Title` line; use `##` sections consistently.
- In **`description.md`**, separate **Goals** from **Non-goals** so `plan` does not over-scope.
- In **`ui.md`**, describe **screens and flows**, not library versions (those go in **`stack.md`**).
- In **`other.md`**, put **secrets policy**, **third-party APIs**, and **“never do X”** rules.

Full editorial guidance: [`docs/MANUAL.md`](../../MANUAL.md) → *Writing and maintaining context files*.
