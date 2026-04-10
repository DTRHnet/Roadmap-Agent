# Skyline Weather

## Summary

Skyline Weather is a cross-platform client for **hourly and multi-day forecasts**, **severe weather alerts**, and **at-a-glance home-screen widgets**. Users save **favorite locations** (city search + GPS), switch units (°C/°F, wind, pressure), and receive **push notifications** when alerts fire for any saved place.

## Users

- Commuters who need reliable precipitation timing.
- Outdoor planners who care about wind and UV index.
- Power users who want widgets and multiple locations without account friction (guest mode) with optional sign-in for sync.

## Goals

- Accurate, attributed forecast data with clear **last-updated** timestamps.
- Fast cold start and **offline-friendly** display of last good data.
- Accessible typography and color-safe **alert banners** (not color-only).

## Non-goals

- Hyperlocal radar animation studio (partner or deep-link only).
- Long-form climate science education inside the app.
- Selling user location data.

## Glossary

| Term | Meaning |
|------|---------|
| **Station bundle** | Cached response for one location + provider snapshot ID. |
| **Alert window** | Provider-defined start/end for a severe weather event. |
