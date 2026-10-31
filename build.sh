#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/墨读 Paperlike.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
clang -arch x86_64 -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=12.0 \
  -framework Cocoa -framework WebKit -framework CoreGraphics \
  "$ROOT/Sources/main.m" -o "$APP/Contents/MacOS/PaperlikeReader"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/ink.js" "$APP/Contents/Resources/ink.js"
cp "$ROOT/Resources/ai.js" "$APP/Contents/Resources/ai.js"
cp "$ROOT/Resources/ai-test.html" "$APP/Contents/Resources/ai-test.html"
cp "$ROOT/Resources/selection-test.html" "$APP/Contents/Resources/selection-test.html"
bash "$ROOT/scripts/create-icon.sh"
cp "$ROOT/build/WeRead.icns" "$APP/Contents/Resources/WeRead.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
test "$(lipo -archs "$APP/Contents/MacOS/PaperlikeReader")" = "x86_64"
printf '%s\n' "$APP"
