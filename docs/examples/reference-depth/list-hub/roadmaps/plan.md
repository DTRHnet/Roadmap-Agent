# ListHub — roadmap dry run (reference exemplar)

This file illustrates a **mature** `.rma/roadmaps/plan.md`: it follows the shape **`rma plan`** expects from the LLM (**#** title, **## Current focus**, **## Suggested sequence**, **## Risks**, **`- [ ]`** tasks) and adds optional sections for **phasing**, **dependencies**, and **traceability** to **Open:** items in context files. A real `rma plan` run may be shorter; teams can merge or expand manually after generation.

## Current focus

Ship a **secure MVP** for list CRUD, **role-based** sharing, **categories**, **email invitations**, and **optimistic concurrency** with clear **409** UX—without prematurely building the **public catalog** or **push notifications**. Ground implementation in **Prisma + Postgres**, **Next.js** App Router, and **server-side authorization** on every list-scoped route.

## Suggested sequence

1. **Foundation**: repo layout (`apps/web`, `packages/db`), `pnpm` workspaces, **ESLint** + **TypeScript** strict, CI skeleton (lint, typecheck, test).
2. **Database**: Prisma schema for `User`, `List`, `ListMember`, `Item`, `Category`, `Invitation`; **UUID** keys; **`version`** on `List` (and/or `Item`) for conflicts; initial migration + seed script for local dev.
3. **Auth**: integrate chosen provider (**Open:** Auth.js vs Clerk vs Better Auth); session attachment middleware; **user id** on all mutating routes.
4. **Authorization layer**: single internal API `assertListRole(userId, listId, minRole)` used by all handlers; unit tests for **owner / editor / viewer** matrix.
5. **List & item REST**: CRUD under `/v1/lists/:listId/...` with membership checks; **no** cross-list leakage (integration tests).
6. **Categories**: nested under list; reorder endpoints; move item between categories.
7. **Invitations**: create/revoke/resend; token hashing; accept/decline flow; audit events for membership changes.
8. **Sharing & visibility**: `PRIVATE` / `LINK` / `PUBLIC` enum; restrict **PUBLIC** write paths; stub **catalog** behind feature flag (off for MVP) — aligns with **Open:** catalog scope.
9. **Web UI**: dashboard, list detail (drag reorder), sharing panel, conflict banner on **409**; role badges.
10. **Hardening**: rate limits on invite + public read paths (**Open:** numeric values); XSS fixtures for public view; **run.md** + smoke checklist.

### Dependency notes (read before parallelizing)

- Steps **4** must exist before **5–7** (shared guard).
- Step **6** can start after **5** once list CRUD is stable.
- Step **8** depends on **7** for consistent audit semantics when visibility changes.

## Risks

- **Auth vendor lock-in** complicates migration—mitigate with thin adapter module and feature flags.
- **Conflict UX** may frustrate users if too noisy—mitigate with copy testing and optional **single-field** retry.
- **Public surface** increases abuse risk—ship **LINK**-only MVP if catalog slips—trace to **Open:** moderation.
- **Email deliverability** blocks invites—mitigate with bounce handling and staging tests.

## Phase alignment (optional)

| Phase | Scope from `description.md` |
|-------|-----------------------------|
| **MVP** | Through step **10** above; catalog stub off or read-only empty state |
| **v1.1** | Public catalog, moderation hooks, conflict diff depth |

## Trace to Open questions

| Open item | Planned handling in this sequence |
|-----------|-----------------------------------|
| Auth vendor | **Step 3** — spike before large UI build |
| Conflict strategy | **Step 2 + 9** — version column + UX |
| Public catalog | **Step 8** — feature flag; full catalog in v1.1 |
| Notifications | **Later** — out of MVP sequence |

## Acceptance hints (per milestone)

- **After step 4**: failing tests prove **viewer** cannot PATCH items.
- **After step 7**: E2E path: invite → accept → **editor** can add item.
- **After step 9**: forced concurrent edit produces **409** and recoverable UI (no silent overwrite).

## Next actions

- [ ] Create monorepo skeleton with `apps/web` and `packages/db`; add CI workflow (lint, typecheck, test).
- [ ] Author Prisma schema with `List`, `ListMember`, `Item`, `Category`, `Invitation`; add `version` fields; run first migration.
- [ ] Implement auth middleware and session → `userId` for API routes.
- [ ] Implement `assertListRole` and apply to all list-scoped handlers; add matrix tests.
- [ ] Implement list CRUD and item CRUD with pagination cursor for items.
- [ ] Add category CRUD and item move between categories.
- [ ] Implement invitation create/revoke/resend/accept with hashed tokens and audit log entries.
- [ ] Add visibility enum and enforce **PUBLIC** read-only + feature flag for catalog UI.
- [ ] Build dashboard, list detail with DnD, sharing modal, conflict banner.
- [ ] Add Playwright smoke: invite flow + unauthorized access denial.
- [ ] Document local run, env var **names**, and migration commands in `run.md`.
