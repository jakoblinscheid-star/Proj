#!/bin/bash
#
# resign_and_install.sh
#
# Re-signs and reinstalls a personal iOS app so a free Apple ID's 7-day
# signature never lapses. Meant to be triggered by a launchd agent when you
# plug your iPhone into the Mac (see the *.plist files in this folder).
#
# What it does:
#   1. Bails out early unless it's been >= MIN_DAYS_BETWEEN_RUNS since the last
#      successful install (debounce, so casual plug-ins don't rebuild).
#   2. Confirms your iPhone is actually connected.
#   3. Archives the app fresh (which mints a new automatic signing profile).
#   4. Exports a development-signed .ipa via ExportOptions.plist.
#   5. Installs it onto the device with `devicectl`.
#   6. Records a success timestamp for the debounce guard.
#
# Requires: Xcode 15+ (for `xcrun devicectl`) and command line tools.
# Run `./resign_and_install.sh --force` to bypass the time guard for testing.

set -u -o pipefail

# ---------------------------------------------------------------------------
# CONFIG - edit these for your project
# ---------------------------------------------------------------------------

# Absolute path to your .xcodeproj OR .xcworkspace (the script auto-detects which).
# Points at the native TabTrack app in this repo. Adjust the prefix to wherever
# you cloned/copied the repo on your Mac.
PROJECT="$HOME/Proj/TabTrackApp/TabTrack.xcodeproj"

# The scheme to build (Xcode > Product > Scheme > Manage Schemes; must be "Shared").
SCHEME="TabTrack"

# 10-character Apple Development Team ID (must match ExportOptions.plist).
TEAM_ID="REPLACE_WITH_TEAM_ID"

# Your iPhone's device identifier (UDID).
# Find it: `xcrun devicectl list devices`  (the "Identifier" column)
# or in Xcode > Window > Devices and Simulators.
# Leave empty ("") to auto-target the first connected iPhone.
DEVICE_UDID=""

# Build configuration to archive.
CONFIGURATION="Release"

# Only do the full export+install if at least this many days have passed
# since the last successful run.
MIN_DAYS_BETWEEN_RUNS=5

# Where build artifacts, logs, and the timestamp guard live.
WORK_DIR="$HOME/Library/Application Support/appresign"

# ---------------------------------------------------------------------------
# Nothing below here should need editing.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"

ARCHIVE_PATH="$WORK_DIR/build/TabTrack.xcarchive"
EXPORT_DIR="$WORK_DIR/build/export"
LOG_FILE="$WORK_DIR/appresign.log"
STAMP_FILE="$WORK_DIR/last_success.epoch"

mkdir -p "$WORK_DIR/build"

log() {
	printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

fail() {
	log "ERROR: $*"
	exit 1
}

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

log "=== run start (force=$FORCE) ==="

# --- 1. Time guard --------------------------------------------------------
if [ "$FORCE" -eq 0 ] && [ -f "$STAMP_FILE" ]; then
	last=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
	now=$(date +%s)
	age_days=$(( (now - last) / 86400 ))
	if [ "$age_days" -lt "$MIN_DAYS_BETWEEN_RUNS" ]; then
		log "Last success was ${age_days}d ago (< ${MIN_DAYS_BETWEEN_RUNS}d). Skipping."
		exit 0
	fi
	log "Last success was ${age_days}d ago (>= ${MIN_DAYS_BETWEEN_RUNS}d). Proceeding."
else
	log "No prior success recorded (or --force). Proceeding."
fi

# --- 2. Confirm the device is connected -----------------------------------
devices="$(xcrun devicectl list devices 2>/dev/null || true)"

if [ -n "$DEVICE_UDID" ]; then
	if ! grep -qi "$DEVICE_UDID" <<<"$devices"; then
		log "Configured device ($DEVICE_UDID) not connected. Skipping."
		exit 0
	fi
else
	# Auto-detect: grab the first UDID-looking identifier from the table.
	DEVICE_UDID="$(grep -oiE '[0-9A-F]{8}-[0-9A-F]{16}|[0-9A-F]{40}' <<<"$devices" | head -n1)"
	if [ -z "$DEVICE_UDID" ]; then
		log "No connected device found. Skipping."
		exit 0
	fi
	log "Auto-selected device: $DEVICE_UDID"
fi

# --- 3. Archive fresh (mints a new signing profile) -----------------------
if [[ "$PROJECT" == *.xcworkspace ]]; then
	PROJ_FLAG=(-workspace "$PROJECT")
else
	PROJ_FLAG=(-project "$PROJECT")
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

log "Archiving..."
xcodebuild archive \
	"${PROJ_FLAG[@]}" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-archivePath "$ARCHIVE_PATH" \
	-destination "generic/platform=iOS" \
	-allowProvisioningUpdates \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	CODE_SIGN_STYLE=Automatic \
	>>"$LOG_FILE" 2>&1 || fail "xcodebuild archive failed (see log)."

# --- 4. Export a development-signed .ipa -----------------------------------
log "Exporting .ipa..."
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS" \
	-exportPath "$EXPORT_DIR" \
	-allowProvisioningUpdates \
	>>"$LOG_FILE" 2>&1 || fail "xcodebuild -exportArchive failed (see log)."

IPA="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -n1)"
[ -n "$IPA" ] || fail "No .ipa produced in $EXPORT_DIR."
log "Built: $IPA"

# --- 5. Install onto the device -------------------------------------------
log "Installing to device $DEVICE_UDID..."
xcrun devicectl device install app \
	--device "$DEVICE_UDID" \
	"$IPA" \
	>>"$LOG_FILE" 2>&1 || fail "devicectl install failed (see log)."

# --- 6. Record success -----------------------------------------------------
date +%s >"$STAMP_FILE"
log "SUCCESS. Signature refreshed and app reinstalled."
log "=== run end ==="
