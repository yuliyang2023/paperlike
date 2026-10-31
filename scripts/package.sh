#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/墨读 Paperlike.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
NAME="PaperlikeReader-${VERSION}-macos-intel"
mkdir -p "$ROOT/dist"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/${NAME}.zip"
(
  cd "$ROOT/dist"
  LC_ALL=C shasum -a 256 "${NAME}.zip" > "${NAME}.zip.sha256"
)
printf '%s\n' "$ROOT/dist/${NAME}.zip"
