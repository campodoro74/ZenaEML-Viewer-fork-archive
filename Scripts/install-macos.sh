#!/bin/bash
set -euo pipefail

# Install ZenaEML Viewer into /Applications.
# Usage: sudo bash Scripts/install-macos.sh /path/to/EMLViewer.app

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
    echo "usage: $0 /path/to/EMLViewer.app" >&2
    exit 1
fi

DEST="/Applications/ZenaEML Viewer.app"
echo "==> Installing to $DEST"
rm -rf "$DEST" "/Applications/EMLViewer.app"
ditto --norsrc --noextattr "$SRC" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$DEST" || true

open "$DEST"
echo "Installed. Optionally set as default for .eml / .msg from the welcome screen."
