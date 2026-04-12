# UI — ListHub

## Design principles

- **Permissions first**: every screen that mutates state shows **role** context (“You’re an editor on this list”).
- **No silent data loss**: concurrent edits produce a **clear** recovery path (refresh, retry, optional diff).
- **Progressive disclosure**: sharing and visibility are high-impact—use **confirmations** for destructive, irreversible, or **public** actions.
- **Honest latency**: show **saving…** for slow networks; do not fake success before server ack for destructive actions.

## Information architecture

| Screen / surface | Purpose | Primary roles |
|------------------|---------|---------------|
| **Dashboard** | Owned lists, shared with me, optional **Public browse** | All |
| **List detail** | Items by **category**; add, complete, reorder | Editor+ |
| **Sharing** | Visibility, invites, members, transfer ownership | Owner (invites: editor+ per policy) |
| **Public list** | Read-only view; CTA to sign up / duplicate | Anonymous or logged-in |
| **Account / settings** | Profile, sessions, **export data** | All |
| **Invite landing** | Accept / decline invite; explain role | Invitee |

## Global chrome

- **App header**: product name, **New list**, account menu (profile, sign out).
- **Breadcrumbs** (web): Dashboard → List name → optional sub-view.
- **Role badge**: persistent on list detail and sharing (`Owner` / `Editor` / `Viewer`).

## Dashboard

### Layout

- **Sections or tabs**: **Owned**, **Shared with me**, **Public** (if feature enabled).
- **Quick add**: header **New list** → modal: title (required), default visibility **PRIVATE**, optional description.

### List cards

- **Title**, **item count**, **last activity** (relative time), up to **3 collaborator avatars** (overflow “+N”).
- **Badges**: `LINK` or `PUBLIC` when not private; subtle **unread** or **conflict** indicator if backend signals—**Open:** notification model.

### Loading, empty, error

- **Loading**: skeleton cards (3–6 placeholders), no layout jump.
- **Empty (owned)**: short value prop + **Create list** + optional **Browse public** if on.
- **Empty (shared)**: explain invites; link to **account email** settings if wrong inbox.
- **Error**: inline banner with **Retry**; do not wipe cached list on transient failure.

## List detail

### Header

- **Title**: inline edit for **editor+**; **viewer** sees static title.
- **Overflow menu**: **Share** (all members), **List settings** (owner: delete, transfer), **Leave list** (non-owner).

### Categories

- **Tabs** or **accordion** per category; **uncategorized** bucket if allowed.
- **Drag** items **across** categories for **editors**; **viewers** see static grouping.
- **Open:** max categories per list (soft limit + warning).

### Add item

- Sticky composer or inline row: **title** required; **notes** optional; **due date** optional.
- **Enter** submits; **Shift+Enter** newline in notes.
- **Open:** assignee picker—defer if not in MVP schema.

### Item row

- **Checkbox** (complete), **title** (strikethrough when done), **due** badge, expand for **notes**.
- **Reorder**: drag handle for editors; keyboard alternative where feasible (**Open:** full keyboard spec).

### Filters

- Toggle **hide completed**; filter by **category**; optional **search** within list—**Open:** v1.1.

## Sharing panel (modal or side sheet)

### Visibility

- **Radio** or segmented control: **Private** / **Link** / **Public** — each with **one-sentence** consequence.
- **Public**: secondary confirm (“Visible in catalog”) before apply.

### Invites

- Email field + **role** dropdown (default **editor**); **Send** creates pending invite.
- Show **pending** rows: email, role, **Resend** (rate-limited), **Revoke**.

### Members

- Table: name/email, role (owner-only can change), **Remove** with confirm.
- **Transfer ownership**: modal; type list name; previous owner becomes **editor** unless they leave.

### Last-owner rule

- UI **disables** self-demotion or leave if sole **owner** until **transfer** completes.

## Public list view

- **Read-only**; no edit chrome.
- **SEO**: `<title>` and meta description from list fields only; **no** member emails in HTML.
- **CTA**: “Use as template” → auth gate → creates private copy—**Open:** guest flow.

## Conflict and concurrency UX

- On **409** or version mismatch: banner **“Someone else updated this list.”**
- Actions: **Refresh** (reload server state), **Retry my edit** (re-apply if still valid)—**Open:** item-level diff depth.
- **Open:** whether to show **which actor** triggered conflict (privacy vs debuggability).

## Rate limiting (UX)

- Friendly copy when invite or public endpoint is throttled (“Try again in a minute”); no raw HTTP codes to end users.

## Empty states (additional)

- **No categories yet**: prompt **Add category** or use **uncategorized** stream.
- **Viewer lands on edit URL**: explain read-only; **Request access** — **Open:** product decision.

## Accessibility

- **Keyboard**: focus order matches visual order; modals **trap focus**; **Esc** closes non-destructive modals.
- **Screen readers**: announce **list title** and **your role** on route enter; landmarks for main content.
- **Contrast**: completed items use **strikethrough +** icon or text, not color alone for state.
- **Motion**: respect `prefers-reduced-motion` for reorder animations.

## Copy tone

- Friendly, **action-oriented** (“Invite someone to edit”) not jargon (“ACL”, “RBAC” in user-facing strings).
- Errors: **what happened** + **what to do** (“Refresh to see the latest changes.”).
- **Open:** localization—English-only MVP vs i18n keys from day one.
