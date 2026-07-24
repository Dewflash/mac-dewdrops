# Dewdrops Repository Learning Report

Generated: 2026-07-20

## Evidence Standard

This report is grounded in the repository at `/Users/kevinyongcj/Programming/mac-dewdrops`.
Claims are labelled as:

- **Implemented**: directly evidenced by source, scripts, configuration, release artifacts, or the verification run.
- **Partial**: present, but incomplete, fragile, or not fully verified by the repo.
- **Planned**: described in roadmap documentation but not fully present in the current source state.
- **Inferred**: a reasonable interpretation from evidence, with uncertainty noted.
- **Unknown**: not established by inspected material.

Inspected material includes `AGENTS.md`, `README.md`, all `PLAN-*.md` files, `index.html`, `macos/DewdropsApp.swift`, `macos/Info.plist`, scripts under `scripts/`, `.gitignore`, release artifact listing, and recent Git history. There is no `CLAUDE.md` in the repository.

Current verification status: **Implemented and verified now**. `zsh scripts/verify.sh` initially failed inside the sandbox because Swift could not write to `~/.cache/clang/ModuleCache`; rerunning with normal build permissions passed and printed `VERIFY GREEN`.

## Executive Overview

**Implemented**: Dewdrops is an offline macOS menu-bar snippet shelf. The user clicks a menu-bar droplet, opens a 430 x 560 popover, sees reusable text cards, and clicks a card to copy its exact body text to the system clipboard. The native shell is AppKit and WebKit; the product UI and state live in one `index.html` file. Evidence: `README.md`, `AGENTS.md`, `macos/DewdropsApp.swift:5-8`, `macos/DewdropsApp.swift:73-146`, and `index.html:2474-3198`.

The architecture is deliberately small:

- AppKit creates the menu-bar accessory app, status item, popover, quit menu, native clipboard write, native JSON save panel, and `WKWebView` host.
- WebKit loads a bundled local `index.html`.
- The browser page owns rendering, local storage, search, filtering, add/edit/delete/duplicate, favorites, settings, import parsing, theme selection, and toast feedback.
- A single JS-to-Swift bridge named `dewdropsNative` carries `copy`, `export`, and `close` messages.
- There are no runtime package dependencies, no network services, no backend, and no build system beyond shell scripts plus Apple developer tools.

**Current maturity**: useful and shippable as a small local utility, with strong smoke coverage for its core promise. Release maturity is **partial** because packaged v1.1 artifacts exist, but the formal `RELEASE-QA.md` required by `PLAN-final-polish.md` is absent and there is no `v1.1` tag.

## Repository Map

**Implemented** top-level source and docs:

- `index.html`: entire product UI, styling, state model, storage, rendering, and browser-side behavior.
- `macos/DewdropsApp.swift`: native menu-bar host, popover, WebKit bridge, clipboard/export integration, app icon drawing for the status item.
- `macos/Info.plist`: macOS bundle metadata, version `1.1`, build `2`, bundle id `com.dewflash.dewdrops`, `LSUIElement` accessory mode, minimum macOS `13.0`.
- `scripts/build-mac-app.sh`: builds `build/Dewdrops.app` from source.
- `scripts/smoke.swift`: offscreen WebKit behavioral smoke suite.
- `scripts/verify.sh`: build, bundle, signature, marker, and smoke gate.
- `scripts/package-release.sh`: creates `release/Dewdrops-1.1.zip`, `release/Dewdrops-1.1.dmg`, `release/INSTALL.txt`, and checksums.
- `scripts/render-app-icon.swift`: generates the `.iconset` from `assets/app-icon.png`.
- `assets/app-icon.png`: app icon source.
- `README.md`: install/use/build/quit instructions.
- `AGENTS.md` and `PLAN-*.md`: execution roadmap, invariants, release process, and known traps.

Generated or ignored material:

- `build/`: ignored build output.
- `release/`: ignored binary release output, currently containing v1.0 and v1.1 artifacts.
- `.DS_Store`: ignored local macOS metadata.
- `.claude/`: present as a directory, but no `CLAUDE.md` was found.

## System Architecture

### Native Shell

