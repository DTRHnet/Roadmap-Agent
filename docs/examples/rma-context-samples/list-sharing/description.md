# ListHub

## Summary

ListHub helps people **create structured lists** (shopping, travel, project checklists), **organize items into categories**, and **share** them with others. Lists can be **private**, **link-shared**, or **public** in a discoverable catalog. A clear **role model** (owner, editor, viewer) lets multiple editors **co-manage** the same list without a single-assignee bottleneck.

## Problem statement

Shared notes apps blur permissions; families and small teams need **predictable** who-can-edit rules, **invitations** that expire, and **audit** when something sensitive changes. ListHub focuses on **lists as the core primitive**, not free-form documents.

## Users and personas

| Persona | Who they are | What they need |
|---------|--------------|----------------|
| **Household Harper** | Groceries, chores, trip packing | **Fast add**, **categories**, **shared edit** with partner |
| **Creator Casey** | Publishes reading lists, templates | **Public** visibility, **read-only** viewers, optional **duplicate as template** |
| **Team lead Taylor** | Small team ops checklists | **Roles**, **invite by email**, **audit** of membership and visibility changes |

### Scenario: Harper (household)

Harper creates “Costco run,” adds categories **Produce** / **Pantry**, shares with partner as **editor**. Partner reorders items; Harper sees updates on refresh. Notifications when partner adds **must-buy** items — **Open:** notification scope.

### Scenario: Casey (public list)

Casey marks a list **public**; it appears in a **browse** surface with title and description only (no PII). Anonymous visitors **read**; **use as template** copies structure into their account — **Open:** anonymous vs logged-in only.

## Goals

- **Enforce** roles in **API and UI** (no client-trust for `listId` alone).
- **Invitations** by email or magic link with **accept/decline** and **audit trail**.
- **Categories** as first-class: filter, collapse, **reorder within category**.
- **Conflict handling**: no silent overwrite when two editors clash — surface **refresh** or **merge** policy.
- **Discoverability** for **public** lists without leaking private metadata.

## Non-goals

- **Real-time multiplayer cursors** or simultaneous typing in one field (eventual consistency + refresh is enough for MVP).
- **Full document collaboration** (inline comments only if explicitly scoped later).
- **Arbitrary custom fields per item** in v1 — stick to **title**, **notes**, **due date**, **optional assignee**.
- **Billing / paid tiers** in MVP unless reopened.

## MVP vs later

| Phase | Scope |
|-------|--------|
| **MVP** | Auth, list CRUD, items, categories, roles, link sharing, email invites, basic audit log |
| **v1.1** | **Public** catalog, moderation hooks, improved conflict UX |
| **Later** | Comments, webhooks, public API keys, mobile apps |

## Success criteria

- **100%** of list-scoped API routes validate **membership + role** server-side (automated contract tests).
- Invite flow: **under 3 clicks** from invite email to first edit for new user (benchmark).
- **Zero** unauthorized cross-list reads in security test suite.
- **Owner** cannot remove self without **transfer ownership** (enforced in API).
- Public list pages **sanitize** user content (XSS suite passes).

## Glossary

| Term | Meaning |
|------|---------|
| **Visibility** | `PRIVATE` — only members; `LINK` — anyone with URL; `PUBLIC` — catalog + URL |
| **Mutual management** | Two or more **editors** with equal write unless owner restricts |
| **Invitation** | Pending `ListMember` row with token, expiry, inviter id |

## Open:

- **Open:** Auth vendor **Auth.js vs Clerk vs Better Auth** — pick before scaling SSO.
- **Open:** **Public catalog** — global vs instance-only; moderation workflow.
- **Open:** **Conflict strategy** — last-write-wins with version column vs operational transform (likely **optimistic +409** for MVP).
- **Open:** **Notification** channels (email only vs push later).
