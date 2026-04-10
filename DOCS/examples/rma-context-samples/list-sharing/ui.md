# UI — ListHub

## Core flows

- **Dashboard:** “My lists,” “Shared with me,” **Public** browse (if enabled).
- **List detail:** items grouped by **category** tabs or sections; drag reorder; inline add.
- **Sharing panel:** visibility radio; **invite** by email; table of members with role dropdown; **transfer ownership** (confirm modal).
- **Public list view:** read-only; optional “Use as template” if product allows.

## Permissions UX

- **Viewer:** cannot reorder or edit items; can copy link if list is link-shared.
- **Editor:** full write; cannot delete list or change billing (if any).
- **Owner:** destructive actions, visibility changes, removing members.
- **Last owner rule:** cannot demote/remove self without transferring ownership (inline validation).

## Patterns

- **Optimistic UI** for item toggle with rollback toast on failure.
- **Conflict:** if server rejects (409), show diff or “refresh to latest” — avoid silent overwrite.

## Empty states

- New list: suggest **default categories** (optional) or start uncategorized.
- Sharing: explain each visibility level with one sentence each.
