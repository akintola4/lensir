#!/usr/bin/env bash
# Renders the Lock Screen widget screenshots in docs/screenshots/widgets/.
#
#   scripts/widget-screenshots.sh [simulator name]     # default: iPhone 17 Pro
#
# The Simulator can't add a widget without tapping, so a test
# (LensirTests/WidgetScreenshots.swift) draws the real widget views with
# ImageRenderer onto a stand-in Lock Screen. It's skipped in normal test
# runs; LENSIR_WIDGET_SHOTS turns it on.
set -euo pipefail

cd "$(dirname "$0")/.."
NAME="${1:-iPhone 17 Pro}"
UDID=$(xcrun simctl list devices available | grep -F "$NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')

TEST_RUNNER_LENSIR_WIDGET_SHOTS=1 xcodebuild test -scheme Lensir \
  -destination "id=$UDID" \
  -derivedDataPath build/DerivedData \
  -only-testing:LensirTests/WidgetScreenshots -quiet
ls docs/screenshots/widgets
