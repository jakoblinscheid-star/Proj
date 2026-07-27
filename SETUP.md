# Setup — get this running on your iPhone

This repo has two pieces:

1. **The apps** — native SwiftUI iOS apps (`TabTrackApp/`, `SwimTracker/`) you build in Xcode.
2. **The re-sign toolchain** — `mac/` scripts that re-archive and reinstall every ~5 days so a free Apple ID’s **7-day** signature never expires.

You need a **Mac**. The apps will not build on Windows. Clone or copy this repo onto the Mac and do everything below there.

---

## What you need

| Requirement | Notes |
| --- | --- |
| Mac with **Xcode 15+** | Install from the App Store, then open it once and accept the license. |
| Command Line Tools | Usually installed with Xcode. Confirm: `xcode-select -p` |
| Free **Apple ID** in Xcode | Xcode → Settings → Accounts → **+** → add your Apple ID |
| iPhone on **iOS 17+** | USB cable; unlock and tap **Trust** when prompted |

---

## Part A — First install of an app (do this once)

Pick one app. These instructions use **TabTrack**; SwimTracker is the same with different names (see the end of this section).

### 1. Open the project

```bash
# wherever you put the repo on the Mac, e.g.:
cd ~/Proj
open TabTrackApp/TabTrack.xcodeproj
```

### 2. Fix signing

In Xcode, select the **TabTrack** target → **Signing & Capabilities**:

1. Check **Automatically manage signing**.
2. Set **Team** to your Apple ID (Personal Team is fine).
3. Change **Bundle Identifier** from `com.yourname.tabtrack` to something unique, e.g. `com.yourname.tabtrack`.

Apple will reject a bundle ID someone else already registered under another team.

### 3. Run on your phone

1. Plug in the iPhone; unlock it; trust the Mac if asked.
2. In the Xcode toolbar, choose your **iPhone** as the run destination (not a simulator).
3. Press **⌘R** (Product → Run).

### 4. Trust the developer profile (first launch only)

On the iPhone:

**Settings → General → VPN & Device Management** → your Apple ID / developer entry → **Trust**.

Open the app again from the home screen. If it launches, Part A is done.

### SwimTracker instead (or as well)

Same steps, but:

- Open `SwimTracker/SwimTracker.xcodeproj`
- Target / scheme: **SwimTracker**
- Bundle ID example: `com.yourname.swimtracker`

The re-sign script below is pre-wired for **TabTrack**. To automate SwimTracker, change `PROJECT` and `SCHEME` in the script (Part B).

---

## Part B — Automate re-signing (so it doesn’t die after 7 days)

Do this on the Mac after Part A works.

### 1. Find your Team ID

```bash
security find-identity -v -p codesigning
```

Look for a line like `Apple Development: you@example.com (XXXXXXXXXX)`. The 10-character value in parentheses is your **Team ID**.

### 2. (Optional) Find your iPhone UDID

```bash
xcrun devicectl list devices
```

Use the **Identifier** column. You can leave UDID empty in the script to auto-pick the first connected iPhone.

### 3. Edit the script config

Open `mac/resign_and_install.sh` and set the CONFIG block at the top:

| Variable | What to put |
| --- | --- |
| `PROJECT` | Absolute path to the `.xcodeproj` on **this** Mac. Default assumes `$HOME/Proj/TabTrackApp/TabTrack.xcodeproj` — change the prefix if your clone isn’t at `~/Proj`. |
| `SCHEME` | `TabTrack` (or `SwimTracker`) |
| `TEAM_ID` | Your 10-character Team ID |
| `DEVICE_UDID` | Your UDID, or `""` for auto |

Also set the same Team ID in `mac/ExportOptions.plist`:

```xml
<key>teamID</key>
<string>YOUR_TEAM_ID_HERE</string>
```

### 4. Test a full re-sign by hand

```bash
cd ~/Proj   # or wherever the repo lives
chmod +x mac/resign_and_install.sh
./mac/resign_and_install.sh --force
```

`--force` skips the 5-day wait so you can verify once.

Watch the log:

```bash
tail -f "$HOME/Library/Application Support/appresign/appresign.log"
```

When it finishes without `ERROR`, the app on the phone should have a fresh signature. If export fails mentioning `method`, open `mac/ExportOptions.plist` and change `development` to `debugging` (Xcode 15.3+).

### 5. Install a launchd agent (pick one)

Edit the chosen plist first: replace  
`/Users/REPLACE_ME/path/to/mac/resign_and_install.sh`  
with the real absolute path, e.g. `/Users/you/Proj/mac/resign_and_install.sh`.

**Option A — fire when the phone plugs in (preferred)**

```bash
cp mac/com.personal.appresign.watch.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.personal.appresign.watch.plist
```

If this never runs, grant **Full Disk Access** to `bash` / Terminal / whatever launches it (System Settings → Privacy & Security), or use Option B. Option A watches `/var/db/lockdown`, which can be restricted.

**Option B — poll every 30 seconds (simpler fallback)**

```bash
cp mac/com.personal.appresign.poll.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.personal.appresign.poll.plist
```

Use **only one** of A or B.

### 6. Confirm the agent is loaded

```bash
launchctl list | grep appresign
```

You should see `com.personal.appresign.watch` or `com.personal.appresign.poll`.

Agent stdout/stderr:

- `/tmp/appresign.out.log`
- `/tmp/appresign.err.log`

Script log:

- `~/Library/Application Support/appresign/appresign.log`

---

## Day-to-day use

1. Leave the Mac on (or wake it) with the repo and Xcode tools available.
2. Plug the iPhone in about once every **5 days** (or leave Option B polling while the phone is connected).
3. The script rebuilds, exports, and reinstalls only if ≥5 days have passed since the last success — so casual charging won’t thrash rebuilds.
4. Free signatures last **7 days**; the 5-day guard keeps you inside that window.

To unload the agent later:

```bash
launchctl unload ~/Library/LaunchAgents/com.personal.appresign.watch.plist
# or
launchctl unload ~/Library/LaunchAgents/com.personal.appresign.poll.plist
```

---

## Quick checklist

- [ ] Repo on a Mac
- [ ] Xcode 15+ + Apple ID in Accounts
- [ ] App builds with ⌘R and launches after Trust
- [ ] Unique Bundle Identifier set
- [ ] `TEAM_ID` set in `resign_and_install.sh` **and** `ExportOptions.plist`
- [ ] `PROJECT` path matches this Mac
- [ ] `./mac/resign_and_install.sh --force` succeeds
- [ ] launchd plist path fixed and agent loaded
- [ ] `launchctl list | grep appresign` shows the agent

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Signing / provisioning errors in Xcode | Team selected? Bundle ID unique? Device trusted? |
| App won’t open on phone | Settings → General → VPN & Device Management → Trust |
| `xcrun: error: unable to find utility "devicectl"` | Install/open Xcode 15+; run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Export fails on `method` | In `ExportOptions.plist`, try `debugging` instead of `development` |
| Script says device not connected | Unlock phone, trust Mac, check `xcrun devicectl list devices` |
| Option A never fires | Use Option B, or grant Full Disk Access for lockdown watching |
| Script exits immediately with no install | Normal if last success was &lt;5 days ago; use `--force` to test |
| Wrong app gets rebuilt | Point `PROJECT` / `SCHEME` at SwimTracker or TabTrack as needed |

---

## More detail

- Re-sign design notes: [README.md](README.md)
- TabTrack app: [TabTrackApp/README.md](TabTrackApp/README.md)
- SwimTracker app: [SwimTracker/README.md](SwimTracker/README.md)
