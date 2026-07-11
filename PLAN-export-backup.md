# PLAN-export-backup — make Export actually write a file; guard destructive Import

- **Rank:** 2 of 5
- **Dependencies:** run AFTER PLAN-verify (the gate must exist). Independent of PLAN-first-open and PLAN-duplicate-drop.
- **Effort:** ~45 minutes
- **Files touched:** `index.html`, `macos/DewdropsApp.swift`, `scripts/smoke.swift` (one assertion block replaced, one added). **Nothing else.**

## Goal

README advertises "JSON export and import for backup", but in the packaged app **Export
never produces a file**. `exportJson()` in `index.html` creates a blob URL and clicks an
`<a download>` link — and WKWebView ignores anchor downloads unless the host app implements
download handling. `macos/DewdropsApp.swift` sets only `view.uiDelegate = self` (inside the
`webView` lazy initializer); there is no `navigationDelegate` and no `WKDownloadDelegate`
anywhere. The only observable effect of Export today is the incidental clipboard copy.

Second gap, same feature area: `importJson()` REPLACES the entire library
(`snippets = parsed.map(makeSnippet)`) with zero confirmation — while the far less
destructive Clear Library requires two clicks. A misclicked import destroys every drop.

This plan routes Export through the native bridge to an `NSSavePanel`, and arms Import with
the same two-click confirm pattern `clearLibrary()` already uses. It is rank 2 because the
product promise ends with "never lost", and today the backup story is silently broken in
the shipped artifact.

## Steps

### Step 1 — Swift: add the UTType import

In `macos/DewdropsApp.swift`, the file starts with:

```swift
import AppKit
import WebKit
```

Add a third line:

```swift
import UniformTypeIdentifiers
```

### Step 2 — Swift: handle the "export" bridge message

In `userContentController(_:didReceive:)` (class `WebViewController`), the switch reads:

```swift
        switch type {
        case "copy":
            if let text = body["text"] as? String {
                copyToPasteboard(text)
                callJavaScriptCallback("dewdropsNativeCopied")
            }
        default:
            break
        }
```

Insert a new case between the `case "copy":` block and `default:` (if other cases already
exist there from another plan, keep them — just add this one):

```swift
        case "export":
            if let json = body["json"] as? String {
                exportToFile(json)
            }
```

### Step 3 — Swift: the save-panel writer

Add this method to `WebViewController`, directly after the existing
`copyToPasteboard(_:)` method:

```swift
    private func exportToFile(_ json: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "dewdrops-library.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                self?.callJavaScriptCallback("dewdropsNativeExported")
            } catch {
                NSSound.beep()
            }
        }
    }
```

### Step 4 — JS: prefer the native export path

In `index.html`, replace the entire `exportJson` function:

```js
      function exportJson() {
        const json = JSON.stringify(snippets, null, 2);
        copySnippet(json);
        const blob = new Blob([json], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = "dewdrops-library.json";
        link.click();
        URL.revokeObjectURL(url);
      }
```

with:

```js
      function exportJson() {
        const json = JSON.stringify(snippets, null, 2);
        if (postNativeMessage({ type: "export", json })) return;
        copySnippet(json);
        const blob = new Blob([json], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = "dewdrops-library.json";
        link.click();
        URL.revokeObjectURL(url);
      }
```

### Step 5 — JS: the exported callback

Directly after the existing line

```js
      window.dewdropsNativeCopied = () => showToast("Copied");
```

add:

```js
      window.dewdropsNativeExported = () => showToast("Exported");
```

### Step 6 — JS: armed import confirm

6a. In the state block near the top of the script, directly after
`let clearConfirmTimer = null;`, add:

```js
      let importConfirmTimer = null;
```

6b. Add these two functions directly before the existing `function clearLibrary()`
(mirroring its arm/reset pattern):

```js
      function requestImport() {
        if (!snippets.length || elements.importButton.dataset.confirming) {
          resetImportButton();
          elements.importFile.click();
          return;
        }
        elements.importButton.dataset.confirming = "true";
        elements.importButton.textContent = "Replaces All - Sure?";
        showToast("Import replaces your library");
        importConfirmTimer = window.setTimeout(resetImportButton, 4000);
      }

      function resetImportButton() {
        window.clearTimeout(importConfirmTimer);
        importConfirmTimer = null;
        delete elements.importButton.dataset.confirming;
        elements.importButton.textContent = "Import JSON";
      }
```

6c. In the listener wiring near the bottom, replace:

```js
      elements.importButton.addEventListener("click", () => elements.importFile.click());
```

with:

```js
      elements.importButton.addEventListener("click", requestImport);
```

### Step 7 — smoke: update SMOKE-EXPORT to the new contract

In `scripts/smoke.swift`, replace the entire SMOKE-EXPORT block (from the comment
`// SMOKE-EXPORT:` through `print("SMOKE-EXPORT keys OK")` inclusive) with:

```swift
// SMOKE-EXPORT: the Export button hands the full library across the bridge as
// {type:"export", json:...} for the native save panel (PLAN-export-backup).
let exportBefore = bridge.messages.count
_ = js("document.getElementById('exportButton').click(); true")
guard spin(seconds: 5, until: { bridge.messages.count > exportBefore }) else {
    fail("SMOKE-EXPORT: no bridge message after Export click")
}
let exportMessage = bridge.messages.last!
expect("SMOKE-EXPORT type", exportMessage["type"] as? String ?? "<missing>", "export")
guard let exportedJSON = (exportMessage["json"] as? String)?.data(using: .utf8),
      let exportedArray = try? JSONSerialization.jsonObject(with: exportedJSON) as? [[String: Any]] else {
    fail("SMOKE-EXPORT: payload is not a JSON array of objects")
}
expect("SMOKE-EXPORT count", exportedArray.count, 5)
for key in ["id", "title", "category", "body", "favorite", "createdAt", "updatedAt"] {
    guard exportedArray[0][key] != nil else { fail("SMOKE-EXPORT: exported drop missing key \(key)") }
}
print("SMOKE-EXPORT keys OK")
```

