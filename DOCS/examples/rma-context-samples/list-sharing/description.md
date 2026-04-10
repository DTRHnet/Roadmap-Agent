# ListHub

## Summary

ListHub helps people **create lists** (shopping, travel, project checklists), **organize items into categories**, and **share** them with others. Lists can be **private**, **link-shared**, or **public** in a discoverable catalog. **Permissions** span owner, editor, and viewer; multiple editors can **co-manage** the same list without a single assignee bottleneck.

## Users

- Households and small teams sharing recurring lists.
- Creators who publish **public** templates or reading lists.
- Workspace admins who need **audit-friendly** visibility (who changed what).

## Goals

- Clear **role model** and enforcement in API and UI.
- **Invitations** by email or magic link; accept/decline with audit trail.
- **Categories** as first-class: filter, collapse, reorder within category.

## Non-goals

- Full document collaboration (comments only if explicitly scoped later).
- Real-time multiplayer cursors (eventual consistency + refresh is enough for MVP).
- Arbitrary custom fields per item in v1 (stick to title, notes, due, assignee optional).

## Glossary

| Term | Meaning |
|------|---------|
| **Mutual management** | Two or more **editors** with equal write access unless owner restricts. |
| **Visibility** | `PRIVATE` \| `LINK` \| `PUBLIC` — controls discovery and anonymous read. |
