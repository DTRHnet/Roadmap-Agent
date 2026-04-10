# Stack — Skyline Weather

## Runtime

| Layer | Choice | Notes |
|-------|--------|--------|
| Mobile | **Flutter** 3.x (iOS + Android) | Single codebase; platform channels for widgets |
| State | **Riverpod** or **Bloc** | Pick one; document in ADR |
| HTTP | **dio** | Interceptors for auth + retry |
| Local cache | **Hive** or **Isar** | Store last JSON bundles + ETags |
| Push | **FCM** (Android) + **APNs** (iOS) | Server or Firebase for topic routing |

## Backend (optional for v1)

- **BFF** in **Node (Fastify)** or **Go** if we need API key protection and alert fan-out.
- **Redis** for rate limits and short-lived session tokens.

## Data providers

- Forecast + alerts: **commercial provider TBD** (contract, SLA, attribution string).
- Geocoding: provider or **Open-Meteo** geocoder for search MVP.

## Build and test

```bash
flutter analyze
flutter test
flutter build apk   # CI
flutter build ipa   # release pipeline with signing
```

## Deployment

- **Stores:** Play Console + App Store Connect; staged rollout.
- **Secrets:** never in repo; CI injects via sealed variables.
