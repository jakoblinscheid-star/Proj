# SwimTracker

A personal swimming performance tracker for iPhone. Built with SwiftUI, fully
on-device — no accounts, no cloud sync, no analytics.

SwimTracker is for competitive swimmers who want one place to log meet results,
watch best times improve, score performances the way World Aquatics does, and
set goals they can see on the Home Screen. It is not a team management tool or a
workout planner; it is a private logbook and scoreboard for *your* swimming.

## Why it exists

Swimming results live in heat sheets, TeamUnify/Swimcloud exports, stopwatch
notes, and memory. This app pulls that into a single local store:

- Every swim is an **event** (distance + stroke + course) with an optional time,
  splits, meet link, and notes.
- Every performance can be turned into **World Aquatics points**, so a 100 Free
  and a 200 Breast can be compared on the same scale.
- An **overall score** (Swimcloud-style weighted average of your best events)
  summarizes how strong your book of times is — by stroke, by team, by year, or
  by season.

Everything stays on the phone as JSON. Export a backup when you want a copy;
delete the app and the data goes with it.

## What you can do

### Log meets and times

- Create meets with name, team/club, location, date range, course (SCY / SCM /
  LCM), and an optional prelims/finals flag.
- Add **individual** and **relay** events at create time or later. Times can be
  blank until you have official results.
- Relays track leg number, leg stroke (for medley), personal leg split, and
  lead-off status. Relays stay meet-scoped; individual results feed the Times
  tab automatically.
- Enter times with scoreboard-style digit wheels; record 50-interval splits on
  longer races.
- Tag prelims vs finals when the meet uses that format.

### Track best times and progression

- The **Times** tab shows your best time per event with swim scores. Sort by
  score or by event order.
- Open an event for full history, PR markers, progression charts, and splits.
- **Opening splits** from longer races are extracted Swimcloud-style (e.g. first
  50 of a 100 Free counts toward 50 Free; first 50 of a 200 IM counts toward
  50 Fly). Mid-race flying splits are not used. Extracted performances are
  derived from the parent swim, not stored twice.

### Score yourself

Individual times use the World Aquatics formula:

```text
P = 1000 × (base ÷ time)³
```

- **SCM / LCM** bases are World Aquatics 1000-point times (world records).
- **SCY** bases are U.S. Open records (yards have no WA table).
- Gender for scoring badges and “Your Score” is set in Settings; the Calc tool
  can still score either gender. Bases are editable on device under Base Times.

**Overall score** = weighted average of your best four *individual* events
(including extracted opening splits):

| Rank | Weight |
| --- | --- |
| 1st best | 40% |
| 2nd best | 40% |
| 3rd best | 15% |
| 4th best | 5% |

Weights renormalize when you have fewer than four scored events. Relays never
count toward overall.

The Score tab also shows:

- Top contributing events and their share of the overall
- Per-team breakdowns (meets with no team name group as “Unattached”)
- Progression by **calendar year** or by **season** (August–July), month by month
- A calculator for time ↔ points on any event

The Home radar chart uses the same overall formula, scoped to each stroke.

### Set goals (and pin them to the Home Screen)

- Per-event **all-time** goals (vs overall best) and **meet** goals (vs best in
  the current Aug–Jul season).
- Optional **Goals** widget (small / medium / large) via App Group shared data.

### Convert courses

Convert SCY ↔ SCM ↔ LCM with Colorado Timing factors (same model as SwimSwam’s
classic converter), including yard/meter distance pairs like 400/500 Free.

### Back up and restore

Settings can export a JSON backup of meets, times, goals, base-time overrides,
and settings — and import one to replace everything on the device.

## App map

| Tab | Role |
| --- | --- |
| **Home** | Upcoming meet countdown, stroke radar, recent meets; Settings |
| **Times** | Best times + scores; event detail; Goals |
| **Meets** | Meet list and detail; add/edit results and relays |
| **Score** | Overall, team filters, progression, Calc, Base Times |
| **Convert** | Course conversion |

## Privacy & data

| | |
| --- | --- |
| Storage | Local JSON in the app Documents directory |
| Accounts / servers | None |
| Widget | App Group snapshot only (goals progress) |
| Device backups | Included in encrypted iPhone backups |
| Uninstall | Deletes all local data |

## Requirements

- Mac with **Xcode 15+** (iOS 17 SDK)
- Free **Apple ID** added in Xcode (Settings → Accounts)
- iPhone on **iOS 17+**, USB-connected and trusted

## Build & run

1. Open `SwimTracker/SwimTracker.xcodeproj` in Xcode.
2. Select the **SwimTracker** target → **Signing & Capabilities**:
   - Enable **Automatically manage signing** and pick your Team.
   - Set a unique **Bundle Identifier** (e.g. `com.<yourname>.swimtracker`).
   - Under **App Groups**, use a matching `group.<your-bundle-id>` (keep both
     entitlements files and `AppGroup.identifier` in sync).
   - Repeat signing / App Groups for **SwimTrackerWidget**
     (`<app-bundle-id>.widget`).
3. Choose your iPhone as the run destination and press **⌘R**.
4. On first launch: **Settings → General → VPN & Device Management** → trust
   your developer profile.
5. Optional widget: long-press the Home Screen → **+** → SwimTracker / Goals.

Step-by-step free-Apple-ID install, 7-day re-signing automation (`mac/`), and
troubleshooting: see **[SETUP.md](SETUP.md)**.

CI can produce an unsigned `.ipa` via [`.github/workflows/build.yml`](.github/workflows/build.yml)
for sideloading tools such as AltStore (see `instructions.txt`).

## Project layout

```text
Proj/
├─ README.md                 # this overview
├─ SETUP.md                  # Mac install + free-ID re-sign automation
├─ SwimTracker/
│  ├─ SwimTracker.xcodeproj/
│  ├─ README.md              # app-focused notes
│  ├─ SwimTracker/           # SwiftUI app (models, tabs, scoring, store)
│  │  └─ Shared/             # App Group + goals widget snapshot
│  └─ SwimTrackerWidget/     # Home Screen Goals widget (WidgetKit)
├─ mac/                      # optional launchd re-sign / reinstall scripts
└─ .github/workflows/        # optional unsigned CI build
```

App-specific layout and first-run notes also live in
[`SwimTracker/README.md`](SwimTracker/README.md).
