# Stack — ListHub

## Suggested shape (MVP)

| Layer | Choice | Notes |
|-------|--------|--------|
| API | **Node + Fastify** or **Next.js Route Handlers** | REST or tRPC — pick one |
| DB | **PostgreSQL** | Row-level checks for list membership |
| ORM | **Prisma** | Migrations in repo |
| Auth | **Better Auth** / **Auth.js** / **Clerk** (evaluate) | Sessions + OAuth |
| Frontend | **Next.js (App Router)** + **React** | Server components where possible |
| Cache | **Redis** (optional) | Session, rate limits |

## Data model (conceptual)

- `User`, `List`, `ListMember(userId, listId, role)`, `Item`, `Category`, `Invitation`.

## Build and test

```bash
pnpm install
pnpm lint
pnpm test
pnpm exec prisma migrate dev
```

## Deployment

- **Vercel** or **Fly.io** for app + managed Postgres.
- **Secrets** in platform env; rotate invite signing keys on schedule.
