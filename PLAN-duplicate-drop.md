# PLAN-duplicate-drop — implement the advertised Duplicate action

- **Rank:** 4 of 5
- **Dependencies:** run AFTER PLAN-verify (the gate must exist). Independent of PLAN-export-backup and PLAN-first-open.
- **Effort:** ~20 minutes
- **Files touched:** `index.html`, `scripts/smoke.swift` (assertions added only). **Nothing else.**

## Goal

`README.md` line 17 advertises "Add, edit, delete, and duplicate snippets" — but no
duplicate capability exists anywhere in `index.html`. `snippetCard()` builds a footer with
exactly two actions (Edit via `openEditor`, Delete via `deleteSnippet`); there is no
`duplicateSnippet` function. The README lies about a feature.

Duplicating a drop to tweak a variant (same prompt, different tone) is squarely inside the
product story of a reusable-text shelf, and the honest fix is smaller than rewriting the
README around the gap: one button, one function, one icon.

## Steps

### Step 1 — add the Duplicate button to the card footer

In `snippetCard()` in `index.html`, replace:

```js
        const footer = document.createElement("div");
        footer.className = "tile-footer";
        footer.append(
          actionButton("", "Edit", editIcon(), () => openEditor(snippet.id)),
          actionButton("delete", "Delete", trashIcon(), () => deleteSnippet(snippet.id))
        );
```

with:

```js
        const footer = document.createElement("div");
        footer.className = "tile-footer";
        footer.append(
          actionButton("", "Duplicate", duplicateIcon(), () => duplicateSnippet(snippet.id)),
          actionButton("", "Edit", editIcon(), () => openEditor(snippet.id)),
          actionButton("delete", "Delete", trashIcon(), () => deleteSnippet(snippet.id))
        );
```

### Step 2 — add `duplicateSnippet`

Directly after the existing `deleteSnippet` function, add:

```js
      function duplicateSnippet(id) {
        const source = snippets.find((item) => item.id === id);
        if (!source) return;
        snippets.unshift(makeSnippet({
          title: `${source.title.slice(0, 23)} copy`,
          category: source.category,
          body: source.body,
          favorite: false
        }));
        saveSnippets();
        render();
        showToast("Drop duplicated");
      }
```

### Step 3 — add the icon

Directly after the existing `editIcon()` function, add:

```js
      function duplicateIcon() {
        return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2" stroke="currentColor" stroke-width="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';
      }
```

### Step 4 — smoke: add the duplicate assertions

In `scripts/smoke.swift`, insert this block directly after the SMOKE-DELETE block (after
its `expect("SMOKE-DELETE", countLabel(), "4 drops")` line) and before
`print("SMOKE OK")`:

```swift
// SMOKE-DUPLICATE: duplicating a card creates "<title> copy" with the same body.
expect("SMOKE-DUPLICATE click", clickInCard(title: "Friendly follow-up", selector: "[aria-label=\"Duplicate\"]"), "CLICKED")
expect("SMOKE-DUPLICATE count", countLabel(), "5 drops")
let dupBefore = bridge.messages.count
expect("SMOKE-DUPLICATE copy click", clickInCard(title: "Friendly follow-up copy", selector: ""), "CLICKED")
guard spin(seconds: 5, until: { bridge.messages.count > dupBefore }) else {
    fail("SMOKE-DUPLICATE: no bridge message after clicking the duplicate")
}
expect("SMOKE-DUPLICATE body", bridge.messages.last!["text"] as? String ?? "<missing>",
       "Hey, just following up on this. No rush, but wanted to keep it on your radar. Thanks.")
expect("SMOKE-DUPLICATE cleanup", clickInCard(title: "Friendly follow-up copy", selector: "[aria-label=\"Delete\"]"), "CLICKED")
expect("SMOKE-DUPLICATE end", countLabel(), "4 drops")
```

These are additive; no existing assertion changes in this plan.

### Step 5 — run the gate

```sh
zsh scripts/verify.sh
```

Expected: all previous SMOKE lines plus the five `SMOKE-DUPLICATE* OK` lines, then
`VERIFY GREEN`, exit 0.

## Edge cases a weaker model would miss

- **The title budget math is exact, not stylistic.** `makeSnippet` hard-slices titles at 28
  characters (`String(input.title || "Untitled").slice(0, 28)`). `slice(0, 23) + " copy"`
  is at most 28, so the ` copy` suffix ALWAYS survives. If you "simplify" to
  `source.title + " copy"`, any title near 28 chars gets its suffix truncated away and the
  duplicate becomes visually identical to the original — the user cannot tell which card is
  which, and the feature reads as broken.
- **`makeSnippet({...fields})`, never `{ ...source }`.** Spreading the source would copy its
  `id`; every lookup in the app is `snippets.find((item) => item.id === id)`, so a duplicated
  id makes favorite/edit/delete hit whichever card happens to be found first. `makeSnippet`
  mints a fresh id and fresh timestamps. This is the nastiest trap in the plan.
- **`favorite: false` is deliberate.** Duplicating a pinned favorite should yield a working
  draft, not a second pinned card that reshuffles the grid (favorites sort first in
  `filteredSnippets`). Do not "preserve all fields faithfully".
- **The Duplicate button's class is `""`, not `"delete"`.** Copy-pasting the Delete line and
  keeping its class makes Duplicate glow the danger color on hover (see the
  `.mini-button.delete:hover` CSS rule).
- **No event plumbing needed:** `actionButton` already wraps handlers with
  `event.stopPropagation()`, so the click does not bubble into the card's copy action.
  `duplicateSnippet` receives no event argument — keep its signature as written.
- **Layout is already safe:** three 22 px buttons + two 5 px gaps = 76 px inside a ~127 px
  card; do not shrink buttons or adjust CSS.
- **Chained duplicates stay legal by construction:** "Friendly follow-up copy" (23 chars)
  duplicates to exactly 28 chars; further generations keep slicing back to ≤28. No guard
  needed — don't add one.
- **Smoke expectations rely on the exact strings:** "Friendly follow-up" is 18 chars, so its
  duplicate title is exactly `Friendly follow-up copy`, and `compactTitle` (limit 28) passes
  it through unchanged, so `.snippet-title` textContent matches exactly.

## Acceptance criteria

1. `zsh scripts/verify.sh` exits 0; output contains all five `SMOKE-DUPLICATE` lines OK,
   `SMOKE OK`, `VERIFY GREEN`.
2. `git status --porcelain` shows exactly: `index.html`, `scripts/smoke.swift`.
3. Manual (dev build, observable — quit any other running Dewdrops copy first, and note
   the shared-data warning in AGENTS.md):
   - Launch `build/Dewdrops.app`, open the popover: every card shows three footer buttons;
     Duplicate hovers accent-colored (not red).
   - Duplicate a favorite starter: the new card appears titled `<title> copy`, is NOT
     starred, and clicking it copies the same body text (paste somewhere to compare).
   - Delete the duplicate afterwards; quit the app.
4. README.md line 17 is now true as written (no README edit in this plan).

Suggested commit message:

```
feat: duplicate drop action on snippet cards
```
