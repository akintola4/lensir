#!/usr/bin/env bash
# Builds Lensir for the Simulator and takes the README screenshots in docs/screenshots/.
#
#   scripts/screenshots.sh [simulator name]     # default: iPhone 17 Pro
#
# The Simulator has no camera, so these use the Debug launch arguments
# (-LensirDemo, -LensirOpenHistory, -LensirCameraDenied, -LensirNoCamera),
# which draw a stand-in camera with a real QR code on it. No tapping needed.
set -euo pipefail

cd "$(dirname "$0")/.."
NAME="${1:-iPhone 17 Pro}"
UDID=$(xcrun simctl list devices available | grep -F "$NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')
OUT=docs/screenshots
DERIVED=build/DerivedData

xcrun simctl boot "$UDID" 2>/dev/null || true
xcodebuild build -scheme Lensir -destination "id=$UDID" -derivedDataPath "$DERIVED" -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Lensir.app"
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$UDID" "$APP"
# Answer the camera prompt up front so it never covers a screenshot.
xcrun simctl privacy "$UDID" grant camera "$BUNDLE"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() { # file, launch arguments...
  local file=$1; shift
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$OUT/$file" >/dev/null 2>&1
  echo "wrote $OUT/$file"
}

mkdir -p "$OUT"
shot looking.png -LensirDemo looking
shot found.png -LensirDemo found
shot safe-link.png -LensirDemo safe
shot safe-expanded.png -LensirDemo safe-expanded
shot lookalike.png -LensirDemo risky
shot lookalike-expanded.png -LensirDemo risky-expanded
shot short-link.png -LensirDemo http
shot wifi.png -LensirDemo wifi
shot wifi-expanded.png -LensirDemo wifi-expanded
shot contact.png -LensirDemo contact
shot contact-expanded.png -LensirDemo contact-expanded
shot phone.png -LensirDemo phone
shot text.png -LensirDemo text
shot photo-codes.png -LensirDemo photos
shot history.png -LensirDemo looking -LensirOpenHistory
shot history-empty.png -LensirDemo looking -LensirOpenHistory -LensirEmptyHistory
shot camera-denied.png -LensirCameraDenied
shot no-camera.png -LensirNoCamera

xcrun simctl status_bar "$UDID" clear
