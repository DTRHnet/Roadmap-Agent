# UI — Skyline Weather

## Information architecture

- **Home:** current conditions + today strip + “next hours” chart; pull-to-refresh.
- **Locations:** search, GPS “use here,” reorder (drag), delete with undo snackbar.
- **Detail (location):** tabs or segments — *Hourly* | *Daily* | *Alerts*.
- **Settings:** units, notification toggles per alert type, data attribution, about.

## Visual and motion

- **Light/dark** follow OS; charts use distinct series colors with pattern fill fallback.
- **Alerts:** full-width banner above content; tap opens detail; dismiss is per-alert, not global hide forever.
- **Widgets (platform-specific):** small = temp + condition icon; medium = add hourly sparkline; large = weekly min/max.

## Accessibility

- **VoiceOver / TalkBack:** location list announces “favorite” state and alert count.
- **Dynamic type:** layout reflows; chart labels remain legible at largest sizes.
- **Reduce motion:** disable parallax; shorten transition duration to 0 where possible.

## Empty and error states

- **No locations:** illustration + “Add a city” CTA + GPS shortcut.
- **Provider outage:** non-blaming copy + retry; show stale data age if cache exists.
