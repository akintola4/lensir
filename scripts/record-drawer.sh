#!/bin/zsh
# Records the drawer's drags in the Simulator so you can watch how it feels.
#
#   scripts/record-drawer.sh after            build, then record each drag
#   scripts/record-drawer.sh --no-build after record the build that's already there
#
# SIM=<udid> picks the simulator (default: the first iPhone 17 Pro). Each
# drag in DrawerFeelUITests is recorded on its own, at normal speed and 4x
# slow, into ~/Movies/Lensir drawer/ as <time>-<name>-<drag>.mp4 and
# <time>-<name>-<drag>-slow-4x.mp4. Every video starts with the app
# launching; the drag is the last few seconds.
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED=build/DerivedData
OUT="$HOME/Movies/Lensir drawer"
mkdir -p "$OUT"

BUILD=1
if [[ "${1:-}" == "--no-build" ]]; then BUILD=0; shift; fi
NAME=${1:-drawer}

SIM=${SIM:-$(xcrun simctl list devices available | grep -E "^ +iPhone 17 Pro \(" | head -1 | grep -oE '[0-9A-F-]{36}')}
xcrun simctl boot "$SIM" 2>/dev/null || true
DEST="id=$SIM"

if (( BUILD )); then
  xcodebuild build-for-testing -scheme Lensir -destination "$DEST" -derivedDataPath "$DERIVED" -quiet
fi
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

STAMP=$(date +%H%M%S)
record() { # drag name, test name
  local drag=$1 test=$2
  local raw="$OUT/.raw.mov" file="$OUT/$STAMP-$NAME-$drag.mp4"
  xcrun simctl io "$SIM" recordVideo --codec h264 --force "$raw" >/dev/null 2>&1 &
  local rec=$!
  sleep 1.5
  xcodebuild test-without-building -scheme Lensir -destination "$DEST" -derivedDataPath "$DERIVED" \
    -only-testing:"LensirUITests/DrawerFeelUITests/$test" -quiet >/dev/null 2>&1 || echo "  ($test failed)" >&2
  sleep 1
  kill -INT $rec; wait $rec 2>/dev/null || true
  # Keep it small and playable anywhere.
  ffmpeg -loglevel error -y -i "$raw" -vf "scale=-2:1280" -c:v libx264 -pix_fmt yuv420p "$file"
  ffmpeg -loglevel error -y -i "$raw" -vf "setpts=4*PTS,scale=-2:1280" -r 60 -an -c:v libx264 -pix_fmt yuv420p "${file%.mp4}-slow-4x.mp4"
  rm -f "$raw"
  echo "$file"
}

record flick testFastFlickDismisses
record slow-past-half testSlowDragPastHalfDismisses
record snap-back testSlowShortDragSnapsBack
record rubber-band testPullPastTopRubberBandsBack
record catch testCatchWhileClosing
xcrun simctl status_bar "$SIM" clear