**Implemented**: `AppDelegate` sets the app as an accessory app, configures a square menu-bar status item, creates a transient popover, preloads the WebView, and wires a close callback from the web page back to the popover. Evidence: `macos/DewdropsApp.swift:10-23`, `macos/DewdropsApp.swift:25-41`.

`statusItemClicked(_:)` has two paths:

- Right click opens a tiny menu with `Quit Dewdrops`.
- Left click toggles the popover, activates the app, shows the popover, then asks the web page to focus search.

Evidence: `macos/DewdropsApp.swift:43-70`.

### WebView Boundary

**Implemented**: `WebViewController` creates a `WKWebView` using the default website data store, registers a `dewdropsNative` script message handler, disables the WebView default background, and loads bundled `index.html` from app resources. Evidence: `macos/DewdropsApp.swift:73-102`.

The default website data store is load-bearing for persistence: because the UI is a local file loaded inside a bundle with stable bundle id, WebKit localStorage persists across app launches. The smoke suite uses `.nonPersistent()` to avoid mutating the user's real library while testing. Evidence: `macos/DewdropsApp.swift:77-79`, `scripts/smoke.swift:46-52`.

### Web App Layer

**Implemented**: `index.html` is both presentation and application logic. It defines CSS variables, all layouts and themes, fixed markup shells for the shelf/editor/settings panels, and a closure containing all state and functions. Evidence: `index.html:1-3201`.

The app has no routing system. The primary screen is the shelf; two panels are toggled with classes:

- `#editorPanel` for new/edit drop.
- `#managePanel` for settings.

Evidence: `index.html:2357-2468`, `index.html:2867-2882`, `index.html:2833-2836`.

### Dependency Direction

The dependency direction is simple and healthy:

1. macOS app loads bundled HTML.
2. HTML sends a small set of native messages.
3. Native code performs platform-only effects and optionally calls tiny JS callbacks.

The native app does not inspect or manage the snippet model. The web page does not directly call AppKit APIs. This keeps the boundary understandable, but it also means `index.html` is large and highly coupled internally.

## Startup and Runtime Flows

### App Launch

1. `NSApplication.shared` is created and assigned an `AppDelegate`.
2. `applicationDidFinishLaunching` sets accessory mode, configures menu-bar icon/popover, preloads the WebView, and installs the web-to-native close callback.
3. `loadIfNeeded()` loads `index.html` exactly once.

Evidence: `macos/DewdropsApp.swift:15-23`, `macos/DewdropsApp.swift:92-102`, `macos/DewdropsApp.swift:198-201`.

**Implemented reliability detail**: preloading reduces first-click delay, and `view.setValue(false, forKey: "drawsBackground")` avoids the white WebView flash. This is verified by code and smoke-adjacent plan evidence, but the no-white-flash observation is not mechanically asserted by `scripts/smoke.swift`.

### Open Shelf

Left-clicking the status item toggles the popover. On open, the app activates itself, shows the popover, and calls `focusSearch()`, which executes `window.dewdropsFocusSearch()` in the page. The JS hook declines to steal focus if the editor or settings panel is open. Evidence: `macos/DewdropsApp.swift:49-56`, `macos/DewdropsApp.swift:104-107`, `index.html:3022-3026`.

### Load Data

At page startup:

1. Appearance is read early in a head script so CSS can render the saved look immediately.
2. Snippets, custom categories, vibe color, and look preference are loaded from localStorage.
3. Vibe and look are applied.
4. The selected settings tab is initialized.
5. `render()` draws filters, cards, settings, datalist options, and the count label.

Evidence: `index.html:7-23`, `index.html:2475-2559`, `index.html:3196-3197`.

### Copy Flow

Clicking a card calls `copySnippet(snippet.body)`. In the packaged app, `postNativeMessage({ type: "copy", text })` succeeds and Swift writes that exact text to `NSPasteboard.general`, then invokes `window.dewdropsNativeCopied`. In a browser fallback environment, the code tries `navigator.clipboard.writeText` and then a hidden textarea `execCommand("copy")`. Evidence: `index.html:2718-2723`, `index.html:2994-3018`, `macos/DewdropsApp.swift:124-151`.

