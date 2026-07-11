# PLAN-verify — behavioral smoke suite wired into the verify gate

- **Rank:** 1 of 5 (run FIRST)
- **Dependencies:** none. Every other plan depends on THIS one.
- **Effort:** ~30 minutes
- **Files touched:** `scripts/smoke.swift` (new), `scripts/verify.sh` (one block replaced), `scripts/build-mac-app.sh` (one line added). **Nothing else.**

## Goal

The repo has zero mechanical verification of behavior. `scripts/verify.sh` exists and checks
build + bundle integrity, but nothing proves the app's actual promise: that clicking a card
sends the exact snippet text across the JS→native bridge, that search/filter/add/delete work,
and that the library survives a reload. This plan installs a behavioral smoke suite that
drives the real `index.html` in an offscreen WKWebView — no window ever opens — and makes it a
mandatory part of `verify.sh`. Every later plan gates on this.

**Feasibility is already proven:** this exact `smoke.swift` was run green on this machine on
2026-07-11 (all 20 assertions passed, exit 0). If it fails for you at Step 3 without you having
changed anything: STOP, log to `BLOCKERS.md` per AGENTS.md, and do not improvise fixes to
WebKit behavior.

## Steps

### Step 1 — create `scripts/smoke.swift` with EXACTLY this content

