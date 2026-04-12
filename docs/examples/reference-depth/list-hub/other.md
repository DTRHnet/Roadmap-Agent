# Other — ListHub

## Threat model (practical)

| Threat | Mitigation |
|--------|------------|
| **IDOR** on `listId` | Resolve membership + role on **every** list-scoped handler; UUIDs in URLs |
| **Token reuse** (invites) | Short TTL; **single-use** accept; hash tokens at rest; constant-time compare |
| **XSS** on public pages | Escape output; **CSP** baseline; no `dangerouslySetInnerHTML` for user titles |
| **CSRF** | SameSite cookies + CSRF token for cookie-based session POSTs from web forms |
| **Enumeration** | Generic errors for “invite not found”; rate-limit invite **accept** by IP + token |
| **Abuse** (public catalog) | Rate limits; **Open:** numeric caps; CAPTCHA only if needed |

## Security (implementation)

- **Deny by default**: unauthenticated users only access routes explicitly public (`PUBLIC` list read, health).
- **Role matrix** enforced in **service layer** (not only UI); integration tests for **viewer** denied PATCH.
- **Secrets**: never in repo; `.env` gitignored; CI uses secret manager—**names** documented in `stack.md` / `run.md` only.

## Privacy

- **Export**: user-initiated JSON/CSV of **their** lists within documented SLA (e.g. 48h async job if huge).
- **Deletion**: account deletion **cascades** or **anonymizes** list content per policy; document **audit log retention** (e.g. 90 days for security).
- **Logs**: no email bodies or invite tokens in **info** logs; use opaque ids; redact in debug tooling.

## API conventions

| Topic | Rule |
|-------|------|
| **Errors** | Stable `code` + human `message`; **no** stack traces to clients; trace id in header for support |
| **Pagination** | Cursor-based for items; **max** page size (e.g. 100) |
| **Idempotency** | `Idempotency-Key` on **invite resend** and other retriable POSTs — **Open:** full route list |
| **Versioning** | `/v1/` prefix; breaking changes require v2 or deprecation window |

## Compliance (if applicable)

- **GDPR**: lawful basis documented; DPA with subprocessors (email, hosting); **Open:** EU residency.
- **Children**: not directed at under-13; block signup below threshold if required by law—**Open:** age gate.

## Branching and review

- **Protected `main`**; at least **one** approval for merge.
- **Schema / auth / visibility** changes: **two** reviewers when possible.
- **Context updates**: when behavior changes, update `.rma` Markdown in same PR as code so **`plan`** / agents stay aligned.

## Third-party integrations

| Integration | Notes | Env (names) |
|-------------|-------|---------------|
| Email | Invites, bounces | `EMAIL_API_KEY` |
| OAuth | Google / GitHub | `AUTH_GOOGLE_*`, `AUTH_GITHUB_*` — align with chosen auth vendor |
| Error tracking | Optional | `SENTRY_DSN` |

## Operational limits (placeholders)

- **Open:** **Rate limits**: public catalog **N** req/min/IP; invite send **M** per hour per account.
- **Open:** **Soft-delete retention** for lists (e.g. 30 days before purge).
- **Open:** **Max items per list** (soft cap + admin override).

## Conventions

- **IDs**: **UUIDv7** or **ULID** for new rows (sortable, non-sequential).
- **Time**: **UTC** in DB; **ISO-8601** in API; **Open:** list-level TZ for due dates vs user TZ.

## Runbooks

- **Open:** links to **DB failover**, **auth provider outage**, **email provider degradation** (internal wiki).

## Open:

- **Open:** **Numeric** rate limits for catalog and anonymous endpoints (document when set).
- **Open:** **Audit log** export for enterprise customers (later).
- **Open:** **Data residency** regions for hosted offering.
