#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIG="${1:-debug}"
APP_NAME="EMLViewer"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG" --product "$APP_NAME"
swift build -c "$CONFIG" --product emlcheck

echo "==> Assembling .app bundle"
bash Scripts/make-app.sh "$CONFIG"

echo "==> Restart"
pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 0.4
open "dist/$APP_NAME.app"
echo "$APP_NAME started."
