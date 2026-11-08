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
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -LensirNoSplash "$@" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$OUT/$file" >/dev/null 2>&1
  echo "wrote $OUT/$file"
}

mkdir -p "$OUT" "$OUT/ax5"

# Every screen, once per appearance: dark as <name>.png, light as <name>-light.png.
screens() { # suffix
  local x=$1
  shot looking$x.png -LensirDemo looking
  shot found$x.png -LensirDemo found
  shot safe-link$x.png -LensirDemo safe
  shot safe-expanded$x.png -LensirDemo safe-expanded
  shot lookalike$x.png -LensirDemo risky
  shot lookalike-expanded$x.png -LensirDemo risky-expanded
  shot short-link$x.png -LensirDemo http
  shot wifi$x.png -LensirDemo wifi
  shot wifi-expanded$x.png -LensirDemo wifi-expanded
  shot contact$x.png -LensirDemo contact
  shot contact-expanded$x.png -LensirDemo contact-expanded
  shot phone$x.png -LensirDemo phone
  shot text$x.png -LensirDemo text
  shot photo-codes$x.png -LensirDemo photos
  shot history$x.png -LensirDemo looking -LensirOpenHistory
  shot history-empty$x.png -LensirDemo looking -LensirOpenHistory -LensirEmptyHistory
  shot make-link$x.png -LensirDemo make-link
  shot make-wifi$x.png -LensirDemo make-wifi
  shot make-risky$x.png -LensirDemo make-risky
  shot make-show$x.png -LensirDemo make-show
  shot my-codes-empty$x.png -LensirDemo looking -LensirOpenHistory -LensirEmptyCodes
  shot camera-denied$x.png -LensirCameraDenied
  shot no-camera$x.png -LensirNoCamera
}

xcrun simctl ui "$UDID" appearance dark
screens ""

# The largest accessibility text size, for Make and My codes.
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
shot ax5/make-wifi.png -LensirDemo make-wifi
shot ax5/make-risky.png -LensirDemo make-risky
shot ax5/make-show.png -LensirDemo make-show
shot ax5/history.png -LensirDemo looking -LensirOpenHistory
shot ax5/my-codes-empty.png -LensirDemo looking -LensirOpenHistory -LensirEmptyHistory
# Domains wrap at a dot at this size, with the lookalike underline intact.
shot ax5/lookalike.png -LensirDemo risky
xcrun simctl ui "$UDID" content_size large

xcrun simctl ui "$UDID" appearance light
screens -light
# Light at AX5 and with Increase Contrast, for the result drawer and History.
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
shot ax5/lookalike-light.png -LensirDemo risky
shot ax5/history-light.png -LensirDemo looking -LensirOpenHistory
xcrun simctl ui "$UDID" content_size large
xcrun simctl ui "$UDID" increase_contrast enabled
shot contrast-lookalike-light.png -LensirDemo risky
shot contrast-safe-expanded-light.png -LensirDemo safe-expanded
shot contrast-history-light.png -LensirDemo looking -LensirOpenHistory
xcrun simctl ui "$UDID" increase_contrast disabled
xcrun simctl ui "$UDID" appearance dark

xcrun simctl status_bar "$UDID" clear
