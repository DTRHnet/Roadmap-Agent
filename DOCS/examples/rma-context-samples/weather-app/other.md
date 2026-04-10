# Other — Skyline Weather

## Compliance and privacy

- **Location:** explain foreground vs background collection; link privacy policy before enabling GPS or notifications.
- **Retention:** trim old forecast blobs after N days unless user pins a location.
- **Attribution:** show provider name and license string on Settings → About (required by contract).

## API and limits

- Respect provider **QPS**; backoff on 429; never hammer from widgets on a tight loop—use scheduled jobs server-side if we add a BFF.

## Conventions

- **Versioning:** semver for app; API versions only if we own a public API.
- **Logging:** no raw coordinates in debug logs in release builds.

## Open decisions

- Guest vs account-first: default **guest** with optional **Apple/Google** sign-in for sync.
- Widget refresh cadence vs battery — document chosen policy in ADR-00x.
