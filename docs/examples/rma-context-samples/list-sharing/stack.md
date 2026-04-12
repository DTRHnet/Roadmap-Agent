# Stack — ListHub

## Runtime and layers

| Layer | Choice | Notes |
|-------|--------|--------|
| API | **Node + Fastify** *or* **Next.js Route Handlers** | REST v1; **Open:** tRPC alternative |
| DB | **PostgreSQL** 15+ | Row-level **membership** enforced in queries + service layer |
| ORM | **Prisma** | Migrations in repo; `prisma migrate` in CI |
| Auth | **Better Auth** / **Auth.js** / **Clerk** | Sessions + OAuth; **Open:** final pick |
| Frontend | **Next.js** (App Router) + **React** 18+ | Server components for read-heavy views |
| Cache | **Redis** (optional) | Rate limits, session cache, invite throttle |
| Email | **Resend** / **Postmark** | Transactional invites — **Open:** vendor |
| Hosting | **Vercel** / **Fly.io** | **Open:** single region vs multi |

## Data model (conceptual)

- `User`, `List`, `ListMember(userId, listId, role, invitedBy, invitedAt)`, `Item`, `Category`, `Invitation(token, email, expiresAt, listId, role)`.
- **Version** column on `List` or `Item` for optimistic concurrency — **Open:** granularity.

## Repository layout (suggested)

```text
apps/web/ # Next.js
packages/api/             # shared handlers or separate service
packages/db/              # Prisma schema + client
infra/                    # IaC optional
```

## Local development

```bash
pnpm install
cp .env.example .env      # fill DATABASE_URL, AUTH_SECRET, etc.
pnpm exec prisma migrate dev
pnpm dev
```

## Build and test

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm exec prisma migrate deploy   # staging/prod pipelines
```

- **E2E** (Playwright): invite flow, role enforcement smoke — **Open:** CI stage.

## CI

- **Matrix**: Node LTS; **Postgres** service container for integration tests.
- **Migrations**: `prisma migrate diff` check on PR if schema changes.
- **Secrets**: `DATABASE_URL`, `AUTH_SECRET`, `EMAIL_API_KEY` from CI secrets — **names only** in docs.

## Observability

- **Structured logs**: JSON in prod; **request id** per HTTP request.
- **Metrics**: latency, 4xx/5xx, invite send failures — **Open:** vendor (Datadog, Grafana Cloud, etc.).
- **Tracing**: optional OpenTelemetry for API — **Open:** when to enable.

## Environment variables (names only)

| Name | Purpose |
|------|---------|
| `DATABASE_URL` | Postgres connection |
| `AUTH_SECRET` | Session signing |
| `AUTH_URL` | Canonical app URL for OAuth callbacks |
| `EMAIL_API_KEY` | Transactional email |
| `REDIS_URL` | Optional cache / rate limit |
| `SENTRY_DSN` | Optional error reporting |

## Deployment

- **Managed Postgres** (Neon, RDS, Supabase) with **backups** and **PITR** if available.
- **Rotate** invite signing keys on schedule; document procedure in runbook.
- **Staging** environment mirrors prod auth providers (separate OAuth apps).

## Cost notes

- Email volume scales with invites; add **cooldown** and **captcha** if abuse appears — document in `other.md` when enforced.
