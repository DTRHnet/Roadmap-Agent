# Other — ListHub

## Security

- **Authorization:** every list-scoped route checks **membership and role**; never trust `listId` from the client without a server check.
- **Public lists:** sanitize titles and descriptions for XSS; rate-limit anonymous endpoints.
- **Invites:** time-limited tokens; single-use where possible.

## Privacy

- **Export and delete:** users can request data export and account deletion where required by law; document an internal SLA.
- **Audit:** log role changes and visibility changes with actor id and timestamp.

## Conventions

- **IDs:** UUIDv7 or ULID in new code; opaque tokens in URLs for public slugs.
- **API errors:** stable `code` field plus human-readable `message`; no stack traces to clients.

## Integrations (later)

- Email provider for invites (e.g. Resend, Postmark).
- Webhooks for external automation — out of scope until the public API is stable.
