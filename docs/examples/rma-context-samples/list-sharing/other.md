# Other — ListHub

## Security

- **Authorization**: every list-scoped route resolves `listId` → **membership** + **role**; deny by default.
- **IDOR**: never expose sequential ids without authz; prefer **UUID** in URLs.
- **Public lists**: **HTML-escape** titles/descriptions; **CSP** headers on web app.
- **Invites**: **time-limited** tokens; **single-use** accept where possible; constant-time compare.
- **Sessions**: **httpOnly** cookies; **CSRF** on state-changing web forms if cookie-based auth.

## Privacy

- **Export**: user can download their lists (JSON/CSV) within documented SLA.
- **Deletion**: account deletion **cascades** or **anonymizes** per policy — document **retention** for audit logs.
- **PII in logs**: no emails or tokens in **info** logs; redact in structured fields.

## API conventions

- **Errors**: stable `code` (machine) + `message` (human); **no** stack traces to clients.
- **Pagination**: cursor-based for large item lists; **max page size** enforced.
- **Idempotency**: **Idempotency-Key** header on invite resend — **Open:** which routes.

## Compliance (if applicable)

- **GDPR** / regional privacy: DPA with subprocessors; **data residency** — **Open:** regions.
- **Children**: not targeted at under-13 without parental flows — product decision.

## Branching and review

- **Protected main**; **1 approval** for merge; **context** updates (`.rma` or these samples mirrored in real project) alongside schema changes when possible.
- **Security-sensitive** PRs (auth, visibility): extra reviewer.

## Third-party integrations

| Integration | Notes | Env (names) |
|-------------|-------|-------------|
| Email | Invite delivery, bounce handling | `EMAIL_API_KEY` |
| OAuth | Google/GitHub sign-in | `AUTH_GOOGLE_*`, `AUTH_GITHUB_*` — **Open:** exact names |
| Future webhooks | Outbound events | **Open:** signing secret name |

## Conventions

- **IDs**: **UUIDv7** or **ULID** for new rows.
- **Timestamps**: **UTC** in DB; ISO-8601 in API.
- **Time zones**: list-level **optional** TZ for due dates — **Open:** user TZ vs list TZ.

## Runbooks (links)

- **Open:** Link to on-call doc for **DB failover** and **auth outage**.

## Open:

- **Open:** **Rate limits** for public catalog and anonymous endpoints (numeric values).
- **Open:** **Data retention** for soft-deleted lists (30 vs 90 days).
