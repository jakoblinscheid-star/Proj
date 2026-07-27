# Proj — keep a personal iPhone app alive without AltStore

**New here?** Follow **[SETUP.md](SETUP.md)** for a zero-to-running walkthrough
(first Xcode install → configure re-sign → launchd).

Free Apple ID app signatures expire after **7 days**. This repo automates the
re-sign + reinstall using only native Apple tooling (`xcodebuild` + `devicectl`),
triggered by a `launchd` agent whenever you plug your iPhone into your Mac.

> **These scripts run on macOS.** This repo just happens to be authored on
> Windows — copy the `mac/` folder to your Mac (or clone the repo there) to use it.

## Files

| File | Purpose |
| --- | --- |
| `mac/ExportOptions.plist` | Development / automatic-signing options for `-exportArchive`. |
| `mac/resign_and_install.sh` | Archive → export `.ipa` → install to device, with a 5-day guard. |
| `mac/com.personal.appresign.watch.plist` | **Option A** — launchd agent that fires on device connect (`WatchPaths`). |
| `mac/com.personal.appresign.poll.plist` | **Option B** — launchd agent that polls on a timer (`StartInterval`). |

## Prerequisites

- Xcode 15+ with Command Line Tools (`xcrun devicectl` ships with it).
- Your app project opening cleanly in Xcode and signing with your free Apple ID.
- Your **Team ID** and your iPhone's **UDID**:

```bash
security find-identity -v -p codesigning   # Team ID is in the cert name
xcrun devicectl list devices               # "Identifier" column = UDID
```

## Step 1 — Confirm signing works manually (once)

Do this once in Xcode before automating, to prove the signing chain works:

1. Plug in your iPhone and trust the Mac.
2. Xcode → **Product → Archive**.
3. In the Organizer: **Distribute App → Development → Export**, using development
   (automatic) signing. You should get a `.ipa`.

## Step 2 — Configure the script

Edit the CONFIG block at the top of `mac/resign_and_install.sh`:

- `PROJECT` — absolute path to your `.xcodeproj` or `.xcworkspace` (pre-filled with
  `$HOME/Proj/TabTrackApp/TabTrack.xcodeproj`; fix the prefix to match where the repo
  lives on your Mac)
- `SCHEME` — your shared scheme name (pre-filled with `TabTrack`)
- `TEAM_ID` — your 10-char Team ID (also set it in `ExportOptions.plist`)
- `DEVICE_UDID` — your iPhone UDID (or leave `""` to auto-pick the first connected device)

> The app being signed here is the native **TabTrack** iOS app in
> [`TabTrackApp/`](TabTrackApp/). See its [README](TabTrackApp/README.md) for how to
> build and first-install it in Xcode (including setting a unique Bundle Identifier).

Then verify it end-to-end, bypassing the time guard:

```bash
chmod +x mac/resign_and_install.sh
./mac/resign_and_install.sh --force
tail -f "$HOME/Library/Application Support/appresign/appresign.log"
```

If the app reinstalls on your phone, you're ready to automate.

## Step 3 — Install the launchd agent

Pick **one** option. Edit the placeholder script path inside the chosen plist first,
then:

```bash
# Option A (preferred): fire on device connect
cp mac/com.personal.appresign.watch.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.personal.appresign.watch.plist

# — or —

# Option B (fallback): poll every 30s
cp mac/com.personal.appresign.poll.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.personal.appresign.poll.plist
```

To update or remove:

```bash
launchctl unload ~/Library/LaunchAgents/com.personal.appresign.watch.plist
```

## How the 5-day guard works

`resign_and_install.sh` writes an epoch timestamp to
`~/Library/Application Support/appresign/last_success.epoch` after each successful
install. On every trigger it exits immediately unless that timestamp is
`MIN_DAYS_BETWEEN_RUNS` (default 5) days old. So plugging in for charging/sync
won't cause needless rebuilds, but a real re-sign happens comfortably inside the
7-day window.

## Gotchas

- **`method` value**: Xcode 15.3+ may prefer `debugging` over `development` in
  `ExportOptions.plist`. Swap it if export warns/fails.
- **Full Disk Access**: reading `/var/db/lockdown` (Option A) may require granting
  Full Disk Access to whatever runs the agent. If Option A never fires, use Option B.
- **First launch on device**: the very first install of a new signing identity may
  need you to trust the developer under Settings → General → VPN & Device Management.
- **Logs**: script log lives in `~/Library/Application Support/appresign/appresign.log`;
  launchd stdout/stderr go to `/tmp/appresign.{out,err}.log`.
