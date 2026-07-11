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
