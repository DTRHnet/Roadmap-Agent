# Other — Skyline Weather

## Security

- **API keys**: not in source control; use CI secrets and local `.env` / define files gitignored.
- **Certificate pinning**: **Open:** evaluate for provider endpoints if threat model requires it (maintenance cost).
- **Deep links**: validate **alert** and **location** ids; reject malformed payloads.
- **Push payloads**: contain **no** PII beyond what’s needed; prefer opaque ids resolved in-app.

## Privacy and compliance

- **Location**: collect **only** what’s needed; disclose **foreground** vs **background** in privacy policy and in-app before enabling.
- **Retention**: trim old **station bundles** after **N** days unless user has pinned location — **Open:** N.
- **Attribution**: show provider name and license string in **Settings → About** as required by contract.
- **Children**: if distributed in regions with **COPPA**-style rules, ensure no behavioral ads without parental gates — **Open:** product decision.

## Third-party APIs and limits

- Respect provider **QPS** and **daily caps**; exponential backoff on **429** and **5xx**.
- **Widgets** and **background** tasks must not hammer the network—use **coalesced** refresh and OS-recommended intervals.
- Document **vendor incident** runbook (who pages, how to show “degraded” in-app).

## API and error handling (app-internal)

- Map provider errors to **user-safe** messages; log **correlation id** only in diagnostics builds.
- **Never** show raw stack traces in UI.

## Branching and review

- **Main** is releasable; feature branches for work taking **more than one day**.
- **PR** requires: analyze clean, tests for business logic, screenshot or recording for UI changes when helpful.
- **Context updates**: when provider or cache strategy changes, update **`stack.md`** and **`description.md`** in the same PR when possible.

## Conventions

- **IDs**: internal **location id** (UUIDv7 or ULID); provider ids stored separately for mapping upgrades.
- **Time**: store **UTC**; display in user **local** timezone with clear labels for “today” boundaries.
- **i18n**: externalize strings; RTL tested for **locations** and **charts** where applicable.
- **Versioning**: **semver** app; document **bundle schema version** in cache layer if migrations needed.

## Audit and support

- **Support bundle** (optional): export **non-sensitive** diagnostics (app version, last error code) — no tokens.

## Open:

- **Open:** DPA and subprocessors list for chosen forecast provider.
- **Open:** Whether **analytics** is in scope for MVP and which events are allowlisted.
