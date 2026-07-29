# SwimTracker — native iOS app

Personal tracker for swim times, meets, scores, and goals. Built with SwiftUI.
See the [repo root README](../README.md) for the full feature overview.

## Tabs

- **Home** — upcoming meets, stroke radar (overall score per stroke), recent meets.
- **Times** — best time per event with World Aquatics points; event detail has
  history, splits, and a progression graph. Goals (all-time / meet) open from here.
- **Meets** — meet name, team, location, date; individual and relay events with
  times now or later. Individual results sync into Times.
- **Score** — weighted overall, top events, by-team scores, year / season
  progression chart, and a time ↔ points calculator.
- **Convert** — SCY ↔ SCM ↔ LCM (Colorado Timing factors).

### Times & scoring

Events are distance + stroke + **course** (SCY / SCM / LCM). The list shows your
**best** time per event.

Points use `P = 1000 × (base ÷ time)³`. Bases: World Aquatics for SCM/LCM, U.S.
Open for SCY. Gender for “Your Score” and badges is set in Settings; Calc can
score either gender. Edit bases under Base Times in the Score tab.

Overall score = weighted average of your best four individual events
(**40% / 40% / 15% / 5%**, renormalized if fewer). Year chart points use only
that year’s swims; season chart is monthly season-to-date from each August.

### Meets

Creating a meet captures name, **team**, location, and date. Add individual and
relay events then or later. Relays stay per-meet; individual times feed Times
(linked to the meet).

### Goals & widget

Per-event all-time and meet goal times. The **SwimTrackerWidget** shows goal
progress via an App Group shared with the app.

## Requirements

- Mac with **Xcode 15+** (iOS 17 SDK)
- Free **Apple ID** in Xcode
- iPhone on **iOS 17+**

## Project layout

```
SwimTracker/
├─ SwimTracker.xcodeproj/       # shared "SwimTracker" scheme
├─ SwimTracker/
│  ├─ Shared/                   # App Group + goals widget snapshot
│  ├─ SwimTrackerApp.swift      # @main
│  ├─ Models.swift              # models, scoring, persistent Store
│  └─ …                         # tab and feature views
└─ SwimTrackerWidget/           # Home Screen Goals widget
```

## Build & run (first time)

1. Open **`SwimTracker.xcodeproj`** in Xcode.
2. **SwimTracker** target → **Signing & Capabilities**:
   - **Automatically manage signing**, set **Team**.
   - Unique **Bundle Identifier** (e.g. `com.<yourname>.swimtracker`).
   - **App Groups**: `group.<your-bundle-id>` (keep entitlements and
     `AppGroup.identifier` in sync).
   - Same for **SwimTrackerWidget** (`<app-bundle-id>.widget`).
3. Plug in the iPhone, select it, **⌘R**.
4. Trust the developer profile under **Settings → General → VPN & Device Management**.
5. Add the widget from the Home Screen **+** menu if you want it.

## Your data

Local JSON in the app Documents directory (meets, times, goals, settings). No
accounts or servers. Included in encrypted device backups; deleting the app
deletes the data.
