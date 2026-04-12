# UI — Skyline Weather

## Design principles

- **Trust over novelty**: show **data age**, **source**, and **units** clearly.
- **Calm alerts**: urgent visually, but not panic copy; one primary action (“View details” / “Open map” if deep-linked).
- **Resilient empties**: never a blank white screen when cache exists—show stale data with label.

## Information architecture

| Area | Purpose |
|------|---------|
| **Home** | Default location or last-used; current conditions; **today** strip; **next hours** chart |
| **Locations** | Search, GPS “use here,” reorder (drag), delete with **undo** snackbar where supported |
| **Location detail** | Segments or tabs: **Hourly** \| **Daily** \| **Alerts** |
| **Settings** | Units, per–alert-type toggles, data attribution, privacy / location explainer, about |
| **Alert detail** (modal or full screen) | Title, severity, window, recommended actions, link out if allowed |

## Home

- **Primary actions**: pull-to-refresh; tap location **chip** to switch; overflow → **Manage locations**.
- **Content order**: **alerts banner** (if any) above main content; then current conditions; then charts.
- **Loading**: skeleton for first load; if cache exists, show cache immediately and **refresh in background**.
- **Error**: non-blaming copy; **Retry**; if offline, explain and show **last updated** time.

## Locations list

- **Search**: debounced typeahead; show **recent** and **popular** when empty.
- **GPS row**: explain **permission** rationale on first use (system dialog + one-line in-app pre-prompt if needed).
- **Reorder**: long-press drag handle; persist order locally (and sync later if accounts exist).
- **Delete**: confirm only if location has **active alerts**; otherwise undo pattern.
- **Limits**: cap max favorites (e.g. 15) with friendly message — **Open:** exact cap TBD.

## Location detail — Hourly

- **Chart**: temperature line + precipitation probability or quantity (provider-dependent); **reduce motion** → simpler table.
- **Scroll**: horizontal scrub or vertical list per hour; pick one pattern per platform and stay consistent.
- **Now** marker clearly labeled.

## Location detail — Daily

- **Rows**: day, condition icon, high/low, precip chance, wind summary (collapsed detail on tap).
- **Tap row**: expand **hourly preview** for that day or navigate to hourly with day preselected — **Open:** UX decision.

## Location detail — Alerts

- List **active** and **recent** (policy: how long “recent” lasts — **Open:**).
- **Tap**: full alert body; **share** disabled unless provider allows.

## Settings

- **Units**: temperature, wind, pressure, precipitation units; preview string updates live.
- **Notifications**: master toggle; per **alert type** toggles; link to OS settings if disabled at system level.
- **Privacy**: short explainer on **location** use; link to full privacy policy.
- **About**: **provider attribution**, license text, app version, open-source notices if applicable.

## Widgets (platform-specific)

| Size | Content |
|------|---------|
| **Small** | Temp, condition icon, location label (truncated) |
| **Medium** | Add **next3–6 hour** precip or temps |
| **Large** | **Daily** min/max row or **hourly** sparkline — **Open:** final layout |

- **Tap targets**: open app to **relevant location** deep link.
- **Refresh**: obey OS budgets; no tight polling loops from widget code.

## Accessibility

- **VoiceOver / TalkBack**: location rows announce **favorite**, **alert count**, and **data age** when shown.
- **Dynamic type**: reflow layouts; chart labels remain legible at largest sizes (fallback to table).
- **Reduce motion**: disable parallax; shorten transitions to instant where possible.
- **Alerts**: combine **icon + text + color**; never rely on red/green alone.

## Empty and error states

| State | Behavior |
|-------|----------|
| **No locations** | Illustration + **Add a city** + **Use GPS** |
| **Provider outage** | Honest copy + **Retry**; show **cached** data with **age** |
| **Location permission denied** | Explain feature loss; button to **open settings** |
| **Search no results** | Suggest spelling; offer **report** only if product supports |

## Copy tone

- Short, plain sentences; **no** shame (“You’re offline”) → prefer **“No connection—showing last forecast.”**
- **Attribution**: neutral (“Forecast from **ProviderName**”) per contract.
