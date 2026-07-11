# PLAN-final-polish — self-verified v1.1 release (README, packaging, QA, verdict)

- **Rank:** 5 of 5 (run LAST)
- **Dependencies:** run AFTER all of PLAN-verify, PLAN-export-backup, PLAN-first-open,
  PLAN-duplicate-drop are either landed or logged in `BLOCKERS.md`. Do not start earlier.
- **Effort:** ~90 minutes (most of it is honestly performing the QA checklist)
- **Files touched:** `README.md`, `macos/Info.plist`, `scripts/package-release.sh` (new),
  `RELEASE-QA.md` (new). **Nothing else committed.** (`release/` outputs are produced but
  stay untracked — that directory is gitignored by design.)

## Goal

This is the release vet nobody else will do. It bumps the version, makes packaging
reproducible (the existing `release/Dewdrops-1.0.*` artifacts were built by hand — no
script in the repo produced them), rewrites the README to document ONLY shipped behavior,
and runs a ~20-row manual QA checklist against the REAL packaged artifact, ending in an
explicit SHIP / DO-NOT-SHIP verdict. The tag exists only if the verdict is SHIP.

## Steps

### Step 0 — inventory what actually landed

Run `git log --oneline` and read `BLOCKERS.md` if it exists. Build a list of which of the
three feature plans landed. Below, lines marked `[export]`, `[first-open]`, `[duplicate]`
are included ONLY if the corresponding plan landed; otherwise use the noted fallback or
omit the line/row. Do not document behavior that is not in the build you are packaging.

### Step 1 — version bump

In `macos/Info.plist`:
- `CFBundleShortVersionString`: `1.0` → `1.1`
- `CFBundleVersion`: `1` → `2`

Do this FIRST — Step 2's script names its artifacts from this value; bumping afterwards
produces artifacts labeled 1.0.

### Step 2 — create `scripts/package-release.sh` (mode 755) with EXACTLY this content

```zsh
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

ditto -c -k --keepParent "$STAGING_DIR/Dewdrops.app" "$RELEASE_DIR/Dewdrops-$VERSION.zip"

hdiutil create -volname "Dewdrops $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO \
  "$RELEASE_DIR/Dewdrops-$VERSION.dmg" >/dev/null

(cd "$RELEASE_DIR" && shasum -a 256 "Dewdrops-$VERSION.zip" "Dewdrops-$VERSION.dmg" > "SHA256SUMS-$VERSION.txt")

echo "$RELEASE_DIR/Dewdrops-$VERSION.zip"
echo "$RELEASE_DIR/Dewdrops-$VERSION.dmg"
```

Then: `chmod +x scripts/package-release.sh`.

### Step 3 — rewrite `README.md`

Replace the full file with the following, applying the conditional edits from Step 0:

```markdown
# Dewdrops

Offline macOS menu bar snippet shelf for prompts, replies, notes, and reusable text.

## Install

Open `release/Dewdrops-<version>.dmg` (or the zip), drag `Dewdrops.app` into
`/Applications`, and launch it. The droplet icon appears in the menu bar; Dewdrops has no
Dock icon.

If macOS blocks the first launch, right-click `Dewdrops.app`, choose **Open**, then confirm
**Open** again (the app is ad-hoc signed, not notarized).

## Use

- Click the menu bar droplet to open the shelf; click a card to copy its text to the
  clipboard.
- Search, category chips, and favorites narrow the grid.
- `+` adds a drop; each card can be edited, duplicated, and deleted.
- Esc closes the editor, the settings panel, or the shelf.
- **Export JSON** saves a backup file; **Import JSON** restores one (import replaces the
  library and asks you to confirm first).
- Settings (gear): vibe colour, category rename/delete, starter drops, clear library.
- Everything stays in local storage on your Mac. No network, ever.

## Build from source

```sh
/bin/zsh scripts/build-mac-app.sh    # -> build/Dewdrops.app
zsh scripts/verify.sh                # build + bundle checks + behavioral smoke
/bin/zsh scripts/package-release.sh  # -> release/Dewdrops-<version>.{zip,dmg}
```

`verify.sh` and the smoke suite need a logged-in macOS session (WebKit); they never open
windows.

## Quit

Right-click the menu bar droplet → **Quit Dewdrops**.
```

Conditional edits:
- `[duplicate]` blocked → change "edited, duplicated, and deleted" to "edited and deleted".
- `[first-open]` blocked → delete the Esc bullet.
- `[export]` blocked → replace the Export/Import bullet with:
  `- **Export JSON** copies the library JSON to the clipboard; **Import JSON** replaces the library from a file.`

### Step 4 — build the release artifacts

```sh
/bin/zsh scripts/package-release.sh
```

Expected: prints the zip and dmg paths; both files exist in `release/`, plus
`SHA256SUMS-1.1.txt` and refreshed `INSTALL.txt`. Old `Dewdrops-1.0.*` files are history —
leave them in place.