The only semantic changes: expected `type` becomes `"export"`, and the payload field
becomes `["json"]` instead of `["text"]`. This is the pre-authorized assertion change for
this plan; nothing else in the suite may be altered.

### Step 8 — smoke: add the import-arming assertions

Insert this block between the SMOKE-EXPORT block and the SMOKE-FAVORITE block:

```swift
// SMOKE-IMPORT-ARM: with a non-empty library, the first Import click arms a
// confirmation instead of opening the picker (destructive-replace guard).
expect("SMOKE-IMPORT-ARM", jsString("""
(() => { const b = document.getElementById('importButton'); b.click(); return (b.dataset.confirming === 'true' && b.textContent !== 'Import JSON') ? 'ARMED' : 'NOT_ARMED:' + b.textContent; })()
"""), "ARMED")
_ = js("(() => { const b = document.getElementById('importButton'); b.click(); return true; })()")
expect("SMOKE-IMPORT-RESET", jsString("document.getElementById('importButton').textContent"), "Import JSON")
```

(The second click takes the picker path; headless there is no open-panel handler, so no
panel appears — the assertion only checks the button reset.)

### Step 9 — run the gate

```sh
zsh scripts/verify.sh
```

Expected: all SMOKE lines OK including the renamed SMOKE-EXPORT and new
SMOKE-IMPORT-ARM/RESET, then `VERIFY GREEN`, exit 0.

## Edge cases a weaker model would miss

- **WKWebView will never honor `<a download>` here — that's WHY the native message must be
  the first line of `exportJson`.** The blob/anchor code after the native return is the
  browser-dev fallback (opening `index.html` directly in Safari/Chrome still exports). It is
  not dead code; do not "clean it up".
- **`NSApp.activate(ignoringOtherApps: true)` before `panel.begin` is load-bearing.** The
  app is an `LSUIElement` accessory; without activation the save panel can open BEHIND the
  frontmost app and Export looks like it did nothing. Don't remove it as redundant.
- **The transient popover closes when the save panel takes key focus. That is expected, not
  a bug to fix.** The export still completes: `WebViewController` and its WKWebView outlive
  popover visibility (see the `didLoad` guard in `loadIfNeeded()`).
- **Don't chase the "Exported" toast in manual testing.** The callback fires while the
  popover is hidden and the toast expires in ~1.9 s (see `showToast` timers). The success
  signal is the file on disk. Do not add state-holding to re-show the toast.
- **`[.json]` requires the `UniformTypeIdentifiers` import (Step 1)** or the build fails
  with an unresolved `.json` member. The compile error is your signal you skipped Step 1.
- **`panel.begin`'s completion already runs on the main thread and the write is tiny** —
  do not wrap it in `DispatchQueue` ceremony.
- **The empty-library branch in `requestImport` (`!snippets.length`) must stay.** With
  nothing to lose there is nothing to confirm; forcing two clicks on an empty library makes
  first-run restore feel broken.
- **Button label length:** "Replaces All - Sure?" fits the half-width footer button at its
  12 px / weight-780 styling. Don't make the label longer.
- **`resetImportButton()` is called at the top of the picker branch on purpose** — it
  clears the pending timeout so a stale timer can't flip the label back mid-picker.
- **Smoke placement:** SMOKE-IMPORT-ARM requires a non-empty library, which is guaranteed
  at its specified position (5 drops exist after SMOKE-ADD/PERSIST). Moving it after
  SMOKE-DELETE still works (4 drops) but keep the specified position so the suite reads in
  execution order.

## Acceptance criteria

1. `zsh scripts/verify.sh` exits 0; output contains `SMOKE-EXPORT type OK`,
   `SMOKE-IMPORT-ARM OK`, `SMOKE-IMPORT-RESET OK`, `SMOKE OK`, `VERIFY GREEN`.
2. `git status --porcelain` shows exactly: `index.html`, `macos/DewdropsApp.swift`,
   `scripts/smoke.swift`.
3. Manual (dev build, observable):
   **Before mutating anything: this build shares its data store with any installed copy
   (same bundle id `com.dewflash.dewdrops`). Export a backup first; re-import it when done
   (see AGENTS.md house rules).**
   - Launch `build/Dewdrops.app`, open the popover, click **Export JSON** → a save panel
     appears frontmost; save to `~/Desktop/dewdrops-test.json`; PASS = file exists and
     `python3 -m json.tool ~/Desktop/dewdrops-test.json` exits 0 showing an array.
   - Click **Import JSON** once → button text changes to `Replaces All - Sure?` and a toast
     appears; wait 4+ seconds → button text returns to `Import JSON` without any picker.
   - Click **Import JSON** twice → file picker opens; choose the exported file → toast
     `Library imported`; drops match what was exported.
   - Quit the app when finished (right-click the menu bar droplet → Quit Dewdrops).

Suggested commit message:

```
feat: native file export and guarded import for backups
```
