#!/bin/bash
set -euo pipefail

APP_NAME="EMLViewer"
CONFIG="${1:-release}"
BUILD_DIR=".build/${CONFIG}"
DIST_DIR="dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> Building $CONFIG binary"
swift build -c "$CONFIG" --product "$APP_NAME"

echo "==> Assembling bundle: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "==> Generating AppIcon.icns"
    bash Scripts/make-icon.sh
fi
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

for bundle in "$BUILD_DIR"/*_*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
done

echo "==> Ad-hoc signing"
codesign --force --deep --sign - \
    --entitlements "Resources/EMLViewer.entitlements" \
    "$APP_BUNDLE"

echo "==> Registering with LaunchServices"
touch "$APP_BUNDLE"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREG" ]; then
    "$LSREG" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo ""
echo "Done. Bundle: $APP_BUNDLE"
echo "Open:    open \"$APP_BUNDLE\""
echo "Install: make install"