Sanity-check the zip's signature survives packaging:

```sh
cd "$(mktemp -d)" && ditto -x -k ~/Programming/mac-dewdrops/release/Dewdrops-1.1.zip . \
  && codesign --verify --deep --strict Dewdrops/Dewdrops.app && echo ZIP-SIGNATURE-OK
```

(The zip contains `Dewdrops/Dewdrops.app` because staging wraps the app in a `Dewdrops`
folder — if `codesign` reports "not signed" or "modified", packaging corrupted the bundle:
STOP, log to BLOCKERS.md.)

### Step 5 — QA protocol (read fully BEFORE starting)

**DATA SAFETY — this is the one irreversible trap in the whole roadmap.** Every copy of
Dewdrops on this machine shares one data store, keyed by bundle id
`com.dewflash.dewdrops` in the user's WebKit storage. The QA rows below include Clear
Library. Skipping the backup steps destroys the machine owner's real snippet library.

1. Quit any running Dewdrops (right-click droplet → Quit Dewdrops). Never run two copies
   at once (two droplet icons, one shared store — undefined confusion).
2. Launch the CURRENT app once and back up the real library to
   `~/Desktop/dewdrops-preqa-backup.json`: use Export JSON `[export]`, else Settings →
   Copy All JSON and paste into that file. Verify the backup parses:
   `python3 -m json.tool ~/Desktop/dewdrops-preqa-backup.json > /dev/null && echo BACKUP-OK`.
   **Do not proceed without BACKUP-OK.**
3. Open `release/Dewdrops-1.1.dmg`, drag `Dewdrops.app` to `/Applications` (replace any
   existing copy — upgrading the real install is the honest test). Eject the dmg.
4. Run every QA row against the `/Applications` copy. The dev build under `build/` skips
   the quarantine/first-launch path, which is exactly what releases break on — testing it
   instead would invalidate rows 1–3.
5. After the last row: Import the pre-QA backup back (confirm the armed import), verify
   the drop count matches pre-QA, then delete the two QA scratch files from the Desktop.

### Step 6 — create `RELEASE-QA.md`, perform it, commit results

Create `RELEASE-QA.md` with the header, the table, and the verdict block below; then
actually perform each row against the packaged app and fill RESULT with PASS or FAIL plus
a note where useful.

Rule, verbatim, and it must appear in the file: **"PASS only from actually performing the
check — an honest FAIL committed is worth more than a green lie."**

Rows marked `[export]` / `[first-open]` / `[duplicate]`: if that plan did not land, mark
the row `SKIPPED (not shipped)` — a skipped row is not a FAIL.

```markdown
# Dewdrops 1.1 — Release QA

Performed against: /Applications/Dewdrops.app installed from release/Dewdrops-1.1.dmg
Date / macOS version: <fill in>

Rule: "PASS only from actually performing the check — an honest FAIL committed is worth
more than a green lie."

| # | Area | Steps | Expected | RESULT |
|---|------|-------|----------|--------|
| 1 | Install | Open the 1.1 dmg; volume shows Dewdrops.app + INSTALL.txt; drag to /Applications | Both files visible; copy succeeds | |
| 2 | First launch | Launch from /Applications (right-click → Open if blocked) | App launches; droplet icon in menu bar | |
| 3 | Accessory app | Check Dock and Cmd-Tab | No Dock icon, no Cmd-Tab entry | |
| 4 | Open shelf | Click the droplet | Popover opens, dark themed, cards visible | |
| 5 | First-open polish [first-open] | Watch popover on the FIRST open after launch | No white flash, content already rendered | |
| 6 | Type-to-search [first-open] | Open shelf while another app is frontmost; type immediately | Keystrokes land in search; grid filters | |
| 7 | Copy exactness | Click the "Bug report shape" card; paste into TextEdit | Pasted text has all 5 lines, line breaks intact | |
| 8 | Copy feedback | Click any card | "Copied" toast appears | |
| 9 | Search | Type a word that matches one drop | Grid narrows to matching card(s) | |
| 10 | Category filter | Click a category chip, then "All" | Grid filters, then restores | |
| 11 | Favorites | Star a card; check "Favorites" chip | Starred card listed; favorites sort first in All | |
| 12 | Add drop | + → fill title/category/body → Save | Count label +1; card appears; toast "Drop added" | |
| 13 | Validation | + → leave title empty → Save | Save blocked with visible feedback on the empty field (report what you see) | |
| 14 | Edit drop | Edit a card, change body, Save | Reopening Edit shows new body; copy pastes new body | |
| 15 | Duplicate [duplicate] | Duplicate a card | New "<title> copy" card, not starred, same body on copy | |
| 16 | Delete drop | Delete a card | Card gone; count label -1; toast "Drop deleted" | |
| 17 | Categories | Settings: add, rename, delete a category with drops in it | Rename cascades to drops; delete moves drops to "Notes" | |
| 18 | Vibe colour | Settings: change vibe; quit and relaunch | New accent everywhere; survives relaunch | |
| 19 | Export [export] | Export JSON → save to Desktop | File exists; `python3 -m json.tool` parses it | |
| 20 | Import guard [export] | Click Import once with drops present | Button arms ("Replaces All - Sure?"); reverts after ~4 s | |
| 21 | Import restore [export] | Import the exported file (two clicks) | "Library imported"; drops match export | |
| 22 | Clear library | Settings: Clear Library twice | First click arms; second empties; "No drops yet." empty state | |
| 23 | Starters | Settings: Restore Starters on the empty library | 4 starter drops return | |
| 24 | Esc behavior [first-open] | Esc in shelf; Esc inside open editor | Shelf closes; editor closes first, shelf stays | |
| 25 | Persistence | Add a marker drop; quit app; relaunch | Marker drop still present | |
| 26 | Quit | Right-click droplet → Quit Dewdrops | App quits; droplet disappears | |

## Verdict

**SHIP / DO-NOT-SHIP** (delete one)

Notes: <any FAIL gets a line here: row, what was observed, why it does or does not block>
```