```swift
// Dewdrops behavioral smoke test.
// Loads index.html in an offscreen WKWebView (no window is ever shown), drives the
// UI via JavaScript, and asserts on the observable results, including messages that
// cross the JS -> native "dewdropsNative" bridge.
//
// Usage: swift scripts/smoke.swift [path/to/index.html]
// Exit codes: 0 = all assertions pass, 1 = an assertion failed, 2 = timeout/infra failure.
import AppKit
import WebKit

final class Bridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    var messages: [[String: Any]] = []
    var loaded = false
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: Any] { messages.append(body) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail("navigation failed: \(error.localizedDescription)", exitCode: 2)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail("provisional navigation failed: \(error.localizedDescription)", exitCode: 2)
    }
}

func fail(_ detail: String, exitCode: Int32 = 1) -> Never {
    print("SMOKE FAIL: \(detail)")
    exit(exitCode)
}

func spin(seconds: TimeInterval, until check: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        if check() { return true }
    }
    return check()
}

let htmlPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "index.html"
let htmlURL = URL(fileURLWithPath: htmlPath)
guard FileManager.default.fileExists(atPath: htmlURL.path) else {
    fail("index.html not found at \(htmlURL.path)", exitCode: 2)
}

let bridge = Bridge()
let config = WKWebViewConfiguration()
config.websiteDataStore = .nonPersistent()
config.userContentController.add(bridge, name: "dewdropsNative")
let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 430, height: 560), configuration: config)
webView.navigationDelegate = bridge
webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())

guard spin(seconds: 15, until: { bridge.loaded }) else {
    fail("page never finished loading", exitCode: 2)
}

// Evaluates a JS expression and returns its result, spinning the run loop until
// the completion handler fires. The expression must produce a JSON-serializable
// value (string/number/bool) — never undefined.
func js(_ script: String) -> Any {
    var result: Any?
    var jsError: Error?
    var done = false
    webView.evaluateJavaScript(script) { value, error in
        result = value
        jsError = error
        done = true
    }
    guard spin(seconds: 10, until: { done }) else {
        fail("evaluateJavaScript timed out for: \(script.prefix(80))", exitCode: 2)
    }
    if let jsError { fail("JS error: \(jsError.localizedDescription) in: \(script.prefix(120))", exitCode: 2) }
    return result ?? NSNull()
}

func jsString(_ script: String) -> String {
    guard let value = js(script) as? String else { fail("expected string from: \(script.prefix(80))", exitCode: 2) }
    return value
}

func jsInt(_ script: String) -> Int {
    if let value = js(script) as? Int { return value }
    if let value = js(script) as? Double { return Int(value) }
    fail("expected number from: \(script.prefix(80))", exitCode: 2)
}

func expect(_ label: String, _ actual: String, _ expected: String) {
    guard actual == expected else { fail("\(label): expected \(expected.debugDescription), got \(actual.debugDescription)") }
    print("\(label) OK")
}

func expect(_ label: String, _ actual: Int, _ expected: Int) {
    guard actual == expected else { fail("\(label): expected \(expected), got \(actual)") }
    print("\(label) OK")
}

// Clicks the interactive element matching `selector` inside the card whose exact
// title is `title`. Card order is nondeterministic (starter timestamps race within
// a millisecond), so cards are ALWAYS selected by title, never by index.
// Pass selector "" to click the card itself.
func clickInCard(title: String, selector: String) -> String {
    let titleJSON = String(data: try! JSONSerialization.data(withJSONObject: [title]), encoding: .utf8)!
    let selectorJSON = String(data: try! JSONSerialization.data(withJSONObject: [selector]), encoding: .utf8)!
    return jsString("""
    (() => {
      const title = \(titleJSON)[0];
      const selector = \(selectorJSON)[0];
      const cards = [...document.querySelectorAll('#snippetList .card')];
      const card = cards.find((c) => c.querySelector('.snippet-title').textContent === title);
      if (!card) return 'NO_CARD:' + title;
      const target = selector ? card.querySelector(selector) : card;
      if (!target) return 'NO_TARGET:' + selector;
      target.click();
      return 'CLICKED';
    })()
    """)
}

func countLabel() -> String { jsString("document.getElementById('countLabel').textContent") }
func cardCount() -> Int { jsInt("document.querySelectorAll('#snippetList .card').length") }

// SMOKE-SEED: fresh (non-persistent) storage seeds the four starter drops.
expect("SMOKE-SEED count label", countLabel(), "4 drops")
expect("SMOKE-SEED cards", cardCount(), 4)

// SMOKE-STORAGE: localStorage must work on this file:// origin, or every
// persistence assertion below is meaningless.
expect("SMOKE-STORAGE", jsString("""
(() => { try { localStorage.setItem('smoke.probe', '1'); const v = localStorage.getItem('smoke.probe'); localStorage.removeItem('smoke.probe'); return 'RW:' + v; } catch (e) { return 'ERR:' + e.name; } })()
"""), "RW:1")

// SMOKE-COPY: clicking a card posts {type:"copy"} across the native bridge with
// the exact snippet body (newlines and all).
let messagesBefore = bridge.messages.count
expect("SMOKE-COPY click", clickInCard(title: "Friendly follow-up", selector: ""), "CLICKED")
guard spin(seconds: 5, until: { bridge.messages.count > messagesBefore }) else {
    fail("SMOKE-COPY: no bridge message after card click")
}
let copyMessage = bridge.messages.last!
expect("SMOKE-COPY type", copyMessage["type"] as? String ?? "<missing>", "copy")
expect("SMOKE-COPY text", copyMessage["text"] as? String ?? "<missing>",
       "Hey, just following up on this. No rush, but wanted to keep it on your radar. Thanks.")

// SMOKE-SEARCH: typing in the search field filters the grid; clearing restores it.
expect("SMOKE-SEARCH filtered", jsInt("""
(() => { const i = document.getElementById('searchInput'); i.value = 'follow'; i.dispatchEvent(new Event('input', { bubbles: true })); return document.querySelectorAll('#snippetList .card').length; })()
"""), 1)
expect("SMOKE-SEARCH cleared", jsInt("""
(() => { const i = document.getElementById('searchInput'); i.value = ''; i.dispatchEvent(new Event('input', { bubbles: true })); return document.querySelectorAll('#snippetList .card').length; })()
"""), 4)

// SMOKE-FILTER: category chips filter; "All" restores.
expect("SMOKE-FILTER Replies", jsInt("""
(() => { const chip = [...document.querySelectorAll('#filters .chip')].find((c) => c.textContent === 'Replies'); if (!chip) return -1; chip.click(); return document.querySelectorAll('#snippetList .card').length; })()
"""), 1)
expect("SMOKE-FILTER All", jsInt("""
(() => { const chip = [...document.querySelectorAll('#filters .chip')].find((c) => c.textContent === 'All'); if (!chip) return -1; chip.click(); return document.querySelectorAll('#snippetList .card').length; })()
"""), 4)

// SMOKE-ADD: the editor form creates a drop (requestSubmit runs real form validation).
expect("SMOKE-ADD", jsString("""
(() => {
  document.getElementById('newButton').click();
  if (!document.getElementById('editorPanel').classList.contains('active')) return 'EDITOR_NOT_OPEN';
  document.getElementById('titleInput').value = 'Smoke Test Drop';
  document.getElementById('categoryInput').value = 'SmokeCat';
  document.getElementById('bodyInput').value = 'smoke-body-123';
  document.getElementById('snippetForm').requestSubmit();
  return document.getElementById('countLabel').textContent;
})()
"""), "5 drops")
expect("SMOKE-ADD chip", jsInt("[...document.querySelectorAll('#filters .chip')].filter((c) => c.textContent === 'SmokeCat').length"), 1)

// SMOKE-PERSIST: reload the page; the new drop must come back from localStorage.
bridge.loaded = false
webView.reload()
guard spin(seconds: 15, until: { bridge.loaded }) else {
    fail("SMOKE-PERSIST: reload never finished", exitCode: 2)
}
expect("SMOKE-PERSIST", countLabel(), "5 drops")

// SMOKE-EXPORT: the Export button hands the full library across the bridge.
// At HEAD the page copies the JSON (type:"copy"). PLAN-export-backup.md changes
// this assertion — see that plan for the exact replacement.
let exportBefore = bridge.messages.count
_ = js("document.getElementById('exportButton').click(); true")
guard spin(seconds: 5, until: { bridge.messages.count > exportBefore }) else {
    fail("SMOKE-EXPORT: no bridge message after Export click")
}
let exportMessage = bridge.messages.last!
expect("SMOKE-EXPORT type", exportMessage["type"] as? String ?? "<missing>", "copy")
guard let exportedJSON = (exportMessage["text"] as? String)?.data(using: .utf8),
      let exportedArray = try? JSONSerialization.jsonObject(with: exportedJSON) as? [[String: Any]] else {
    fail("SMOKE-EXPORT: payload is not a JSON array of objects")
}
expect("SMOKE-EXPORT count", exportedArray.count, 5)
for key in ["id", "title", "category", "body", "favorite", "createdAt", "updatedAt"] {
    guard exportedArray[0][key] != nil else { fail("SMOKE-EXPORT: exported drop missing key \(key)") }
}
print("SMOKE-EXPORT keys OK")

// SMOKE-FAVORITE: starring a card survives the re-render (2 starter favorites + 1).
expect("SMOKE-FAVORITE click", clickInCard(title: "Smoke Test Drop", selector: "[aria-label=\"Toggle favorite\"]"), "CLICKED")
expect("SMOKE-FAVORITE", jsInt("document.querySelectorAll('#snippetList .favorite-on').length"), 3)

// SMOKE-DELETE: deleting the test drop returns the library to the four starters.
expect("SMOKE-DELETE click", clickInCard(title: "Smoke Test Drop", selector: "[aria-label=\"Delete\"]"), "CLICKED")
expect("SMOKE-DELETE", countLabel(), "4 drops")

print("SMOKE OK")
exit(0)
```

