# Stack — ListHub

## Runtime and layers

| Layer | Choice | Notes |
|-------|--------|--------|
| API | **Node** + **Fastify** *or* **Next.js Route Handlers** | REST v1; JSON; **Open:** GraphQL only if explicit ADR |
| DB | **PostgreSQL** 15+ | Connections pooled; migrations versioned in repo |
| ORM | **Prisma** | `prisma migrate`; generate client in CI |
| Auth | **Better Auth** / **Auth.js** / **Clerk** | Session or JWT per vendor; **Open:** final pick |
| Frontend | **Next.js** App Router + **React** 18+ | RSC for read-heavy; client components for drag-and-drop |
| Cache | **Redis** (optional) | Rate limits, session cache, invite throttle |
| Email | **Resend** / **Postmark** | Transactional invites; webhooks for bounces — **Open:** vendor |
| Hosting | **Vercel** / **Fly.io** | **Open:** region pinning for data residency |

## Data model (conceptual)

- **Core entities**: `User`, `List`, `ListMember` (`userId`, `listId`, `role`, `invitedBy`, `joinedAt`), `Item`, `Category`, `Invitation` (token hash, email, `expiresAt`, `listId`, intended `role`).
- **Concurrency**: integer **`version`** on `List` (and optionally `Item`) for optimistic locking; API returns current version on reads—**Open:** `ETag` exposure.
- **Soft delete**: `deletedAt` on `List` / `Item` if product requires recovery window—align retention with `other.md`.

## Repository layout (suggested)

```text
apps/web/                 # Next.js app
packages/api/             # HTTP handlers or shared server logic
packages/db/              # Prisma schema, migrations, seed
e2e/                      # Playwright
infra/                    # Optional IaC
```

## Local development

```bash
pnpm install
cp .env.example .env      # DATABASE_URL, AUTH_*, EMAIL_*, etc. (names only in docs)
pnpm exec prisma migrate dev
pnpm dev
```

- **Postgres**: Docker Compose or local install; document port in `run.md` when this repo ships a real app.

## Build and test

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm exec prisma migrate deploy    # CI/prod pipelines
```

| Suite | Scope |
|-------|--------|
| **Unit** | Pure helpers, authz guards, validation |
| **Integration** | DB + API with testcontainers or dedicated DB |
| **E2E** (Playwright) | Invite flow, role denial paths, public read-only |

**Open:** E2E in CI on every PR vs nightly.

## CI

- **Matrix**: Node LTS; **Postgres** service container for integration tests.
- **Schema**: fail PR if `prisma migrate diff` shows drift vs committed migrations.
- **Secrets**: inject `DATABASE_URL`, `AUTH_SECRET`, `EMAIL_API_KEY` from CI secret store—document **names** only in README/`run.md`.

## Observability

- **Logs**: structured JSON in production; include **request id**, **user id** (when authenticated), **list id** (when scoped)—never raw tokens.
- **Metrics**: p50/p95 latency, error rate by route, invite send failures.
- **Tracing**: **Open:** enable OpenTelemetry when traffic warrants.

## Environment variables (names only)

| Name | Purpose |
|------|---------|
| `DATABASE_URL` | Postgres connection string |
| `AUTH_SECRET` | Session signing / encryption |
| `AUTH_URL` | Canonical app URL for OAuth callbacks |
| `EMAIL_API_KEY` | Transactional email API |
| `REDIS_URL` | Optional cache / rate limit backend |
| `SENTRY_DSN` | Optional error reporting |

## Deployment

- **Database**: managed Postgres with **automated backups** and **PITR** when available; test restore quarterly—**Open:** runbook link.
- **Migrations**: `prisma migrate deploy` in release pipeline; block deploy on failure.
- **Staging**: separate OAuth apps and DB; no prod data in staging without anonymization.

## Cost and capacity notes

- Email and DB scale with **invites** and **items**; monitor **public catalog** query cost—**Open:** read replicas for catalog.

## Version pins (illustrative)

Document **actual** versions in the real repo’s `package.json` / `engines`—this exemplar does not pin semver to avoid stale numbers:

- Node: **LTS** (even major)
- Postgres: **15+**
- Prisma: follow **current** stable in lockfile
