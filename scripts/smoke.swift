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

// SMOKE-LOOKS: all six looks are available in Settings, the selected look
// persists independently, and switching it never writes the snippet library.
_ = js("localStorage.setItem('dewdrops.look.v1', 'mono'); true")
bridge.loaded = false
webView.reload()
guard spin(seconds: 15, until: { bridge.loaded }) else {
    fail("SMOKE-LOOKS: removed-look migration reload never finished", exitCode: 2)
}
expect("SMOKE-LOOKS removed mono", jsString("""
document.documentElement.dataset.look + ':' + localStorage.getItem('dewdrops.look.v1')
"""), "original:original")
expect("SMOKE-LOOKS default", jsString("document.documentElement.dataset.look"), "original")
expect("SMOKE-LOOKS choices", jsString("""
[...document.querySelectorAll('[data-look-value]')].map((button) => button.dataset.lookValue).join(',')
"""), "original,native,paper,slate,pinboard,wash")
expect("SMOKE-LOOKS panel", jsString("""
(() => {
  document.getElementById('manageButton').click();
  const tab = document.querySelector('[data-settings-tab="appearance"]');
  const pane = document.querySelector('[data-settings-pane="appearance"]');
  return tab.getAttribute('aria-selected') + ':' + pane.hidden + ':' + document.getElementById('managePanel').classList.contains('active');
})()
"""), "true:false:true")
expect("SMOKE-LOOKS tabs", jsString("""
(() => {
  const categories = document.querySelector('[data-settings-tab="categories"]');
  const appearance = document.querySelector('[data-settings-tab="appearance"]');
  categories.click();
  const categoriesState = categories.getAttribute('aria-selected') + ':' + document.querySelector('[data-settings-pane="categories"]').hidden;
  appearance.click();
  const appearanceState = appearance.getAttribute('aria-selected') + ':' + document.querySelector('[data-settings-pane="appearance"]').hidden;
  return categoriesState + ':' + appearanceState;
})()
"""), "true:false:true:false")
expect("SMOKE-LOOKS cycle", jsString("""
(() => {
  const states = [];
  for (const name of ['original', 'native', 'paper', 'slate', 'pinboard', 'wash']) {
    const button = document.querySelector('[data-look-value="' + name + '"]');
    button.click();
    states.push(document.documentElement.dataset.look + ':' + button.getAttribute('aria-pressed'));
  }
  return states.join('|');
})()
"""), "original:true|native:true|paper:true|slate:true|pinboard:true|wash:true")
expect("SMOKE-LOOKS select", jsString("""
(() => {
  document.querySelector('[data-look-value="native"]').click();
  return [
    document.documentElement.dataset.look,
    localStorage.getItem('dewdrops.look.v1'),
    document.getElementById('countLabel').textContent,
    localStorage.getItem('dewdrops.snippets.v1') === null ? 'SNIPPETS_UNTOUCHED' : 'SNIPPETS_WRITTEN'
  ].join(':');
})()
"""), "native:native:4 drops:SNIPPETS_UNTOUCHED")
bridge.loaded = false
webView.reload()
guard spin(seconds: 15, until: { bridge.loaded }) else {
    fail("SMOKE-LOOKS: reload never finished", exitCode: 2)
}
expect("SMOKE-LOOKS persist", jsString("""
document.documentElement.dataset.look + ':' + document.querySelector('[data-look-value="native"]').getAttribute('aria-pressed')
"""), "native:true")
expect("SMOKE-LOOKS restore", jsString("""
(() => { document.querySelector('[data-look-value="original"]').click(); return document.documentElement.dataset.look + ':' + localStorage.getItem('dewdrops.look.v1'); })()
"""), "original:original")

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

// SMOKE-IMPORT-ARM: with a non-empty library, the first Import click arms a
// confirmation instead of opening the picker (destructive-replace guard).
expect("SMOKE-IMPORT-ARM", jsString("""
(() => { const b = document.getElementById('importButton'); b.click(); return (b.dataset.confirming === 'true' && b.textContent !== 'Import JSON') ? 'ARMED' : 'NOT_ARMED:' + b.textContent; })()
"""), "ARMED")
_ = js("(() => { const b = document.getElementById('importButton'); b.click(); return true; })()")
expect("SMOKE-IMPORT-RESET", jsString("document.getElementById('importButton').textContent"), "Import JSON")

// SMOKE-FAVORITE: starring a card survives the re-render (2 starter favorites + 1).
expect("SMOKE-FAVORITE click", clickInCard(title: "Smoke Test Drop", selector: "[aria-label=\"Toggle favorite\"]"), "CLICKED")
expect("SMOKE-FAVORITE", jsInt("document.querySelectorAll('#snippetList .favorite-on').length"), 3)

// SMOKE-DELETE: deleting the test drop returns the library to the four starters.
expect("SMOKE-DELETE click", clickInCard(title: "Smoke Test Drop", selector: "[aria-label=\"Delete\"]"), "CLICKED")
expect("SMOKE-DELETE", countLabel(), "4 drops")

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

print("SMOKE OK")
exit(0)
