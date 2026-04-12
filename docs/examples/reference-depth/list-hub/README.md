# ListHub — reference-depth `.rma` bundle

This folder is a **deliberately dense** exemplar of what a mature ROADMAP-AGENT Markdown contract can look like for one product (**ListHub**). It mirrors how files would sit under a real project root (conceptually `.rma/` plus `roadmaps/`), but lives under `docs/examples/` so it is not executed by the tool.

## How this relates to other examples

| Tier | Location | Use it when |
|------|----------|-------------|
| **Trim-friendly templates** | [`rma-context-samples/list-sharing/`](../../rma-context-samples/list-sharing/) | You want copy-paste starters you can **shorten** for MVP. |
| **This bundle** | `reference-depth/list-hub/` | You want a **ceiling** for detail—what “very thorough” looks like across aligned files. |
| **Narrative walkthrough** | [`END-TO-END-LIST-SHARING-APP.md`](../../END-TO-END-LIST-SHARING-APP.md) | You want the **CLI workflow** story (init → plan → execute-one), not file-by-file max depth. |

## Files here

| File | Notes |
|------|--------|
| `description.md` | Product intent, personas, metrics, glossary, **Open:** lines tied to decisions. |
| `ui.md` | Screens, states, a11y, conflicts, copy—**not** library versions. |
| `stack.md` | Versions, layout, CI, env **names**, deployment sketch. |
| `other.md` | Security, privacy, API policy, branching, ops—**no secret values**. |
| `mcp-server.md` | **Optional** project-local doc: how **your team** uses ROADMAP-AGENT’s MCP alongside the repo. Not loaded by `get_roadmap_context` today; see [`REFERENCE-DEPTH-AUTHORING.md`](../../REFERENCE-DEPTH-AUTHORING.md). |
| `roadmaps/plan.md` | A **full** dry-run plan: matches the generator’s expected sections **plus** optional “mature plan” material (phases, dependencies, acceptance hints). Treat parts of it as **human-enriched** beyond the minimum `rma plan` output. |

## Trim vs aim here

- **Weekend prototype:** use [`rma-context-samples/`](../../rma-context-samples/) and keep Summary, Goals, Non-goals, and one `stack.md` command block.
- **Team roadmap + IDE agents:** aim toward the **density** here—especially explicit **Open:** lines, testable success criteria, and a `plan.md` that names risks and ordering.

See **[`REFERENCE-DEPTH-AUTHORING.md`](../../REFERENCE-DEPTH-AUTHORING.md)** for the authoring rubric.
