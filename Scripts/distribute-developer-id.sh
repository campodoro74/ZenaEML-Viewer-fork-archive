#!/bin/bash
set -euo pipefail

# Build a Developer ID–signed, notarized DMG for Ecotrade / fleet install.
# Prerequisites (one-time):
#   xcrun notarytool store-credentials "zenaconsult" \
#     --apple-id "dev@zenaconsult.com" \
#     --team-id "P675R8Z5DF" \
#     --password "<app-specific password>"
#
# Or set NOTARY_PROFILE to an existing keychain profile name.

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="EMLViewer"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
DIST_DIR="/tmp/emlviewer-dist"
EXPORT_DIR="$PROJECT_ROOT/dist"
mkdir -p "$DIST_DIR" "$EXPORT_DIR"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"
ZIP="$DIST_DIR/$APP_NAME-$VERSION-notarize.zip"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Martijn Goudkamp (P675R8Z5DF)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-zenaconsult}"
SKIP_NOTARY="${SKIP_NOTARY:-0}"

echo "==> Building Release (Developer ID)"
bash Scripts/build.sh release --developer-id

if [ ! -d "$APP_BUNDLE/Contents/PlugIns/EMLViewerQuickLook.appex" ]; then
    echo "error: Quick Look appex missing from $APP_BUNDLE" >&2
    exit 1
fi

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose=4 "$APP_BUNDLE" 2>&1 || true

echo "==> Creating DMG staging"
STAGE=$(mktemp -d /tmp/emlviewer-dmg.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP_BUNDLE" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
xattr -cr "$STAGE/$APP_NAME.app" 2>/dev/null || true

rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
xattr -cr "$DMG" 2>/dev/null || true

copy_exports() {
    ditto --norsrc --noextattr "$DMG" "$EXPORT_DIR/$(basename "$DMG")"
    EXPORTS="$HOME/Documents/Agent/exports/emlviewer"
    mkdir -p "$EXPORTS"
    ditto --norsrc --noextattr "$DMG" "$EXPORTS/$(basename "$DMG")"
    ditto --norsrc --noextattr "$APP_BUNDLE" "$EXPORTS/$APP_NAME.app"
    xattr -cr "$EXPORTS/$APP_NAME.app" "$EXPORTS/$(basename "$DMG")" 2>/dev/null || true
    echo "Exported to $EXPORTS/$(basename "$DMG")"
}

if [ "$SKIP_NOTARY" = "1" ]; then
    echo "SKIP_NOTARY=1 — signed DMG without notarization: $DMG"
    copy_exports
    shasum -a 256 "$DMG"
    exit 0
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    copy_exports
    cat <<EOF

error: notarytool keychain profile '$NOTARY_PROFILE' not found.

Store credentials once (Apple ID: dev@zenaconsult.com, Team: P675R8Z5DF):

  xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
    --apple-id "dev@zenaconsult.com" \\
    --team-id "P675R8Z5DF" \\
    --password "<app-specific-password>"

Then re-run: bash Scripts/distribute-developer-id.sh

A Developer ID–signed (but not notarized) DMG is ready at:
  $DMG
  $HOME/Documents/Agent/exports/emlviewer/$(basename "$DMG")

EOF
    exit 2
fi

echo "==> Submitting to Apple notarization"
# Prefer zip of the .app for notarytool; staple the app then rebuild DMG, or notarize DMG directly.
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP"
SUBMIT_OUT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait)
echo "$SUBMIT_OUT"

echo "==> Stapling"
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

# Rebuild DMG with stapled app
rm -rf "$STAGE"
STAGE=$(mktemp -d /tmp/emlviewer-dmg.XXXXXX)
ditto "$APP_BUNDLE" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
xcrun stapler staple "$DMG" 2>/dev/null || true

# Copy stapled DMG into the repo dist/ (and exports) without resource forks
ditto --norsrc --noextattr "$DMG" "$EXPORT_DIR/$(basename "$DMG")"
EXPORTS="$HOME/Documents/Agent/exports/emlviewer"
mkdir -p "$EXPORTS"
ditto --norsrc --noextattr "$DMG" "$EXPORTS/$(basename "$DMG")"
ditto --norsrc --noextattr "$APP_BUNDLE" "$EXPORTS/$APP_NAME.app"
xattr -cr "$EXPORTS/$APP_NAME.app" "$EXPORTS/$(basename "$DMG")" 2>/dev/null || true

echo ""
echo "Ready for Ecotrade:"
echo "  App:  $APP_BUNDLE  (v$VERSION build $BUILD)"
echo "  DMG:  $DMG"
echo "  Copy: $EXPORTS/$(basename "$DMG")"
shasum -a 256 "$DMG"
echo "Install notes: docs/ECOTRADE-INSTALL.md"
