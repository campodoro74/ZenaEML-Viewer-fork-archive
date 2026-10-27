#!/bin/bash
set -euo pipefail

# Build outside iCloud-synced trees: extended attributes from CloudDocs break codesign.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="EMLViewer"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DERIVED="${EMLVIEWER_DERIVED_DATA:-/tmp/emlviewer-dd}"

CONFIG_INPUT="${1:-debug}"
shift || true
case "$CONFIG_INPUT" in
    debug|Debug) CONFIG="Debug" ;;
    release|Release) CONFIG="Release" ;;
    *) echo "error: unknown config '$CONFIG_INPUT' (expected debug|release)" >&2; exit 1 ;;
esac

OPEN_AFTER=0
SIGN_MODE="auto" # auto | adhoc | developer-id
for arg in "$@"; do
    case "$arg" in
        --open) OPEN_AFTER=1 ;;
        --adhoc) SIGN_MODE="adhoc" ;;
        --developer-id) SIGN_MODE="developer-id" ;;
        *) echo "error: unknown flag '$arg'" >&2; exit 1 ;;
    esac
done

if [ ! -d "$APP_NAME.xcodeproj" ]; then
    echo "error: $APP_NAME.xcodeproj missing" >&2; exit 1
fi

TEAM_ID="${DEVELOPMENT_TEAM:-P675R8Z5DF}"
IDENTITY_DEV_ID="${CODESIGN_IDENTITY:-Developer ID Application: Martijn Goudkamp (P675R8Z5DF)}"

echo "==> xcodebuild ($CONFIG) derivedData=$DERIVED"
EXTRA_SIGN=()
if [ "$SIGN_MODE" = "adhoc" ] || [ "$CONFIG" = "Debug" -a "$SIGN_MODE" = "auto" ]; then
    EXTRA_SIGN=(
        CODE_SIGN_STYLE=Automatic
        DEVELOPMENT_TEAM="$TEAM_ID"
    )
elif [ "$SIGN_MODE" = "developer-id" ] || [ "$CONFIG" = "Release" -a "$SIGN_MODE" = "auto" ]; then
    EXTRA_SIGN=(
        CODE_SIGN_STYLE=Manual
        CODE_SIGN_IDENTITY="$IDENTITY_DEV_ID"
        DEVELOPMENT_TEAM="$TEAM_ID"
        PROVISIONING_PROFILE_SPECIFIER=
    )
fi

xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" \
    "${EXTRA_SIGN[@]}" \
    build

BUILT_APP="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "error: build output missing at $BUILT_APP" >&2; exit 1
fi

echo "==> Copying to $APP_BUNDLE"
# Keep signed artifacts off iCloud-synced trees (CloudDocs xattrs break codesign).
if [[ "$DIST_DIR" == /* ]]; then
    ABS_DIST="$DIST_DIR"
else
    ABS_DIST="/tmp/emlviewer-dist"
fi
mkdir -p "$ABS_DIST" "$PROJECT_ROOT/dist"
rm -rf "$ABS_DIST/$APP_NAME.app" "$PROJECT_ROOT/dist/$APP_NAME.app"
# --norsrc/--noextattr avoid AppleDouble / Finder info that codesign rejects
ditto --norsrc --noextattr "$BUILT_APP" "$ABS_DIST/$APP_NAME.app"
xattr -cr "$ABS_DIST/$APP_NAME.app" 2>/dev/null || true
APP_BUNDLE="$ABS_DIST/$APP_NAME.app"

if [ "$SIGN_MODE" = "adhoc" ]; then
    echo "==> Ad-hoc signing"
    codesign --force --deep --sign - \
        --entitlements "Resources/EMLViewer-Dev.entitlements" \
        "$APP_BUNDLE"
elif [ "$CONFIG" = "Release" ] || [ "$SIGN_MODE" = "developer-id" ]; then
    echo "==> Developer ID signing (nested)"
    APPEX="$APP_BUNDLE/Contents/PlugIns/EMLViewerQuickLook.appex"
    if [ -d "$APPEX" ]; then
        xattr -cr "$APPEX" 2>/dev/null || true
        codesign --force --options runtime --timestamp \
            --sign "$IDENTITY_DEV_ID" \
            --entitlements "Resources/EMLViewerQuickLook.entitlements" \
            "$APPEX"
    fi
    codesign --force --options runtime --timestamp \
        --sign "$IDENTITY_DEV_ID" \
        --entitlements "Resources/EMLViewer-DeveloperID.entitlements" \
        "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

# Symlink into project dist/ for convenience (symlink target stays in /tmp)
ln -sfn "$APP_BUNDLE" "$PROJECT_ROOT/dist/$APP_NAME.app"

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
