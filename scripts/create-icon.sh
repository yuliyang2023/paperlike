#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/build/WeRead.iconset"
mkdir -p "$ICONSET"
clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
  -framework Cocoa "$ROOT/scripts/make-app-icon.m" -o "$ROOT/build/make-app-icon"
SOURCE="$ROOT/build/WeRead-macOS.png"
"$ROOT/build/make-app-icon" "$ROOT/Resources/WeRead.png" "$SOURCE"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$ROOT/build/WeRead.icns" "$ICONSET"
