# SwimTracker

A personal swim tracker for iPhone — native SwiftUI, on-device only. Log meets and
times, track World Aquatics scores, set goals, and convert between courses.

## Tabs

- **Home** — upcoming meet countdown, a radar chart of overall score by stroke,
  and recent meets.
- **Times** — best time per event with swim scores. Sort by score or event; open
  an event for full history, splits, and a progression graph. Goals live here too
  (all-time and meet targets), with an optional Home Screen widget.
- **Meets** — meets you’ve competed in (name, team, location, date), plus the
  individual and relay events you swam. Times can be entered up front or filled
  in later; individual results flow into Times automatically.
- **Score** — weighted overall swim score (best events), top contributing events,
  per-team breakdowns, and a progression chart (by **year** or by **season** /
  month, resetting each August). Includes a calculator for time ↔ points.
- **Convert** — SCY ↔ SCM ↔ LCM conversions using Colorado Timing factors.

## Scoring

Individual times use the World Aquatics point formula:

`P = 1000 × (base ÷ time)³`

Base (“1000-point”) times are World Aquatics bases for SCM/LCM and U.S. Open
records for SCY (men and women). Gender for scoring is chosen in Settings; base
times are editable in the app.

**Overall score** is a Swimcloud-style weighted average of your best four
individual events: **40% / 40% / 15% / 5%** (renormalized when you have fewer).
The Home radar uses the same formula scoped to each stroke. The Score chart’s
year view uses only that year’s swims; the season view is month-by-month
season-to-date from August.

## Requirements

- Mac with **Xcode 15+** (iOS 17 SDK)
- Free **Apple ID** added in Xcode (Settings → Accounts)
- iPhone on **iOS 17+**, connected via USB and trusted

## Build & run

1. Open `SwimTracker/SwimTracker.xcodeproj` in Xcode.
2. Select the **SwimTracker** target → **Signing & Capabilities**:
   - Enable **Automatically manage signing** and pick your Team.
   - Set a unique **Bundle Identifier** (e.g. `com.<yourname>.swimtracker`).
   - Under **App Groups**, use a matching `group.<your-bundle-id>` (update both
     entitlements and `AppGroup.identifier` if you change it).
   - Repeat signing / App Groups for **SwimTrackerWidget**
     (`<app-bundle-id>.widget`).
3. Choose your iPhone as the run destination and press **⌘R**.
4. On first launch: **Settings → General → VPN & Device Management** → trust
   your developer profile.
5. Optional widget: long-press the Home Screen → **+** → SwimTracker / Goals.

More detail lives in [`SwimTracker/README.md`](SwimTracker/README.md).

## Project layout

```
Proj/
├─ SwimTracker/
│  ├─ SwimTracker.xcodeproj/
│  ├─ SwimTracker/              # app sources (models, tabs, scoring, store)
│  │  └─ Shared/                # App Group + goals widget snapshot
│  └─ SwimTrackerWidget/        # Home Screen Goals widget (WidgetKit)
└─ .github/workflows/           # optional unsigned CI build
```

## Your data

Everything stays on device (JSON in the app’s Documents directory) — no accounts
or servers. Meets, times, goals, and settings are included in encrypted device
backups. Deleting the app deletes the data.
