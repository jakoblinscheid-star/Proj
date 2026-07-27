# SwimTracker — native iOS app

A personal tracker for your swim times, built as a native SwiftUI app. Four tabs:

- **Home** — your most recent meets at a glance.
- **Times** — your best time in every event, with an automatic swim score. Sort by
  swim score or by event; tap an event to see all your times and a progression graph.
- **Meets** — the meets you've competed in, the team you swam for, and the events
  you swam there (individual + relays), with times you can add now or fill in later.
- **Score** — scoring *(details TBD)*.

### Meets

Creating a meet captures its name, the **team you're swimming under**, location, and
date. You can add the **events you swam** — individual events *and* relays — right
then, or open the meet later and add them. Each event can have a time now or be left
blank and filled in afterward. Individual events recorded at a meet flow into the
**Times** tab automatically (linked back to the meet); relays are tracked per-meet.

### Times & swim score

Times are organized by **event** — a distance + stroke in a specific **course**
(SCY yards, SCM meters, LCM meters), tracked separately since each course has its
own records. The list shows only your **best** time per event; tapping an event
opens all of its times plus a progression chart.

Each time gets a **swim score** using the World Aquatics ("FINA") point formula
`P = 1000 × (base ÷ time)³`. The base ("1000-point") times are baked in:
World Aquatics world-record base times for **SCM/LCM** and **U.S. Open records**
for **SCY**, for both men and women (toggle whose base times to use from the
person icon in the Times tab). Update the values in `BaseTimes` (in `Models.swift`)
whenever new records are set.

All data stays on device (saved as JSON in the app's Documents directory) — no
accounts, no servers. Sibling to the [`TabTrackApp`](../TabTrackApp) project and
built the same way: authored on Windows, compiled and sideloaded from a Mac using
the auto-resign toolchain in the repo's [`mac/`](../mac) folder.

## Requirements

- A **Mac** with **Xcode 15 or newer** (iOS 17 SDK).
- A free **Apple ID** added to Xcode (Settings → Accounts).
- An iPhone running **iOS 17+**, connected via USB and trusted.

> Xcode only runs on macOS. This project is authored on Windows; copy/clone the repo
> to your Mac to build it.

## Project layout

```
SwimTracker/
├─ SwimTracker.xcodeproj/       # the Xcode project (shared "SwimTracker" scheme)
└─ SwimTracker/
   ├─ SwimTrackerApp.swift      # @main app entry point
   ├─ Models.swift              # Meet/SwimTime models, scoring + base times, persistent Store
   ├─ Theme.swift               # colors + date/time helpers
   ├─ ContentView.swift         # root TabView (Home / Times / Meets / Score)
   ├─ HomeView.swift            # recent meets
   ├─ TimesView.swift           # Times tab: best times, swim score, event detail + graph
   ├─ MeetsView.swift           # meets list, meet detail, events swam (individual + relay), team
   ├─ ScoreView.swift           # Score tab (placeholder)
   └─ Assets.xcassets           # AppIcon (placeholder) + AccentColor
```

## Build & run on your phone (first time)

1. On your Mac, open **`SwimTracker/SwimTracker.xcodeproj`** in Xcode.
2. Select the **SwimTracker** target → **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Set **Team** to your Apple ID (free personal team is fine).
   - Change the **Bundle Identifier** from `com.yourname.swimtracker` to something
     unique to you (e.g. `com.<yourname>.swimtracker`).
3. Plug in your iPhone and pick it as the run destination (top toolbar).
4. Press **⌘R** to build & run. The app installs on your phone.
5. First launch: on the iPhone go to **Settings → General → VPN & Device Management**,
   tap your developer profile, and **Trust** it. Reopen the app.

## Keeping it alive past 7 days

Free Apple ID signatures expire after 7 days. To auto re-sign, point the scripts in
[`mac/`](../mac) at this project (`PROJECT=".../SwimTracker/SwimTracker.xcodeproj"`,
`SCHEME="SwimTracker"`) and follow the steps in the [root README](../README.md).

## Your data

Everything is stored locally inside the app's Documents directory: meets in
`swimtracker.v1.json` and your recorded times (plus the chosen gender) in
`swimtracker.times.v1.json`. It stays on the device and is included in encrypted
device backups. Deleting the app deletes the data.

## Status

Home, Meets, and **Times** are functional. **Score** is a clean placeholder,
waiting on its per-tab design.
