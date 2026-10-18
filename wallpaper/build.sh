#!/bin/sh
# Builds Starlake.heic, a macOS dynamic wallpaper that follows the clock.
# Usage: wallpaper/build.sh [seed]
# Needs Chrome or Chromium; set CHROME to its binary if it isn't in /Applications.
set -e
cd "$(dirname "$0")"
SEED=${1:-616471928}
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
[ -x "$CHROME" ] || { echo "Chrome not found at $CHROME; set CHROME to its binary" >&2; exit 1; }
# One frame per sky phase in index.html's KEYS, plus extras where the light changes fastest.
HOURS="1 5.6 6 6.4 7.8 10 12.5 16.4 17.3 18.1 18.6 19 19.9 22"

rm -rf frames && mkdir frames
for h in $HOURS; do
  # 6016x3384 is the largest Mac display; 5 s of virtual time lets the startup title and HUD fade out.
  "$CHROME" --headless --hide-scrollbars --window-size=6016,3384 --virtual-time-budget=5000 \
    --screenshot="frames/$h.png" "file://$PWD/frame.html#seed=$SEED&t=$h&paused=1&moon=0.45" 2>/dev/null
done
swift make-heic.swift Starlake.heic 12.5 22 frames/*.png