The smoke test asserts that clicking `Friendly follow-up` sends a bridge message with the exact expected text. Evidence: `scripts/smoke.swift:201-211`.

### Add and Edit Flow

`openEditor(id)` opens the same panel for new and existing drops. `saveEditor(event)` normalizes the payload, ensures the category exists, updates or prepends a snippet, saves to localStorage, closes the editor, and re-renders. Evidence: `index.html:2867-2906`.

Validation is partly delegated to HTML attributes: title/category/body have `required`, title has `maxlength="28"`, and category has `maxlength="32"`. Evidence: `index.html:2364-2374`.

### Category Flow

Categories are derived from explicit custom categories plus categories used by snippets. Add, rename, and delete operate on both the category store and affected snippets. Deleting a category moves affected snippets to `Notes`. Evidence: `index.html:2660-2662`, `index.html:2917-2963`.

### Search, Filter, and Sort Flow

`filteredSnippets()` reads the search field, filters by `All`, `Favorites`, or category, searches title/category/body, and sorts favorites first, then newest `updatedAt`. Evidence: `index.html:2664-2673`.

### Export Flow

`exportJson()` stringifies the snippet array. In the packaged app it posts `{ type: "export", json }`; Swift opens `NSSavePanel`, defaults to `dewdrops-library.json`, restricts to JSON, writes the file, and calls `dewdropsNativeExported`. Browser fallback copies the JSON and attempts an anchor download. Evidence: `index.html:3041-3052`, `macos/DewdropsApp.swift:137-140`, `macos/DewdropsApp.swift:153-168`.

### Import Flow

Import is guarded when the current library is non-empty. First click arms the button and warns the user; second click opens the file picker. `importJson(file)` rejects files over 1 MB, parses JSON, requires a top-level array, maps entries through `makeSnippet`, replaces the library, saves, resets filter, renders, and reports errors by toast. Evidence: `index.html:3054-3077`, `index.html:3088-3105`.

### Escape Flow

Escape closes the editor first, then settings, then posts `{ type: "close" }` for Swift to close the popover. Evidence: `index.html:3028-3039`, `macos/DewdropsApp.swift:141-142`.

### Restart Behavior

**Implemented**: snippets, custom categories, vibe color, and look persist in localStorage. Smoke explicitly verifies storage read/write and snippet persistence across reload. Evidence: `index.html:2476-2483`, `index.html:2573-2629`, `scripts/smoke.swift:127-131`, `scripts/smoke.swift:243-249`.

## Module and File Guide

### `index.html`

Purpose: complete app UI and product behavior.

Key responsibilities:

- Early look selection before body render.
- CSS for original, paper, corkboard, whiteboard, scrapbook, passport, field notebook, recipe tin, and legacy/unused-looking native/slate/pinboard/wash styles.
- Static DOM shell for topbar, search, filters, list, editor, settings, toast stack, import input.
- State loading/saving for snippets, categories, vibe, and look.
- Rendering filters, cards, settings controls, and category manager.
- User actions: copy, search, add, edit, delete, duplicate, favorite, export, import, restore starters, clear library, settings tabs, vibe, look.

Inputs: user clicks/typing/file selection, localStorage values, WebKit native bridge availability.

Outputs: DOM changes, localStorage writes, bridge messages, clipboard writes in browser fallback, download attempt in browser fallback, toasts.

Maintainability concerns:

- The file is large: about 3,200 lines, with CSS and JS co-located. This is acceptable for a dependency-free menu-bar utility, but theme CSS is now the largest complexity center.
- CSS contains some older appearance names (`native`, `slate`, `pinboard`, `wash`) while the active look list is `original,paper,corkboard,whiteboard,scrapbook,passport,field,recipe`. This appears to be historical style material and should be documented or pruned cautiously.
- User content uses `textContent` in critical rendering paths, satisfying the repository XSS boundary. Static icon strings use `innerHTML`, as allowed by `AGENTS.md`. Evidence: `index.html:2686-2697`, `index.html:2731-2735`, `index.html:2745-2748`, `index.html:2761-2768`.

### `macos/DewdropsApp.swift`

