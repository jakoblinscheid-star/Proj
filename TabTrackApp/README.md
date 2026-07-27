# TabTrack — native iOS app

A native SwiftUI rewrite of the TabTrack web app: keep tabs on who owes you what.
Each friend is a card with an itemized list of debts; tick items off as they pay you
back, and see a per-friend balance plus a grand total. All data stays on device
(saved as JSON in the app's Documents directory) — no accounts, no servers.

Built to be **sideloaded onto your own iPhone with a free Apple ID** using nothing
but Xcode. Pairs with the auto-resign toolchain in the repo's [`mac/`](../mac) folder
so the free-Apple-ID 7-day signature never lapses.

## Requirements

- A **Mac** with **Xcode 15 or newer** (iOS 17 SDK).
- A free **Apple ID** added to Xcode (Settings → Accounts).
- An iPhone running **iOS 17+**, connected via USB and trusted.

> Xcode only runs on macOS. This project is authored on Windows; copy/clone the repo
> to your Mac to build it.

## Project layout

```
TabTrackApp/
├─ TabTrack.xcodeproj/        # the Xcode project (shared "TabTrack" scheme)
└─ TabTrack/
   ├─ TabTrackApp.swift       # @main app entry point
   ├─ Models.swift            # Friend / DebtItem models + persistent Store
   ├─ Theme.swift             # colors, currency/date/avatar helpers
   ├─ ContentView.swift       # friends list, grand total, search, add
   ├─ FriendDetailView.swift  # a friend's items, mark-paid, add-item form
   ├─ FriendEditView.swift    # add/edit friend sheet
   └─ Assets.xcassets         # AppIcon (placeholder) + AccentColor
```

## Build & run on your phone (first time)

1. On your Mac, open **`TabTrackApp/TabTrack.xcodeproj`** in Xcode.
2. Select the **TabTrack** target → **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Set **Team** to your Apple ID (free personal team is fine).
   - Change the **Bundle Identifier** from `com.yourname.tabtrack` to something
     unique to you (e.g. `com.<yourname>.tabtrack`). This is required — Apple won't
     let two people sign the same bundle ID.
3. Plug in your iPhone and pick it as the run destination (top toolbar).
4. Press **⌘R** to build & run. The app installs on your phone.
5. First launch: on the iPhone go to **Settings → General → VPN & Device Management**,
   tap your developer profile, and **Trust** it. Reopen the app.

That's it — you now have TabTrack on your phone.

## Keeping it alive past 7 days (automate re-signing)

Free Apple ID signatures expire after 7 days. Instead of re-running Xcode by hand,
use the scripts in [`mac/`](../mac), which archive → export → reinstall automatically
whenever you plug in your phone. They're already pointed at this project:

- `PROJECT="$HOME/Proj/TabTrackApp/TabTrack.xcodeproj"` — adjust the path prefix to
  wherever the repo lives on your Mac.
- `SCHEME="TabTrack"` — the shared scheme in this project.

Then follow the steps in the [root README](../README.md): set your `TEAM_ID`
(and in `mac/ExportOptions.plist`), run `./mac/resign_and_install.sh --force` once to
verify, then install the `launchd` agent. **Important:** whatever bundle ID you chose
in step 2 above must match the identity the scripts sign with.

## Your data

Everything is stored locally in `tabtrack.v1.json` inside the app's Documents
directory. It stays on the device and is included in encrypted iTunes/Finder and
iCloud device backups. Deleting the app deletes the data.

## Notes

- App icon is a white dollar sign on the accent blue (`#2b7fff`), at
  `TabTrack/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- Minimum deployment target is **iOS 17.0** (uses the SwiftUI Observation framework
  and `ContentUnavailableView`).
