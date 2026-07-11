#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Dewdrops.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="${TMPDIR:-/tmp}/Dewdrops.iconset"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

rm -rf "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/render-app-icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/Dewdrops.icns"
rm -rf "$ICONSET_DIR"

swiftc "$ROOT_DIR/macos/DewdropsApp.swift" \
  -framework AppKit \
  -framework WebKit \
  -o "$MACOS_DIR/Dewdrops"

cp "$ROOT_DIR/macos/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/index.html" "$RESOURCES_DIR/index.html"

chmod +x "$MACOS_DIR/Dewdrops"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "$APP_DIR"

