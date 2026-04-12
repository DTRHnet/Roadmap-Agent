# Product roadmap quality rubric (for LLM-assisted `plan` / `analyze`)

Use this as **guidance** when generating or refining roadmap artifacts. Output must stay **grounded in the project context** provided; do not invent URLs, keys, or commitments.

## 1. Strategic alignment & purpose

- Tie major items to **product vision**, user problems, or measurable outcomes (not feature laundry lists).
- Prefer **outcomes** over raw output (“reduce p95 latency” vs “add a cache”).
- Note where **stakeholder alignment** or validation is still needed.

## 2. Clarity & structure

- Stay **high-level**: themes, epics, or major features — details belong in issues/PRs.
- State **prioritization rationale** (value vs effort, risk, dependencies) in plain language.
- Define **scope**: what is **in**, **out**, or **not now**.
- List **dependencies & assumptions** (integrations, infra, compliance).

## 3. Timeline & phasing

- Prefer **Now / Next / Later** or **Committed / Planned / Exploration** over fixed calendar dates unless the context supplies them.
- Call out **milestones** (MVP, beta, v1) with **success criteria** where possible.
- Acknowledge **capacity** (tech debt, ops, security) alongside feature work.

## 4. Flexibility

- Treat the roadmap as a **living document**: suggest **review cadence** (e.g. quarterly).
- Allow **uncertainty**: buffers, experiments, or “validate before committing.”

## 5. Measurability & accountability

- For major themes, suggest **KPIs or success metrics** (even directional).
- Include **risks** and **mitigations** with owners when the context allows.
- Use **status language** where helpful (on track / at risk) only when justified by context.

## 6. Communication

- Keep language **audience-appropriate** (engineering depth is OK in internal plans).
- If useful, distinguish **internal** vs **external** messaging in notes — without inventing public promises.

## 7. Technical & operational realism

- Reserve space for **tech debt**, **NFRs** (security, perf, a11y, observability), **CI/CD**, and **quality**.
- Call out **platform or architecture** moves when the codebase/context supports them.

## 8. Anti-patterns to avoid

- Micromanaged task lists disguised as a roadmap.
- Date-driven plans with no outcome link.
- “Everything is P0” with no tradeoff story.
- Static plans that ignore feedback or changing constraints.
- Roadmaps built **without** tying back to `.rma` context and repo reality.

---

When producing **plan.md**, weave these expectations into clear Markdown sections. When assisting **analyze**, synthesize **actionable** `- [ ]` items and structured notes that a human can verify against the repo.
