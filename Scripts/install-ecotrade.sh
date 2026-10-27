#!/bin/bash
set -euo pipefail

# Install ZenaEML Viewer on an Ecotrade (or any) Mac from a local .app or mounted DMG.
# Usage:
#   sudo bash Scripts/install-ecotrade.sh /path/to/EMLViewer.app
#   sudo bash Scripts/install-ecotrade.sh "/Volumes/EMLViewer/EMLViewer.app"

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
    echo "usage: $0 /path/to/EMLViewer.app" >&2
    exit 1
fi

DEST="/Applications/ZenaEML Viewer.app"
echo "==> Installing ZenaEML Viewer to $DEST"
rm -rf "$DEST" "/Applications/EMLViewer.app"
ditto --norsrc --noextattr "$SRC" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

echo "==> LaunchServices register"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$DEST" || true

echo "==> Opening once to register Quick Look extension"
open "$DEST"
sleep 2

echo ""
echo "Installed ZenaEML Viewer (ZenaConsult)."
echo "  1. Welcome screen: Set as default for .eml and .msg"
echo "  2. System Settings → General → Login Items & Extensions → Quick Look"
echo "     → enable ZenaEML Viewer Quick Look"
echo "  3. Space-bar a sample .eml; if headers-only, disable Mail/Letter Opener QL briefly"
echo "See docs/ECOTRADE-INSTALL.md"
