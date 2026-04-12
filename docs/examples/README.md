# Examples (`docs/examples/`)

This folder holds **reference material** for learning ROADMAP-AGENT: sample **`.rma/`** Markdown bundles, **long-form walkthroughs**, and a **fictional terminal session**. Nothing here is executed by the test suite; copy ideas into your own project’s **`.rma/`** tree.

## What lives here

| Area | Path | Purpose |
|------|------|---------|
| **Sample context files** | [`rma-context-samples/`](rma-context-samples/README.md) | Template **`description.md`**, **`ui.md`**, **`stack.md`**, **`other.md`** for three product shapes (weather app, list sharing, devtools CLI), plus per-sample **`README.md`** bootstrap notes. |
| **Walkthroughs** | This directory (root of `examples/`) | Narrative docs with mock transcripts—read when you want an end-to-end story, not a file-by-file template. |
| **Mock session** | [`MOCK-WORKFLOW-SESSION.md`](MOCK-WORKFLOW-SESSION.md) | Illustrative install → **`init`** → hub → **`plan`** / **`analyze`** / **`execute-one`** log; sample lines for **`.rma/logs/`**. |

### Walkthroughs (one line each)

- **[`END-TO-END-LIST-SHARING-APP.md`](END-TO-END-LIST-SHARING-APP.md)** — Collaborative lists, sharing, permissions: MemPalace, **`execute-one`**, and how **terminal agent** vs **IDE** workflows fit the loop.
- **[`END-TO-END-AUTOPART-LEADS-APP.md`](END-TO-END-AUTOPART-LEADS-APP.md)** — Inventory-backed leads (multi-part): discovery vs outreach, compliance framing; same CLI and **`.rma/`** contract ideas as above.

## Terminal agent vs MCP / IDE

- **Modular terminal agent (`rma_agent`)** — Invoked via **`roadmap-agent agent`** or **`python -m rma_agent`** (install **`requirements-agent.txt`**). This is the **default** automation path in CORE; it reads your **`.rma/`** contract and uses the same **`RMA_*`** LLM settings as **`plan`** / **`analyze`**. See **[`docs/agent/usage.md`](../agent/usage.md)** (and **[`architecture.md`](../agent/architecture.md)** / **[`development.md`](../agent/development.md)** for internals).
- **MCP + IDE hosts** — **`rma_mcp`** exposes tools and **`roadmap://context`** so Cursor, Claude Desktop, etc. can call into **`roadmap-agent`** without replacing the terminal workflow. See **[`docs/MCP-SERVER.md`](../MCP-SERVER.md)**.
- **Legacy bash-only loop** — **`RMA_AGENT_LEGACY=1`** restores the older inline bash **agent** implementation; prefer **`rma_agent`** unless you are debugging that path.

## See also

- **[`docs/QUICKSTART.md`](../QUICKSTART.md)** — Fast setup by OS.
- **[`docs/MANUAL.md`](../MANUAL.md)** — Commands and **`.rma`** file authoring.
