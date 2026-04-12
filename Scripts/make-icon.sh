#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

SOURCE="Resources/AppIcon.source.png"
OUTPUT="Resources/AppIcon.icns"
CONTENT=820          # Размер envelope внутри финального 1024x1024 canvas
CANVAS=1024
FUZZ=8%              # Насколько "белым" считать фон при удалении

TMP="$(mktemp -d)"
ICONSET="$TMP/AppIcon.iconset"
STAGED="$TMP/staged.png"
mkdir -p "$ICONSET"

if [ ! -f "$SOURCE" ]; then
    echo "error: $SOURCE not found" >&2; exit 1
fi
if ! command -v magick >/dev/null; then
    echo "error: ImageMagick (magick) not installed" >&2; exit 1
fi
if ! command -v iconutil >/dev/null; then
    echo "error: iconutil missing (expected on macOS)" >&2; exit 1
fi

echo "==> Stage: make white transparent, auto-trim, resize, center on transparent canvas"
magick "$SOURCE" \
    -fuzz "$FUZZ" -transparent white \
    -trim +repage \
    -resize "${CONTENT}x${CONTENT}" \
    -background none -gravity center -extent "${CANVAS}x${CANVAS}" \
    -strip \
    "$STAGED"

echo "==> Generating iconset sizes"
gen_size() {
    local size="$1" out="$2"
    magick "$STAGED" -resize "${size}x${size}" -strip "$ICONSET/$out"
}
gen_size   16  "icon_16x16.png"
gen_size   32  "icon_16x16@2x.png"
gen_size   32  "icon_32x32.png"
gen_size   64  "icon_32x32@2x.png"
gen_size  128  "icon_128x128.png"
gen_size  256  "icon_128x128@2x.png"
gen_size  256  "icon_256x256.png"
gen_size  512  "icon_256x256@2x.png"
gen_size  512  "icon_512x512.png"
gen_size 1024  "icon_512x512@2x.png"

if command -v pngquant >/dev/null; then
    echo "==> Palette quantization (pngquant)"
    # 8-bit indexed palette: для градиентной envelope визуально почти не отличается,
    # но уменьшает размер PNG в 3-5 раз.
    for f in "$ICONSET"/*.png; do
        pngquant --force --quality=78-95 --speed 1 --strip --output "$f" -- "$f" || true
    done
fi

if command -v oxipng >/dev/null; then
    echo "==> Optimizing PNGs (oxipng)"
    oxipng -o max --strip all --quiet "$ICONSET"/*.png
fi

echo "==> Compiling .icns"
iconutil -c icns "$ICONSET" -o "$OUTPUT"

rm -rf "$TMP"

BYTES=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT")
KB=$((BYTES / 1024))
echo "Done: $OUTPUT (${KB} KB)"
