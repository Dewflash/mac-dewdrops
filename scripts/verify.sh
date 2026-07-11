#!/bin/zsh
# One-command verification: build + bundle integrity + page contracts + smoke.
# Needs a logged-in macOS session (WebKit); never opens a window.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Dewdrops.app"

echo "== verify: build =="
/bin/zsh "$ROOT_DIR/scripts/build-mac-app.sh" >/dev/null

echo "== verify: bundle structure =="
[[ -x "$APP_DIR/Contents/MacOS/Dewdrops" ]] || { echo "FAIL: missing or non-executable Contents/MacOS/Dewdrops"; exit 1; }
[[ -s "$APP_DIR/Contents/Resources/Dewdrops.icns" ]] || { echo "FAIL: missing Contents/Resources/Dewdrops.icns"; exit 1; }
cmp -s "$ROOT_DIR/index.html" "$APP_DIR/Contents/Resources/index.html" || { echo "FAIL: bundled index.html differs from source index.html"; exit 1; }
plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null || { echo "FAIL: bundled Info.plist does not lint"; exit 1; }

echo "== verify: code signature =="
codesign --verify --deep --strict "$APP_DIR" || { echo "FAIL: codesign verification"; exit 1; }

echo "== verify: index.html contracts =="
for needle in 'id="countLabel"' 'id="snippetList"' 'dewdropsNative' 'dewdrops.snippets.v1'; do
  grep -qF "$needle" "$ROOT_DIR/index.html" || { echo "FAIL: index.html lost required marker: $needle"; exit 1; }
done

# --- SMOKE ---
# PLAN-verify.md replaces the next echo line with the mandatory smoke-test run.
# Until that plan lands, no behavioral smoke exists at HEAD.
echo "== verify: smoke — NOT YET INSTALLED (see PLAN-verify.md) =="

echo "VERIFY GREEN"
