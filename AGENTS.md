# AGENTS.md — execution roadmap for the Dewdrops handover

You are executing a pre-planned roadmap. The thinking is already done and written into the
`PLAN-*.md` files at repo root; your job is faithful execution, one plan per session. When a
plan and your own judgment disagree, the plan wins — every deviation it forbids is a trap
someone already hit or foresaw.

**Product core promise** (judge any ambiguity against this): *a saved snippet is never more
than two clicks away — menu bar droplet → card → the exact text is on the clipboard,
instantly, offline, and never lost.*
(Derived from README + code at handover time; the original one-sentence brief was not
provided.)

## What this app is

A macOS menu bar app: `macos/DewdropsApp.swift` (AppKit status item + NSPopover + WKWebView)
hosts `index.html` (the entire UI and logic, one file). `scripts/build-mac-app.sh` compiles
and assembles `build/Dewdrops.app`. `scripts/verify.sh` is the gate. No package manager, no
dependencies, no network.

## Step 0 — first session only

Commit the roadmap docs before touching anything else, so no stray checkout can lose them:

```sh
git add AGENTS.md PLAN-*.md scripts/verify.sh
git commit -m "docs: add execution roadmap"
```

Then run `zsh scripts/verify.sh` once — it must print `VERIFY GREEN` (it did at handover).
That commit is your first "last green commit".

## Execution order

```
PLAN-verify            (rank 1, no dependencies — the gate grows teeth here)
   ├── PLAN-export-backup   (rank 2, independent of 3 and 4)
   ├── PLAN-first-open      (rank 3, independent of 2 and 4)
   └── PLAN-duplicate-drop  (rank 4, independent of 2 and 3)
PLAN-final-polish      (rank 5, LAST — requires 1–4 each landed or logged in BLOCKERS.md)
```

One plan per session: complete it, pass the gate, commit, stop. Do not start the next plan
in the same session. Do not reorder ranks 2–4 without cause; if one of them is blocked, the
other two are safe to proceed with (they touch disjoint functions; each plan's smoke
additions are anchored to named blocks, not line numbers).

## The hard gate (after every plan, no exceptions)

1. `zsh scripts/verify.sh` exits 0 and prints `VERIFY GREEN`.
2. That plan's own **Acceptance criteria** section — every numbered item, including the
   manual checks, actually performed.
3. Commit with the plan's suggested commit message. Working tree clean afterwards.

**Never weaken a gate on your own.** No deleting or loosening smoke assertions, no
`|| true`, no skipped manual checks, no "temporarily" commenting out. The ONLY authorized
assertion changes are the ones a PLAN file spells out verbatim (PLAN-export-backup rewrites
the SMOKE-EXPORT block; PLAN-first-open and PLAN-duplicate-drop add new blocks). If the
gate can only pass by changing something no plan authorizes, that is a blocker — see below.

## Failure protocol

- Revert to the last green commit (`git reset --hard <last-green>`). Never leave a
  half-landed plan in the tree, and never commit on top of a red gate.
- Append to `BLOCKERS.md` (create it on first use): the plan name, the step number, the
  exact failing command, the FULL output (not a summary), and what you tried.
- Continue only with plans that do not depend on the blocked one. PLAN-final-polish always
  runs last regardless, and adapts to BLOCKERS.md (its Step 0 tells it how).

## House rules

- **No new runtime dependencies.** No npm/node, no SwiftPM packages, no CocoaPods, no
  frameworks beyond AppKit/WebKit/UniformTypeIdentifiers. Dev-time system tools only:
  `swiftc`, `swift`, `iconutil`, `plutil`, `codesign`, `ditto`, `hdiutil`, `shasum`,
  `PlistBuddy`.
- **Match existing style:** 2-space indent in HTML/JS, 4-space in Swift; no decorative
  comments; JS uses the existing closure/function style — no classes, no modules.
- **Never commit:** `build/`, anything in `release/` (gitignored binaries), `.DS_Store`,
  crash logs, or any secret. `git add` specific files, never `git add .`.
- **Shared data store warning (the one irreversible trap):** every copy of Dewdrops —
  dev build, installed app, QA install — shares ONE library, keyed by bundle id
  `com.dewflash.dewdrops` in the user's WebKit storage. Before ANY manual check that
  mutates the library (import, clear), export a backup and restore it afterwards. Never
  run two copies at once.
- **`verify.sh` needs a logged-in macOS GUI session** (WebKit). It never opens windows.
  Launching `build/Dewdrops.app` is only for a plan's manual checks — quit it when done.

## Architecture invariants (one line each — breaking any is a stop-and-log)

- `index.html` is the entire UI: single file, no bundler, no framework, no external assets.
- Offline only: any `fetch`/XHR/WebSocket in app code is a violation, full stop.
- localStorage keys `dewdrops.snippets.v1`, `dewdrops.categories.v1`, `dewdrops.vibe.v1`
  are persistence contracts — renaming one orphans every user's data.
- Popover size 430×560 is duplicated in `AppConfig.popoverSize` (Swift) and the `body` CSS
  (HTML) — change both or neither.
- User content renders via `textContent` only; `innerHTML` is reserved for the static icon
  strings (XSS boundary).
- The JS↔Swift bridge is `webkit.messageHandlers.dewdropsNative` with `{type: "copy"}`
  (plus `"export"` / `"close"` once their plans land) — both sides of a message change in
  the same commit, and `scripts/smoke.swift` asserts the contract from the JS side.

## Definition of done

- All five plans landed, or blocked with honest `BLOCKERS.md` entries.
- `zsh scripts/verify.sh` prints `VERIFY GREEN` at final HEAD.
- `RELEASE-QA.md` committed with every row performed and an explicit SHIP or DO-NOT-SHIP
  verdict ("PASS only from actually performing the check — an honest FAIL committed is
  worth more than a green lie.").
- `git tag v1.1` exists if and only if the verdict is SHIP.
- Working tree clean; `release/` contains the v1.1 zip, dmg, and SHA256SUMS on disk.
