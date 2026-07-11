# PLAN-first-open — instant dark popover, search autofocus, Esc to close

- **Rank:** 3 of 5
- **Dependencies:** run AFTER PLAN-verify (the gate must exist). Independent of PLAN-export-backup and PLAN-duplicate-drop.
- **Effort:** ~45 minutes
- **Files touched:** `macos/DewdropsApp.swift`, `index.html`, `scripts/smoke.swift` (assertions added only). **Nothing else.**

## Goal

The product promise is "a snippet is never more than two clicks away — instantly". Today the
first seconds undercut it, all confirmed in code:

1. **Lazy load on first click:** `statusItemClicked` calls `webViewController.loadIfNeeded()`
   only when the popover first opens (`macos/DewdropsApp.swift`), so the very first open pays
   the whole WKWebView + page load.
2. **White flash:** the page is dark (`index.html` body background) but WKWebView paints its
   default white background until content renders — a white 430×560 rectangle flashes inside
   the popover.
3. **Can't type immediately:** keyboard focus is not in the search field when the popover
   opens; the user must click the field before typing.
4. **No Esc:** Escape neither closes the editor/settings panels nor dismisses the popover.

Fixes: preload at launch, dark background + dark popover chrome, activate-and-focus on open,
and an Esc handler that routes through the existing native bridge.

## Steps

### Step 0 — feasibility probe for the one non-public API (read this first)

Step 3 uses `setValue(false, forKey: "drawsBackground")` — the long-standing WebKit KVC key
for disabling WKWebView's default white background. It is not public API. The failure mode,
if WebKit ever drops the key, is an `NSUnknownKeyException` **crash at launch**.

Probe: after completing Steps 1–3, build and launch once
(`/bin/zsh scripts/build-mac-app.sh && open build/Dewdrops.app`). If the app crashes on
launch (no droplet appears in the menu bar; crash report mentions
`valueForUndefinedKey` / "not key value coding-compliant"): **remove the single `setValue`
line, log the observation to `BLOCKERS.md`, and continue with the rest of this plan.** Do
not substitute a different API, do not add exception handling, do not improvise.

### Step 1 — Swift: preload the page at launch

In `applicationDidFinishLaunching` (class `AppDelegate`), which currently reads:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
    }
```

append two statements so it becomes:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        webViewController.loadIfNeeded()
        webViewController.onCloseRequest = { [weak self] in
            self?.popover.performClose(nil)
        }
    }
```

(`loadIfNeeded()` touches only the lazy `webView`, never `self.view`, so calling it before
the popover ever shows is safe — `loadView` later assigns that same instance as the view.)

### Step 2 — Swift: dark popover chrome

In `configurePopover()`, after `popover.contentViewController = webViewController`, add:

```swift
        popover.appearance = NSAppearance(named: .darkAqua)
```

### Step 3 — Swift: kill the white background (the probed line)

In the `webView` lazy initializer inside `WebViewController`, after `view.uiDelegate = self`,
add:

```swift
        view.setValue(false, forKey: "drawsBackground")
```

Note the receiver: inside that closure the WKWebView is the local constant `view` (verify by
reading the initializer: `let view = WKWebView(frame:configuration:)`). Referencing `webView`
there instead would be a use of the lazy var inside its own initializer.

### Step 4 — Swift: activate and focus on open

Replace the else-branch of `statusItemClicked`, currently:

```swift
        if popover.isShown {
            popover.performClose(sender)
        } else {
            webViewController.loadIfNeeded()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
```

with:

```swift
        if popover.isShown {
            popover.performClose(sender)
        } else {
            webViewController.loadIfNeeded()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            webViewController.focusSearch()
        }
```

### Step 5 — Swift: focusSearch, close hook, and the "close" bridge case

5a. In `WebViewController`, directly after the `private var didLoad = false` property, add:

```swift
    var onCloseRequest: (() -> Void)?
```

5b. Add this method directly after `loadIfNeeded()`:

```swift
    func focusSearch() {
        view.window?.makeFirstResponder(webView)
        webView.evaluateJavaScript("window.dewdropsFocusSearch && window.dewdropsFocusSearch();")
    }
```

5c. In the message switch in `userContentController(_:didReceive:)`, add a case before
`default:` (if a `case "export":` exists there from another plan, keep it — just add
this one):

```swift
        case "close":
            onCloseRequest?()
```

### Step 6 — JS: focus hook and Escape handling

In `index.html`, directly after the line
`window.dewdropsNativeCopied = () => showToast("Copied");`
(if `window.dewdropsNativeExported = ...` from another plan is also there, insert after
both), add:

```js
      window.dewdropsFocusSearch = () => {
        if (elements.editorPanel.classList.contains("active") || elements.managePanel.classList.contains("active")) return;
        elements.searchInput.focus();
        elements.searchInput.select();
      };

      document.addEventListener("keydown", (event) => {
        if (event.key !== "Escape") return;
        if (elements.editorPanel.classList.contains("active")) {
          closeEditor();
          return;
        }
        if (elements.managePanel.classList.contains("active")) {
          elements.managePanel.classList.remove("active");
          return;
        }
        postNativeMessage({ type: "close" });
      });
```