Purpose: native macOS wrapper.

Key responsibilities:

- Accessory app with no Dock icon.
- Status item and right-click quit menu.
- Transient popover hosting the WebView.
- Load bundled `index.html`.
- Focus the search box after popover open.
- Native clipboard writes.
- Native JSON save panel.
- Handle popover close requests from JS.
- Draw a template droplet status icon.

Maintainability concerns:

- `view.setValue(false, forKey: "drawsBackground")` is a KVC call, not a normal public Swift property. The roadmap accepts it for visual polish but documents it as a possible crash risk if WebKit changes.
- The Swift side trusts the shape of bridge messages but only acts on known `type` values. This is fine for local-only app code.

### `macos/Info.plist`

Purpose: bundle metadata.

Important fields:

- `CFBundleIdentifier`: `com.dewflash.dewdrops`.
- `CFBundleShortVersionString`: `1.1`.
- `CFBundleVersion`: `2`.
- `LSMinimumSystemVersion`: `13.0`.
- `LSUIElement`: true, making it an accessory/menu-bar app.

Evidence: `macos/Info.plist:11-26`.

### `scripts/build-mac-app.sh`

Purpose: reproducible local app build.

Flow:

1. Remove stale `build/Dewdrops.app`.
2. Create bundle directories.
3. Generate iconset with Swift script.
4. Convert iconset to `.icns`.
5. Compile `macos/DewdropsApp.swift` with AppKit and WebKit.
6. Copy plist and `index.html`.
7. Mark executable.
8. Ad-hoc sign the app, ignoring signing failure.

Evidence: `scripts/build-mac-app.sh:4-30`.

Concern: the final codesign line uses `|| true`. `verify.sh` separately requires signature verification, so a failed sign should still be caught later. The build script itself, however, can print an app path even if signing failed.

### `scripts/verify.sh`

Purpose: one-command project gate.

Checks:

- Build succeeds.
- Bundle executable and icon exist.
- Bundled `index.html` matches source.
- `Info.plist` lints.
- Code signature verifies.
- Required markers remain in `index.html`.
- Offscreen WKWebView smoke test passes.

Evidence: `scripts/verify.sh:9-29`.

### `scripts/smoke.swift`

Purpose: behavioral proof without opening windows.

The test loads `index.html` into a non-persistent `WKWebView`, drives JavaScript, and asserts key product contracts:

- Starter drops seed.
- localStorage works.
- Appearance look migration/selection/persistence works.
- Copy sends exact bridge payload.
- Search and category filtering work.
- Add creates a drop and persists across reload.
- Focus hook exists.
- Escape closes editor or posts native close.
- Export sends JSON bridge payload with expected fields.
- Import arms before replacing non-empty library.
- Favorite, delete, and duplicate work.

Evidence: `scripts/smoke.swift:123-315`.

### `scripts/package-release.sh`

Purpose: reproducible release package.

Flow:

1. Read version from `Info.plist`.
2. Build app.
3. Stage `Dewdrops.app` and generated `INSTALL.txt`.
4. Copy `INSTALL.txt` to ignored `release/`.
5. Create ZIP containing the parent `Dewdrops/` folder.
6. Create compressed DMG.
7. Write SHA-256 sums.

Evidence: `scripts/package-release.sh:4-39`.

### `scripts/render-app-icon.swift`

Purpose: generate all required `.iconset` PNG sizes from `assets/app-icon.png`.

Evidence: `scripts/render-app-icon.swift:4-88`.

## Language and Framework Education

Dewdrops uses AppKit as the native app lifecycle and chrome layer. `NSStatusBar.system.statusItem` creates the menu-bar item; `NSPopover` provides the shelf window; `NSPasteboard` handles clipboard writes; `NSSavePanel` handles export. These are platform primitives rather than third-party abstractions.

WebKit is used as a local UI runtime. `WKWebViewConfiguration.userContentController.add(self, name: "dewdropsNative")` installs the bridge. In JavaScript, `window.webkit.messageHandlers.dewdropsNative.postMessage(...)` sends plain objects across that bridge. Swift receives them in `userContentController(_:didReceive:)`, switches on `type`, and performs native effects.