### Step 2 — wire smoke into `scripts/verify.sh`

In `scripts/verify.sh`, find this block:

```zsh
# --- SMOKE ---
# PLAN-verify.md replaces the next echo line with the mandatory smoke-test run.
# Until that plan lands, no behavioral smoke exists at HEAD.
echo "== verify: smoke — NOT YET INSTALLED (see PLAN-verify.md) =="
```

Replace the whole block (all four lines) with:

```zsh
echo "== verify: smoke =="
swift "$ROOT_DIR/scripts/smoke.swift" "$ROOT_DIR/index.html" || { echo "FAIL: smoke test"; exit 1; }
```

### Step 3 — harden the build script against stale bundles

In `scripts/build-mac-app.sh`, find:

```zsh
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
```

Replace with:

```zsh
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
```

WHY: the build currently layers into an existing `build/Dewdrops.app`, so a renamed or
deleted resource silently survives from a previous build and verify would test a stale
bundle. `$APP_DIR` is defined at the top of that script as `$ROOT_DIR/build/Dewdrops.app`;
the `rm -rf` may target only that path — do not "generalize" it to `build/`.

### Step 4 — run the gate

```sh
zsh scripts/verify.sh
```

Expected: every `SMOKE-* OK` line, then `SMOKE OK`, then `VERIFY GREEN`, exit 0.