Verdict rules:
- Any FAIL → DO-NOT-SHIP, unless the note explains why it is known-and-accepted and the
  failure does not touch the core promise (copy exactness, persistence, no data loss).
  Copy-wrongness, data loss, or crash = DO-NOT-SHIP, no exceptions.
- Never edit a FAIL into a PASS. Never perform a row "mentally".

### Step 7 — gate, commit, tag

1. `zsh scripts/verify.sh` → `VERIFY GREEN` (regression check after the plist change).
2. Commit `README.md`, `macos/Info.plist`, `scripts/package-release.sh`, `RELEASE-QA.md`
   (with the verdict filled in) using the suggested message below.
3. ONLY if the committed verdict is SHIP: `git tag v1.1`. If DO-NOT-SHIP: no tag; add a
   `BLOCKERS.md` entry summarizing the failing rows; the engagement ends there honestly.

## Edge cases a weaker model would miss

- **`ditto`, never `cp -R`, for staging the .app.** `cp` can drop extended attributes and
  break the code signature; end users then get Gatekeeper's "damaged" dialog instead of the
  right-click-Open path. Same reason the zip is built with `ditto -c -k --keepParent`.
- **`release/` is gitignored on purpose.** The dmg/zip/SHA256SUMS/INSTALL.txt outputs stay
  untracked; do not `git add -f` binaries. The packaging script is the reproducibility
  artifact, not the binaries.
- **`release/INSTALL.txt` on disk predates this plan and is NOT in git** (the whole
  directory is ignored) — that is why the script owns the INSTALL.txt content via heredoc.
  Do not "restore" the old file from disk into git.
- **`spctl --assess` on this app reports "rejected" — that is EXPECTED for an ad-hoc
  signed, non-notarized app.** It is not a QA failure; the documented right-click-Open path
  is the supported install story. Do not chase notarization (needs a paid Developer ID).
- **`hdiutil create` fails if a previous "Dewdrops 1.1" volume is still mounted.** If you
  opened the dmg and rerun packaging, eject first (`hdiutil info` to check).
- **The dmg contains INSTALL.txt because staging wraps app+txt in one folder** — keep the
  `-srcfolder "$STAGING_DIR"` shape; pointing it at the .app alone drops the instructions.
- **QA row 13 (validation) may genuinely FAIL** if WKWebView does not render HTML5
  validation bubbles. That is exactly the kind of honest finding this checklist exists to
  record — write down what you observed; per the verdict rules it is not automatically
  blocking (no data loss, core promise untouched).
- **The version string in acceptance and artifact names comes from the plist** — if
  artifacts came out named `Dewdrops-1.0.*`, you ran Step 2 before Step 1; fix the plist,
  rerun packaging, delete the mislabeled files.

## Acceptance criteria

1. `zsh scripts/verify.sh` exits 0 → `VERIFY GREEN`.
2. `/bin/zsh scripts/package-release.sh` exits 0; `release/Dewdrops-1.1.zip`,
   `release/Dewdrops-1.1.dmg`, `release/SHA256SUMS-1.1.txt` exist; the Step 4 zip
   signature check prints `ZIP-SIGNATURE-OK`.
3. `/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' macos/Info.plist`
   prints `1.1`.
4. `RELEASE-QA.md` is committed with every row's RESULT filled (PASS / FAIL / SKIPPED),
   the verbatim honesty rule present, and exactly one verdict left standing.
5. The pre-QA backup was restored (drop count matches pre-QA state) — state this in the
   QA notes.
6. `git status --porcelain` clean after commit; tracked changes were exactly `README.md`,
   `macos/Info.plist`, `scripts/package-release.sh`, `RELEASE-QA.md`.
7. `git tag --list v1.1` shows the tag IFF the committed verdict is SHIP.

Suggested commit message:

```
release: v1.1 with packaging script, README, and QA verdict
```