The browser code uses closure-scoped mutable variables rather than classes/modules. This fits `AGENTS.md` style rules and keeps globals limited to four explicit hooks/objects: `window.dewdropsAppearance`, `window.dewdropsNativeCopied`, `window.dewdropsNativeExported`, and `window.dewdropsFocusSearch`.

Rendering is manual DOM construction. The code creates elements with `document.createElement`, assigns classes, assigns user content through `textContent`, and wires event listeners directly. This is less abstract than React/Vue/etc., but it avoids a build system and makes offline packaging trivial.

Persistence is localStorage. It is synchronous, simple, and enough for a small JSON snippet library. There is no migration layer beyond normalizing loaded objects through `makeSnippet` and migrating invalid look values to the default.

## Data Architecture

### Entities

Primary entity: `Snippet`.

Fields from `makeSnippet(input)`:

- `id`: existing id or generated `drop-${Date.now()}-${randomHex}`.
- `title`: string, default `Untitled`, sliced to 28 chars.
- `category`: cleaned category, default `Notes`, sliced to 32 chars.
- `body`: string.
- `favorite`: boolean.
- `createdAt`: ISO timestamp.
- `updatedAt`: ISO timestamp.

Evidence: `index.html:2560-2570`.

Other persisted state:

- `dewdrops.snippets.v1`: snippet array.
- `dewdrops.categories.v1`: custom category array.
- `dewdrops.vibe.v1`: accent color hex.
- `dewdrops.look.v1`: appearance key.

Evidence: `index.html:2476-2483`.

### Validation and Normalization

`makeSnippet` normalizes imported and saved objects. `cleanCategory` trims, collapses whitespace, caps length, and falls back to `Notes`. `normalizeHex` accepts `#rgb`, `rgb`, `#rrggbb`, and `rrggbb`; invalid values become empty and are reset or rejected depending on call site. Evidence: `index.html:2560-2570`, `index.html:2637-2658`.

### Storage and Migration

`loadSnippets()` maps saved arrays through `makeSnippet`; invalid or missing data falls back to starter drops. `loadCategories()` maps saved arrays through `cleanCategory`. The early appearance script resets invalid saved looks to `original`. Evidence: `index.html:15-22`, `index.html:2573-2595`.

There is no schema version migration beyond stable key names and normalization. Given the app size, this is reasonable now, but future schema changes need a careful migration path because localStorage keys are persistence contracts.

### Recovery

Backup/recovery exists through JSON export/import, plus `Copy All JSON` and `Restore Starters`. Import replaces the library and has a two-click guard. Clear library also has a two-click guard. Evidence: `index.html:2461-2464`, `index.html:3041-3129`.

## UI and Product Structure

Implemented surfaces:

- Shelf: brand, count, settings button, search, add button, category chips, card grid/list, export/import footer.
- Editor: title, category, body, cancel/save.
- Settings: appearance tab, categories tab, library tab.
- Toast stack for short feedback.

Card actions:

- Card click: copy body.
- Star: toggle favorite.
- Duplicate: create editable copy with same body/category and unstarred state.
- Edit: open editor.
- Delete: remove card.

Appearances:

- Active choices shown in settings: Original, Paper Shelf, Corkboard, Whiteboard, Scrapbook, Passport Wallet, Field Notebook, Recipe Tin.
- The current CSS also contains older style blocks for `native`, `slate`, `pinboard`, and `wash`; these are not in the current `LOOKS` list.

Accessibility:

- Buttons use `aria-label` for icon-only controls.
- Settings tabs use `role="tablist"`, `role="tab"`, `aria-selected`, and tabpanel hiding.
- Toast stack uses `aria-live="polite"`.
- Gaps: cards are `article` elements with click handlers but no explicit keyboard activation; category rows and custom controls are basic and may not offer full keyboard affordance parity.

## Testing and Reliability

Strongest reliability asset: `scripts/smoke.swift`. It directly exercises important browser behavior in WebKit rather than only linting source. The current gate passed with `VERIFY GREEN` after allowing Swift to write its normal cache.

Covered well:

