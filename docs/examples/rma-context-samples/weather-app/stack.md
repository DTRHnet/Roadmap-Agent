# Stack — Skyline Weather

## Runtime and versions

| Component | Choice | Notes |
|-----------|--------|--------|
| Mobile | **Flutter** 3.24+ (iOS + Android) | Single codebase; platform channels for widgets |
| Language | **Dart** 3.x | Strict analysis; `flutter_lints` |
| State | **Riverpod** *or* **Bloc** | **Open:** pick one; document ADR before scaling |
| HTTP | **dio** | Interceptors: timeouts, retry with jitter, ETag if provider supports |
| Serialization | **json_serializable** / **freezed** | Version DTOs when provider schema changes |
| Local cache | **Hive** *or* **Isar** | Store **station bundles** + metadata (fetchedAt, etag) |
| Push | **FCM** (Android) + **APNs** (iOS) | Topic or token model; payload maps to alert ids |

## Optional backend (BFF) — post-MVP

- **Node (Fastify)** or **Go** if API keys must not live in the app or for **alert fan-out** at scale.
- **Redis**: rate limiting, idempotency keys for webhook ingestion (if we receive provider webhooks).

## Data providers

- **Forecast + alerts**: commercial provider **TBD** — contract, SLA, regional tiles, attribution string.
- **Geocoding**: provider bundle or **Open-Meteo** geocoder for search MVP — **Open:** final choice.

## Repository layout (suggested)

```text
lib/
  app/           # router, theme, localization
  features/
    home/
    locations/
    detail/
    settings/
    alerts/
  core/
    api/         # dio client, DTOs, mappers
    cache/       # station bundle store
    widgets/     # shared UI
test/
integration_test/
```

## Local development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

- **Flavor** or **dart-define** for `FORECAST_API_BASE`, `FORECAST_API_KEY` (never commit values).

## CI (suggested)

```bash
flutter analyze --no-fatal-infos   # tune per team
flutter test
flutter build apk --debug # PR gate
# Release: signed build on protected branch only
```

- **Secrets**: CI injects via provider secrets (GitHub Actions, Codemagic, etc.); no keys in YAML.

## Observability

- **Crash reporting**: e.g. **Firebase Crashlytics** or **Sentry** — **Open:** vendor.
- **Analytics** (if any): privacy-reviewed; **no** precise location in event payloads without consent.
- **Logging**: structured debug logs in dev; **release** strips coordinates and tokens.

## Environment variables and defines (names only)

| Name | Purpose |
|------|---------|
| `FORECAST_API_BASE` | Provider REST base URL |
| `FORECAST_API_KEY` | Provider key (prefer remote config or BFF later) |
| `GEOCODE_API_BASE` | Geocoding endpoint |
| `GEOCODE_API_KEY` | Geocoding key if required |
| `SENTRY_DSN` | Optional crash reporting |
| `APP_ENV` | `dev` / `staging` / `prod` |

## Deployment

- **Stores**: Google Play + App Store Connect; **staged rollout**; internal testing tracks.
- **Compliance**: store privacy labels aligned with actual location and notification behavior.
- **Versioning**: **semver** for app (`major.minor.patch`); track **provider schema** version inside **station bundle** metadata if needed.

## Cost and ops notes

- Provider pricing scales with **MAU** and **call volume**; mitigate with **ETag**, **reasonable refresh**, and **BFF caching** when introduced.
- Widgets and background fetch can inflate costs — align refresh policy with product — **Open:** document in ADR.
