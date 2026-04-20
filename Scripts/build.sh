#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="EMLViewer"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DERIVED="$PROJECT_ROOT/.build/xcode"

CONFIG_INPUT="${1:-debug}"
shift || true
case "$CONFIG_INPUT" in
    debug|Debug) CONFIG="Debug" ;;
    release|Release) CONFIG="Release" ;;
    *) echo "error: unknown config '$CONFIG_INPUT' (expected debug|release)" >&2; exit 1 ;;
esac

OPEN_AFTER=0
for arg in "$@"; do
    case "$arg" in
        --open) OPEN_AFTER=1 ;;
        *) echo "error: unknown flag '$arg'" >&2; exit 1 ;;
    esac
done

if [ ! -d "$APP_NAME.xcodeproj" ]; then
    echo "error: $APP_NAME.xcodeproj missing (it is the source of truth, committed to the repo)" >&2; exit 1
fi

echo "==> xcodebuild ($CONFIG)"
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIG" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_STYLE=- \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build >/dev/null

BUILT_APP="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "error: build output missing at $BUILT_APP" >&2; exit 1
fi

echo "==> Copying to $APP_BUNDLE"
mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE"
cp -R "$BUILT_APP" "$APP_BUNDLE"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - \
    --entitlements "Resources/EMLViewer-Dev.entitlements" \
    "$APP_BUNDLE" 2>/dev/null

echo "==> Registering with LaunchServices"
touch "$APP_BUNDLE"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREG" ]; then
    "$LSREG" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

if [ "$OPEN_AFTER" = "1" ]; then
    pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    sleep 0.3
    open "$APP_BUNDLE"
    echo "Opened $APP_BUNDLE"
else
    echo ""
    echo "Done. Bundle: $APP_BUNDLE"
    echo "Open:    open \"$APP_BUNDLE\""
fi
