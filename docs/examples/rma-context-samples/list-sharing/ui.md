# UI — ListHub

## Design principles

- **Permissions first**: every screen that mutates state shows **role** context (“You’re an editor”).
- **No silent data loss**: conflicts produce a **clear** recovery path.
- **Progressive disclosure**: sharing and visibility are powerful—use **confirmations** for destructive or public actions.

## Information architecture

| Screen | Purpose |
|--------|---------|
| **Dashboard** | “My lists,” “Shared with me,” **Public browse** (if feature on) |
| **List detail** | Items grouped by **category**; add, reorder, complete |
| **Sharing** | Visibility, invites, member table, transfer ownership |
| **Public list** | Read-only; optional CTA to sign up / duplicate |
| **Settings / account** | Profile, sessions, export — **Open:** scope |

## Dashboard

- **Tabs or sections**: **Owned**, **Shared**, **Public** (if enabled).
- **Quick add**: optional FAB or header **New list** → modal (title, default visibility **private**).
- **List cards**: title, item count, **last activity**, avatars of **top collaborators** (max 3).
- **Empty**: explain value prop + template examples — **Open:** templates in MVP?

## List detail

- **Header**: title (inline edit if **editor+**), **overflow**: share, settings, delete list (**owner** only, confirm).
- **Categories**: tabs or collapsible sections; **drag** items **across** categories if editor.
- **Add item**: sticky input or inline row; **Enter** saves; **Shift+Enter** for newline in notes — **Open:** rich text later?
- **Item row**: checkbox complete, title, **due** badge, **assignee** chip (if feature on); expand for **notes**.
- **Reorder**: drag handle visible to **editors**; viewers see static order.
- **Filter**: complete/hide completed toggle; filter by category.

## Sharing panel (modal or side sheet)

- **Visibility** radio: **Private** / **Link** / **Public** — each with **one-sentence** consequence.
- **Invite**: email field + role dropdown (**editor** default); **Send** creates pending invite.
- **Members table**: name/email, role dropdown (**owner** only can change roles), **Remove** with confirm.
- **Transfer ownership**: modal with **type list name** confirmation; previous owner becomes **editor** unless they choose to leave.
- **Last owner rule**: UI disables **demote self** if sole owner until transfer completes.

## Permissions UX (summary)

| Role | Capabilities |
|------|----------------|
| **Viewer** | Read items; copy **link** if `LINK` or `PUBLIC`; no reorder/edit |
| **Editor** | CRUD items/categories; cannot delete list or change billing |
| **Owner** | Visibility, invites, remove members, delete list, transfer ownership |

## Public list view

- **Read-only** chrome; no edit affordances.
- **Optional**: “Use as template” → auth gate → creates private copy — **Open:** guest vs signed-in.
- **SEO**: title + description meta; **no** member emails in HTML.

## Patterns

- **Optimistic UI** for item toggle; **rollback** toast on failure with **Retry**.
- **409 Conflict**: show **“Someone else updated this list”** + **Refresh** + optional **diff** of affected items — **Open:** diff depth.
- **Rate limit**: friendly message if invite spam detected.

## Empty states

- **New list**: offer **default categories** (toggle) or start uncategorized.
- **Sharing**: explain each visibility level with **one line** each.
- **No shared lists**: CTA to create or **enter invite code** if product supports.

## Accessibility

- **Keyboard**: reorder via keyboard where possible; focus trap in modals.
- **Roles**: announce **list title** and **your role** on enter (web: `aria` landmarks).
- **Contrast**: completed items use **strikethrough +** muted color, not color alone.

## Copy tone

- Friendly, **action-oriented** (“Share with household”) not jargon (“ACL”).
- Errors: **what happened** + **what to do** (“Refresh to see the latest changes.”).