- Core copy bridge contract.
- Exact copied text for one starter.
- Search/filter/add/persist/export/import guard/favorite/delete/duplicate.
- Look selection and persistence.
- Bundle integrity and signature.

Not covered mechanically:

- Manual visual quality across all themes.
- Keyboard accessibility of card actions.
- Native save panel completion in a visible GUI flow.
- Real `/Applications` install, Gatekeeper/right-click-open path, and DMG user experience.
- Formal release QA rows from `PLAN-final-polish.md`.

High-value next tests:

- A small accessibility smoke: focus order, Enter/Space behavior for card actions, ARIA state transitions.
- A visual geometry smoke for all active looks, especially icon centering and card overflow.
- Import test using a real temporary file in WebKit, if possible without mutating user storage.
- Package smoke that extracts ZIP and verifies `Dewdrops/Dewdrops.app` plus `INSTALL.txt`.

## Build, Install, and Release

Build from source:

```sh
/bin/zsh scripts/build-mac-app.sh
```

Verify:

```sh
zsh scripts/verify.sh
```

Package:

```sh
/bin/zsh scripts/package-release.sh
```

Install from release:

1. Open `release/Dewdrops-1.1.dmg` or extract `release/Dewdrops-1.1.zip`.
2. Drag `Dewdrops.app` to `/Applications`.
3. Launch from Applications.
4. If macOS blocks first launch, right-click the app, choose Open, then confirm Open.

**Implemented** release files exist on disk in ignored `release/`: `Dewdrops-1.1.zip`, `Dewdrops-1.1.dmg`, `INSTALL.txt`, and `SHA256SUMS-1.1.txt`.

**Partial**: `PLAN-final-polish.md` requires `RELEASE-QA.md` and a `v1.1` tag only after a SHIP verdict. Neither exists in the current repo. Therefore v1.1 is packaged, but not formally release-certified according to the repository's own standard.

## Architectural Critique

### Strengths

- Very small dependency surface: no package manager, no server, no runtime network.
- Clear product promise and simple critical path.
- Local-first data ownership aligns with the app's use case.
- Native bridge is small and auditable.
- Smoke tests target behavior in WebKit, the actual UI runtime.
- Build and package scripts make the app reproducible.
- The app preserves the XSS boundary by using `textContent` for user content.

### Risks and Confusing Areas

- `index.html` is now large enough that CSS theme work can accidentally break unrelated behavior.
- Active appearance names and historical CSS names are not fully aligned.
- `build-mac-app.sh` ignores codesign failures, relying on `verify.sh` to catch them.
- localStorage has no quota handling, no export-before-destructive-action automation, and no schema migration system beyond normalization.
- The formal release QA process was not completed in the current repository state.
- Accessibility is functional but not deeply validated.
- The native WebView background KVC line is a known platform fragility.

### Prioritized Improvements

1. Complete formal `RELEASE-QA.md` if the project wants a true `v1.1` SHIP verdict and tag.
2. Add visual smoke coverage for the eight active looks.
3. Add keyboard activation for cards and card actions.
4. Reconcile or remove unused appearance CSS names after confirming no saved users have those look values.
5. Add a tiny migration registry before changing any persistence shape.
6. Make `build-mac-app.sh` fail hard on signing failure, or document why `verify.sh` is the only supported gate.

## Learning Summary

The mental model is: Dewdrops is a local web app wearing a tiny native macOS coat. The native coat gives the product menu-bar presence, a popover, clipboard access, and file export. The web app gives it almost everything else.

A new developer should learn these first:

1. Do not split or modernize the app reflexively; the no-dependency, one-file web UI is an intentional distribution strategy.
2. Treat localStorage keys as user data contracts.
3. Treat `dewdropsNative` as the only native bridge boundary.
4. Use `textContent` for user data.
5. Run `zsh scripts/verify.sh` after changes.
6. Before manual tests that mutate the real library, export a backup because dev and installed copies share WebKit storage under the same bundle id.

A safe first change would be a narrow UI copy/style adjustment in `index.html`, followed by the smoke gate and a quick visual check. A risky first change would be touching persistence keys, bridge message shapes, package signing, or theme-wide CSS without targeted verification.
