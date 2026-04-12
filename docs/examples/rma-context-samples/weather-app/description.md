# Skyline Weather

## Summary

Skyline Weather is a cross-platform mobile app for **hourly and multi-day forecasts**, **severe weather alerts**, and **home-screen widgets**. Users save **favorite locations** (city search or GPS), choose units and display preferences, and get **push notifications** when alerts apply to any saved place. The product prioritizes **fast cold start**, **offline-friendly** display of the last good forecast, and **accessible** alert presentation.

## Problem statement

Casual weather apps often bury alerts, refresh unpredictably, or fail offline. Power users need **multiple locations**, **reliable alert timing**, and **widgets** without draining battery. Skyline aims to balance **accuracy**, **attribution compliance**, and **trust** (clear “last updated” and data source).

## Users and personas

| Persona | Who they are | What they need |
|---------|--------------|----------------|
| **Commuter Alex** | Daily train/car commuter | Precise **precipitation start/stop** in the next hours; minimal taps |
| **Planner Jordan** | Hikes, sports, outdoor work | **Wind**, **UV**, **feels-like**, multi-day trends; multiple cities |
| **Widget-first Sam** | Glances at home screen | **Reliable widget refresh**, low battery impact, readable at a glance |
| **Alert-sensitive Riley** | Lives in storm-prone region | **Severe alerts** with clear actions; respects **Do Not Disturb** rules where OS allows |

### Scenario: Alex (commute)

Alex adds “Home” and “Office,” enables **rain alerts** only for Home, and checks the **next-hours** strip before leaving. If the network fails on the platform, Alex still sees **stale data with age** (“Updated 12 min ago”) rather than a blank screen.

### Scenario: Jordan (planning)

Jordan saves three trailhead locations, compares **daily min/max** and **wind gusts**, and shares a screenshot of the **7-day** view. Jordan expects **units** (mph vs m/s, °F vs °C) to apply everywhere, including widgets.

## Goals

- **Accurate, attributed** forecast data with visible **provider** and **last-updated** timestamps.
- **Performant** cold start; **cache** last successful response per location (“station bundle”).
- **Accessible** UI: alert banners are not **color-only**; charts have pattern/text fallbacks.
- **Predictable** refresh: user-visible policy for pull-to-refresh vs background (document in `stack.md` / ADR).
- **Location respect**: foreground vs background explained; minimal retention of precise coordinates in logs.

## Non-goals

- Building a **full radar animation studio** or proprietary weather model (deep-link to partner radar if needed).
- Long-form **climate education** or news feed inside the app.
- **Selling** or **brokerage** of user location data to third parties.
- **Desktop** or **web** clients in MVP (mobile-first only unless explicitly reopened).

## MVP vs later

| Phase | Scope |
|-------|--------|
| **MVP** | Locations list, detail (hourly + daily), settings (units, notifications per alert type), basic offline cache, one primary forecast provider, **in-app** attribution |
| **v1.1** | Home-screen **widgets** (size variants), polish on **alert** detail screens |
| **Later** | Optional **account** for cross-device sync of favorites; **BFF** for protected API keys and alert fan-out; additional providers behind a feature flag |

## Success criteria

- Cold start to **interactive** home screen under a defined target (e.g. under **2s** on mid-range device) with warm cache.
- **100%** of alert surfaces pass **WCAG-oriented** checks for contrast and non-color cues (internal QA checklist).
- **Zero** production logs containing raw **lat/long** pairs (audit in release builds).
- Provider **attribution** visible within **two taps** from any forecast screen.
- User can **add**, **reorder**, and **delete** locations with **undo** where the OS pattern supports it.

## Glossary

| Term | Meaning |
|------|---------|
| **Station bundle** | Cached JSON (and metadata) for one **location** + provider snapshot: used for offline display and ETag refresh |
| **Alert window** | Provider-defined **start/end** for a severe event; may span multiple notifications |
| **Favorite location** | User-saved place with stable **place id** internally; may differ from provider’s station id across versions |
| **Widget snapshot** | Last-rendered data subset exposed to the widget extension; refresh cadence constrained by OS |

## Open:

- **Open:** Primary forecast **provider** (contract, SLA, attribution string, regional coverage).
- **Open:** State management choice **Riverpod vs Bloc** — pick one before large feature work; record ADR.
- **Open:** Local store **Hive vs Isar** for MVP (migration path if we switch).
- **Open:** **Guest-only** MVP vs **optional sign-in** in v1 for sync (impacts backend scope).
- **Open:** Whether **widgets** ship in MVP or v1.1 (affects store review timeline and QA).
