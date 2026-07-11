#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Dewdrops.app"
RELEASE_DIR="$ROOT_DIR/release"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/macos/Info.plist")"
STAGING_DIR="$(mktemp -d)/Dewdrops"

/bin/zsh "$ROOT_DIR/scripts/build-mac-app.sh" >/dev/null

mkdir -p "$RELEASE_DIR" "$STAGING_DIR"
ditto "$APP_DIR" "$STAGING_DIR/Dewdrops.app"

cat > "$STAGING_DIR/INSTALL.txt" <<EOF
Dewdrops $VERSION

Install:
1. Drag Dewdrops.app to your Applications folder.
2. Open Dewdrops from Applications.

If macOS blocks the first launch, right-click Dewdrops.app, choose Open,
then choose Open again.

Dewdrops is offline. Your saved drops, categories, and vibe colour stay on
your Mac.
EOF

cp "$STAGING_DIR/INSTALL.txt" "$RELEASE_DIR/INSTALL.txt"

ditto -c -k --keepParent "$STAGING_DIR" "$RELEASE_DIR/Dewdrops-$VERSION.zip"

hdiutil create -volname "Dewdrops $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO \
  "$RELEASE_DIR/Dewdrops-$VERSION.dmg" >/dev/null

(cd "$RELEASE_DIR" && shasum -a 256 "Dewdrops-$VERSION.zip" "Dewdrops-$VERSION.dmg" > "SHA256SUMS-$VERSION.txt")

echo "$RELEASE_DIR/Dewdrops-$VERSION.zip"
echo "$RELEASE_DIR/Dewdrops-$VERSION.dmg"