### Step 7 — smoke: add the contract assertions

In `scripts/smoke.swift`, insert this block directly after the SMOKE-PERSIST block (after
its `expect("SMOKE-PERSIST", ...)` line) and before the SMOKE-EXPORT block:

```swift
// SMOKE-FOCUS-HOOK: the native side calls this on popover open; it must exist.
expect("SMOKE-FOCUS-HOOK", jsString("typeof window.dewdropsFocusSearch"), "function")

// SMOKE-ESC-EDITOR: Escape closes an open editor panel without touching the popover.
expect("SMOKE-ESC-EDITOR", jsString("""
(() => { document.getElementById('newButton').click(); document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); return document.getElementById('editorPanel').classList.contains('active') ? 'STILL_OPEN' : 'CLOSED'; })()
"""), "CLOSED")

// SMOKE-ESC-CONTRACT: Escape with no panel open posts {type:"close"} to the bridge.
let escBefore = bridge.messages.count
_ = js("document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); true")
guard spin(seconds: 5, until: { bridge.messages.count > escBefore }) else {
    fail("SMOKE-ESC-CONTRACT: no bridge message after Escape")
}
expect("SMOKE-ESC-CONTRACT type", bridge.messages.last!["type"] as? String ?? "<missing>", "close")
```

These are additive; no existing assertion changes in this plan.

### Step 8 — run the gate

```sh
zsh scripts/verify.sh
```

Expected: all previous SMOKE lines plus `SMOKE-FOCUS-HOOK OK`, `SMOKE-ESC-EDITOR OK`,
`SMOKE-ESC-CONTRACT type OK`, then `VERIFY GREEN`, exit 0.

## Edge cases a weaker model would miss

- **Statement order in `statusItemClicked` is load-bearing:** `activate` BEFORE `show`
  (activating after can shift key windows and instantly transient-close the popover on some
  macOS versions); `focusSearch()` AFTER `show` (before it, `view.window` is nil — the
  popover window doesn't exist yet — so `makeFirstResponder` is a no-op and the JS focus
  fires into a view that isn't key, losing focus).
- **The Esc handler checks panels BEFORE posting "close".** Otherwise Escape inside the
  editor closes the whole popover and throws away the user's unsaved snippet text — the
  exact dead-end this plan removes.
- **Esc is handled in the page, not with an NSEvent monitor, on purpose.** WKWebView
  consumes keyDown events; a native local monitor would race the web view and double-handle.
  The bridge message is the reliable single path.
- **In-browser dev behavior is correct as written:** opening `index.html` in Safari,
  `postNativeMessage` returns false for "close" and Escape (outside panels) does nothing.
  A browser tab must not try to close itself; don't "fix" this.
- **`focusSearch` deliberately declines to steal focus while a panel is open** (the guard on
  editor/manage `active` classes). Reopening the popover mid-edit must not yank the cursor
  out of the editor body.
- **`searchInput.select()` (not just `.focus()`)** — reopening with a stale query means the
  first keystroke replaces it; without `select()` the user types into the tail of the old
  query and sees zero results.
- **Preload costs a WebContent process (~tens of MB) from launch.** Accepted tradeoff for an
  always-running menu bar app; do not add lazy-unload cleverness later in this plan.
- **`NSAppearance(named:)` is failable and `popover.appearance` accepts an optional** — the
  plain assignment compiles; don't force-unwrap.
- **The right-click Quit path must keep working:** `statusItemClicked` early-returns into
  `showStatusMenu()` on `.rightMouseUp` BEFORE the edited else-branch — don't restructure
  that guard while editing.

## Acceptance criteria

1. `zsh scripts/verify.sh` exits 0; output contains `SMOKE-FOCUS-HOOK OK`,
   `SMOKE-ESC-EDITOR OK`, `SMOKE-ESC-CONTRACT type OK`, `SMOKE OK`, `VERIFY GREEN`.
2. `git status --porcelain` shows exactly: `macos/DewdropsApp.swift`, `index.html`,
   `scripts/smoke.swift`.
3. Manual (dev build, observable — quit any other running Dewdrops copy first):
   - Launch `build/Dewdrops.app`; droplet appears in menu bar (Step 0 probe: no crash).
   - FIRST click on the droplet: popover appears already dark with cards rendered — no
     white rectangle, no visible loading beat.
   - With another app frontmost, click the droplet and type `bug` immediately (no clicking
     inside the popover first): the grid filters live as you type.
   - Press Esc: popover closes. Reopen, click `+`, press Esc: editor closes, popover stays
     open; press Esc again: popover closes.
   - Right-click the droplet → Quit Dewdrops still quits (regression check).

Suggested commit message:

```
feat: instant dark popover with search autofocus and Esc close
```
