# ListHub

## Summary

ListHub helps people **create structured lists** (shopping, travel, project checklists), **organize items into categories**, and **share** them with others. Lists can be **private**, **link-shared**, or **public** in a discoverable catalog. A clear **role model** (owner, editor, viewer) lets multiple editors **co-manage** the same list without a single-assignee bottleneck. The product optimizes for **families and small teams** who need predictable permissions, expiring invitations, and an **audit trail** when visibility or membership changes.

## Problem statement

Shared notes apps blur permissions; collaborators cannot tell **who can edit**, **what “public” means**, or **what changed** after the fact. ListHub treats **lists** as the core primitive (not long-form documents) and enforces **server-side authorization** for every list-scoped action so clients cannot “guess” IDs to access other people’s data.

## Competitive framing (informative, not exhaustive)

- **Generic notes**: weak role models; ListHub is **list-first** with explicit **visibility** and **member roles**.
- **Spreadsheets**: poor mobile UX for quick capture; ListHub targets **fast add**, **categories**, and **share links**.
- **Open:** whether to name specific competitors in public docs (keep internal if preferred).

## Users and personas

| Persona | Who they are | What they need |
|---------|--------------|----------------|
| **Household Harper** | Groceries, chores, trip packing | **Fast add**, **categories**, **shared edit** with partner |
| **Creator Casey** | Publishes reading lists, templates | **Public** visibility, **read-only** viewers, **duplicate as template** |
| **Team lead Taylor** | Small team ops checklists | **Roles**, **invite by email**, **audit** of membership and visibility |
| **Agency Avery** *(stretch)* | Manages client-facing lists | **Export**, **read-only share**, **time-boxed** link access — **Open:** scope for v1 |

### Scenario: Harper (household)

Harper creates “Costco run,” adds categories **Produce** / **Pantry**, shares with partner as **editor**. Partner reorders items; Harper sees updates on refresh. Harper expects **no silent overwrites** if both edit at once—either **refresh** or **clear conflict** guidance.

### Scenario: Casey (public list)

Casey marks a list **public**; it appears in a **browse** surface with **title and description only** (no member PII). Anonymous visitors **read**; **use as template** copies structure into their account after auth—**Open:** guest-only template vs sign-in required.

### Scenario: Taylor (team ops)

Taylor invites three teammates as **editors**, retains **owner** for visibility changes. Taylor reviews **audit** entries when someone changes a member’s role or switches **LINK → PUBLIC**.

### Edge cases to design for (product-level)

- **Last owner** tries to leave or demote self: blocked until **transfer ownership** completes.
- **Revoked invite** or **expired token**: clear error, no partial membership.
- **Public list** taken private: disappears from catalog; **Open:** cache/TTL for search engines.

## Goals

- **Enforce** roles in **API and UI** (no client-trust for `listId` alone).
- **Invitations** by email or magic link with **accept/decline** and **audit trail** on membership and visibility changes.
- **Categories** as first-class: filter, collapse, **reorder within category**, **move items across categories** for editors.
- **Conflict handling**: no silent overwrite when two editors clash—**optimistic concurrency** with recoverable UX (see **Open:** strategy).
- **Discoverability** for **public** lists without leaking private metadata (no member emails in catalog API).

## Non-goals

- **Real-time multiplayer cursors** or simultaneous typing in one field (eventual consistency + refresh is acceptable for MVP).
- **Full document collaboration** (inline comments only if explicitly scoped later).
- **Arbitrary custom fields per item** in v1—**title**, **notes**, **due date**, **optional assignee** only.
- **Billing / paid tiers** in MVP unless reopened.

## MVP vs later

| Phase | Scope |
|-------|--------|
| **MVP** | Auth, list CRUD, items, categories, roles, link sharing, email invites, basic audit log, optimistic conflict handling (409 + UX) |
| **v1.1** | **Public** catalog, moderation hooks, improved conflict diff, rate limits on public endpoints |
| **Later** | Comments, webhooks, public API keys, native mobile apps, push notifications |

## Success criteria (measurable)

| Metric | Target | How we check |
|--------|--------|----------------|
| Authz coverage | **100%** of list-scoped API routes validate **membership + role** | Contract / integration tests per route class |
| Invite UX | **≤ 3 clicks** from invite email to first edit (new user) | Scripted user test + analytics funnel |
| Cross-list leakage | **0** unauthorized reads in security suite | Automated IDOR tests |
| Owner safety | Owner cannot remove self without **transfer** | API + UI tests |
| Public XSS | Public pages **sanitize** user content | XSS fixture suite |
| Conflict clarity | **0** silent overwrites in concurrency tests | Simulated concurrent PATCH |

## Glossary

| Term | Meaning |
|------|---------|
| **Visibility** | `PRIVATE` — members only; `LINK` — unlisted URL; `PUBLIC` — catalog + URL |
| **Mutual management** | Two or more **editors** with equal write unless owner restricts |
| **Invitation** | Pending record: token, email (or target), expiry, inviter, intended role |
| **Audit event** | Append-only record: actor, list, action type, payload summary, timestamp |
| **Catalog** | Browse surface for **PUBLIC** lists (metadata only) |

## Open:

- **Open:** Auth vendor **Auth.js vs Clerk vs Better Auth** — pick before scaling SSO; affects session shape and webhooks.
- **Open:** **Public catalog** — global vs instance-only; **moderation** workflow (report, hide, ban).
- **Open:** **Conflict strategy** — version column on `List` vs per-`Item` row version; **Open:** expose `ETag` vs JSON body version.
- **Open:** **Notification** channels (email only vs push later) and **must-buy** signals for Harper scenario.
- **Open:** **Template duplicate** — anonymous vs authenticated; **Open:** whether templates copy **categories only** or items too.
