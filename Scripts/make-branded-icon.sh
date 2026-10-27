#!/bin/bash
set -euo pipefail
# Original EMLViewer envelope + ZenaConsult orange shield badge on transparent canvas.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIG="${1:-}"
if [ -z "$ORIG" ]; then
  ORIG=$(mktemp /tmp/emlviewer-orig.XXXX.png)
  git -C "$ROOT" show 5e9a657:Resources/AppIcon.source.png > "$ORIG"
fi
LOGO="${ZENA_LOGO:?Set ZENA_LOGO to the ZenaConsult logo PNG path}"
OUT="$ROOT/Resources/AppIcon.source.png"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

magick "$ORIG" -fuzz 8% -transparent white -trim +repage \
  -resize 820x820 -background none -gravity center -extent 1024x1024 "$TMP/base.png"
magick "$LOGO" -fuzz 12% -transparent black -trim +repage -resize 220x220 "$TMP/logo-clear.png"
magick -size 280x280 xc:none \
  -fill 'rgba(255,255,255,0.95)' -draw 'circle 140,140 140,6' \
  \( "$TMP/logo-clear.png" -gravity center \) -compose over -composite "$TMP/badge.png"
magick "$TMP/base.png" "$TMP/badge.png" -gravity southeast -geometry +40+40 \
  -compose over -composite PNG32:"$OUT"
bash "$ROOT/Scripts/make-icon.sh"
