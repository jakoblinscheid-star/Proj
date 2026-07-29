# SwimTracker — native iOS app

Personal on-device tracker for swim times, meets, World Aquatics scores, and
goals. Built with SwiftUI for iOS 17+.

For the full product overview (scoring model, features, privacy, and how this
repo fits together), see the [root README](../README.md). For Mac install and
free Apple ID re-signing, see [SETUP.md](../SETUP.md).

## Tabs

| Tab | What it does |
| --- | --- |
| **Home** | Upcoming meet countdown, stroke radar (overall per stroke), recent meets |
| **Times** | Best time + points per event; history, splits, progression; Goals |
| **Meets** | Meet log (name, team, location, dates, course); individual + relay results |
| **Score** | Weighted overall, top events, by-team scores, year/season charts, Calc |
| **Convert** | SCY ↔ SCM ↔ LCM (Colorado Timing / SwimSwam-style factors) |

## Scoring (quick reference)

```text
P = 1000 × (base ÷ time)³
```

Bases: World Aquatics for SCM/LCM, U.S. Open for SCY. Overall = top four
individual events at **40% / 40% / 15% / 5%** (renormalized if fewer), including
opening splits extracted from longer races. Season view is Aug–Jul.

## Project layout

```text
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
2. **SwimTracker** → **Signing & Capabilities**: automatic signing, your Team,
   unique Bundle ID, App Group `group.<your-bundle-id>` (sync entitlements and
   `AppGroup.identifier`).
3. Same signing / App Groups for **SwimTrackerWidget**.
4. Run on a physical iPhone (**⌘R**), then trust the developer profile under
   **Settings → General → VPN & Device Management**.
5. Optionally add the Goals widget from the Home Screen **+** menu.

## Your data

Local JSON in Documents (meets, times, goals, settings, base-time overrides).
No accounts or servers. Export/import from Settings. Included in encrypted
device backups; deleting the app deletes the data.