## Edge cases a weaker model would miss

- **Card order is nondeterministic — never assert by index.** Each starter gets its
  timestamp from `new Date().toISOString()` inside `makeSnippet` (index.html), and the grid
  sorts by `updatedAt` descending inside `filteredSnippets`. Two starters created 1 ms apart
  swap order between runs (observed in practice: "Bug report shape" rendered first). That is
  why `clickInCard` matches `.snippet-title` text exactly. If an assertion flakes, the fix is
  never "use the first card".
- **Never block the main thread waiting for `evaluateJavaScript`.** Its completion handler
  is delivered on the main thread; a semaphore wait deadlocks forever. That is what `spin()`
  (a RunLoop pump) is for. Do not "simplify" it to `DispatchSemaphore`.
- **`.nonPersistent()` data store is load-bearing twice.** It isolates the smoke run from
  any real data, and it still provides working in-memory `localStorage` across `reload()`
  within one process (proven by SMOKE-PERSIST). Switching to `.default()` would leak state
  between runs and break SMOKE-SEED on the second run.
- **Registering the handler name `dewdropsNative` is the whole point.** The page's
  `postNativeMessage` checks `window.webkit.messageHandlers.dewdropsNative` and takes the
  native path only if present. Removing the handler silently flips the page to
  `navigator.clipboard` and the suite stops testing the app's real contract.
- **Every embedded JS snippet ends with an explicit primitive return.** An IIFE that ends
  without returning yields `undefined`, which surfaces as a nil result or an error from
  `evaluateJavaScript`. Keep that pattern when adding assertions.
- **`requestSubmit()` — not `dispatchEvent(new Event('submit'))`.** `requestSubmit` runs
  real HTML validation and the submit handler's `preventDefault` semantics; a synthetic
  submit event bypasses `required` and would pass even with a broken form.
- **SMOKE-EXPORT tolerates the inert `<a download>` click.** At HEAD, Export also clicks a
  blob anchor; WKWebView without a download delegate ignores it. If SMOKE-EXPORT ever hangs
  there, that is a finding for `BLOCKERS.md` — do not delete the assertion to get green.
- **The suite needs a logged-in macOS GUI session** (WebKit talks to WindowServer). Over
  SSH without a session it may hang or fail with exit 2 — that is an environment problem,
  not a code problem.
- **Do not add `NSApplication` setup or `NSApp.run()`.** The script must exit on its own;
  the RunLoop spin is sufficient (proven green).
- **Exit codes are a contract:** 1 = assertion failed (product bug), 2 = infra/timeout.
  Keep them distinct; `verify.sh` treats any nonzero as a gate failure.

## Acceptance criteria

1. `zsh scripts/verify.sh` exits 0 and prints `SMOKE OK` and `VERIFY GREEN`.
2. Run it a second time immediately: still exits 0 (guards cross-run state leakage).
3. Mutation check — prove the gate has teeth: in `index.html`, temporarily change
   `id="countLabel"` to `id="countLabelX"`; `zsh scripts/verify.sh` must FAIL (nonzero).
   Revert the change; verify must be green again. Do not commit the mutation.
4. `git status --porcelain` shows exactly three changed/new files:
   `scripts/smoke.swift`, `scripts/verify.sh`, `scripts/build-mac-app.sh`.

Suggested commit message:

```
test: add offscreen WebKit smoke suite and wire into verify
```
