# Dewdrops Product and Industry Report

Generated: 2026-07-20

## Evidence Standard

This report is evidence-based from the local repository. It does not include live market research or current competitor pricing because the request did not ask for external market comparison. Comparable workflows are therefore framed as general product categories rather than researched claims.

Status labels:

- **Implemented**: evidenced by code, scripts, configuration, release artifacts, or a green verification run.
- **Partial**: present but incomplete, fragile, or not fully verified by the repo.
- **Planned**: stated in roadmap/docs but not completed in the current repo state.
- **Inferred**: reasoned from evidence, with uncertainty.
- **Unknown**: not established.

## 1. Executive Summary

**One-sentence product description**: **Implemented**: Dewdrops is an offline macOS menu-bar app for saving short snippets and copying them from a compact shelf in one or two clicks.

**Elevator pitch**: Dewdrops keeps the tiny bits of text people reuse all day, such as prompts, replies, support notes, bug-report templates, and install instructions, in a fast local menu-bar shelf. Click the droplet, click a card, and the exact text is on the clipboard.

**Plain-English explanation**: It is a personal text shelf that lives in the macOS menu bar. You add reusable text once, organize it by category, search or filter it later, and click a card whenever you want to paste that text somewhere else.

**Target users**: **Inferred**: people who frequently reuse text on macOS: developers, AI-heavy workers, support operators, founders, writers, students, and anyone with recurring replies or prompt fragments.

**Problem solved**: remembering, finding, and copying reusable text without opening a notes app, searching old chats, or maintaining scattered text files.

**Main value proposition**: speed, locality, and simplicity. The core promise in `AGENTS.md` says a saved snippet is never more than two clicks away and never leaves the machine.

**Strongest differentiator**: **Implemented**: Dewdrops is deliberately offline and menu-bar native, with no account, server, package manager, or sync layer.

**Current stage and verdict**: Dewdrops is a credible small utility with a working v1.1 build and strong smoke coverage for its core flow. It is not yet formally release-certified by its own roadmap because `RELEASE-QA.md` and a `v1.1` tag are absent.

## 2. The Problem and Alternatives

### User Struggle

**Inferred**: Many computer users reuse the same small texts: AI prompts, polite follow-ups, bug report templates, support instructions, onboarding blurbs, commit phrasing, and personal notes. These snippets are often stored in places optimized for writing or archiving, not instant reuse: Notes, text files, clipboard managers, Notion pages, docs, pinned chats, or browser bookmarks.

The friction is small but frequent:

- Opening a larger app.
- Searching in the wrong place.
- Copying slightly wrong text.
- Reconstructing a template from memory.
- Losing useful prompt variants across chats or projects.

### Why It Matters

The problem matters when repetition is high. A single reused line is not enough to justify a product; daily reuse is. Dewdrops is strongest where the user has 10 to 100 short snippets and wants retrieval to feel almost automatic.

### Alternatives

General alternatives include:

- macOS clipboard history tools.
- Text expansion utilities.
- Notes apps.
- Document/wiki tools.
- Browser bookmarks or pinned AI chat prompts.
- Plain text files.

Without external research, this report cannot claim Dewdrops is better than a named competitor. The meaningful product distinction evidenced by the repo is focus: Dewdrops is not a full writing system, sync system, or automation platform. It is a local shelf for fast copy.

### Limits of the Problem Claim

The repo does not contain user research, analytics, interviews, pricing experiments, or market data. Therefore the frequency, urgency, willingness to pay, and segment size are **unknown**. The product pain is plausible, but not validated by repository evidence.

## 3. Users and Use Cases

### Primary User: AI and Prompt-Heavy Mac User

**Inferred** from starter drops and README.

Goal: keep reusable prompts and AI instructions close at hand.

Scenario: the user is writing in ChatGPT, Codex, or another AI tool. They click the Dewdrops menu-bar icon, search `prompt`, click `Polish this prompt`, paste it, and continue.

Value: less repeated typing and fewer lost prompt patterns.

Return motivation: the user improves or adds prompt variants over time.

Not suited for: long prompt libraries that need tagging, version history, team sharing, or rich metadata.

### Secondary User: Support or Operations Worker

**Inferred** from starter `Support` and `Friendly follow-up` drops.

Goal: reuse accurate responses and procedural notes.

Scenario: while replying to a customer, the user filters `Support`, clicks the install note, and pastes it into email or chat.

Value: consistency and speed.

Not suited for: regulated support knowledge bases that require approval workflows, audit logs, macros, or CRM integration.

### Secondary User: Developer

**Inferred** from starter `Bug report shape` and the app's developer-oriented README.

Goal: keep small templates available for issues, PRs, bug reports, and prompts.

Scenario: in GitHub or Slack, the user clicks `Bug report shape` and pastes a five-line issue template.

Value: faster structured communication.

Not suited for: project-wide snippet libraries, code snippets with syntax highlighting, or secret storage.

### Future User: Team or Multi-Device User

**Planned/Inferred only**: The current app has no accounts or sync. A future product could serve teams or multiple Macs, but that would meaningfully change the privacy, reliability, and complexity profile.

### Explicitly Out of Scope Today

Dewdrops should not be used as:

- A password manager.
- A secure notes vault.
- A synced team knowledge base.
- A long-form document manager.
- A clipboard history recorder.

These boundaries matter because the current implementation is localStorage-backed and not encrypted by the app itself.

## 4. Product Experience

### Onboarding and First Value

**Implemented**: A fresh data store seeds four starter drops: `Polish this prompt`, `Friendly follow-up`, `Bug report shape`, and `Install note`. Evidence: `index.html:2485-2510`.

The first value moment is immediate: open shelf, click card, paste. The smoke test verifies four starter cards load and that a card click sends the exact copy payload.

### Main Surface

**Implemented**: The shelf has a topbar with brand/count/settings, a search bar with add button, horizontal category filters, card grid/list, and export/import footer. Evidence: `index.html:2320-2355`.

The fixed popover size is 430 x 560 in both Swift and CSS. Evidence: `macos/DewdropsApp.swift:5-8`, `index.html:47-50`.

### Editor

**Implemented**: The editor supports title, category, and body. New drops and edits use the same panel. Save writes to localStorage and re-renders the shelf. Evidence: `index.html:2357-2379`, `index.html:2867-2906`.

### Settings

**Implemented**:

- Appearance: eight looks plus vibe color.
- Categories: add/rename/delete.
- Library: restore starters, copy all JSON, clear library.

Evidence: `index.html:2382-2468`.

### Feedback, Error, and Recovery States

**Implemented**:

- Toasts for copied, exported, invalid JSON, too-large file, library imported, category actions, clear confirmation, and save/delete/duplicate feedback.
- Empty list states for no drops and no matching drops.
- Import replacement guard.
- Clear library two-click guard.

Evidence: `index.html:2705-2710`, `index.html:3054-3129`, `index.html:3131-3141`.

### What Feels Trustworthy

The app's value moments are direct and explainable. The product has no account setup, no remote service, and no hidden sync state. Its core operations are visible in code and exercised in smoke tests.

### What May Feel Fragile

- App is ad-hoc signed and not notarized, so first launch may require right-click Open.
- Formal release QA is missing in the repo state.
- The settings panel has many appearance choices in a small popover; discoverability may be fine for casual use but could feel dense.
- HTML5 validation behavior in WebKit was called out by the roadmap as possibly needing honest manual QA.

## 5. Product Capabilities

### Fast Card Copy

Status: **Implemented and verified**.

What it does: click a card and its body text is copied to the clipboard.

Who benefits: all users.

How it works: card click posts `{ type: "copy", text }` to Swift; Swift writes `text` to `NSPasteboard`.

Limitation: no rich text, images, variables, or multi-format clipboard payloads.

### Search and Category Filters

Status: **Implemented and verified**.

What it does: search across title/category/body; filter by all, favorites, or category.

Limitation: simple substring search only. No fuzzy search, tags, multiple filters, or saved searches.

### Add and Edit Drops

Status: **Implemented and smoke-tested for add**; edit is implemented but not separately asserted by smoke.

What it does: user creates or updates title/category/body.

Limitation: no undo/version history.

### Favorites

Status: **Implemented and verified**.

What it does: marks cards as favorite and sorts favorites first.

Limitation: no pin order or manual sorting.

### Duplicate

Status: **Implemented and verified**.

What it does: creates an unstarred copy with the same body/category and title suffix ` copy`.

Limitation: suffix behavior is intentionally simple; repeated duplication can produce similar names.

### Delete and Clear

Status: **Implemented**; delete smoke-tested, clear implemented with confirmation.

What it does: remove individual drops or clear the full library.

Limitation: no undo. Export is the recovery mechanism.

### JSON Export and Import

Status: **Implemented and smoke-tested for bridge contract and guard**.

What it does: export the snippet library as JSON; import a JSON array to replace the library.

Limitation: import only covers snippets, not custom categories, vibe, or appearance settings as a complete backup bundle. Custom categories are reconstructed from imported snippets and explicit categories are separate state.

### Appearance and Vibe

Status: **Implemented and smoke-tested for look selection/persistence**.

What it does: switch visual shelf style and accent color without changing saved drops.

Limitation: visual QA is not fully automated; some theme CSS is complex and historical names remain.

### Native Packaging

Status: **Implemented**.

What it does: produce app bundle, ZIP, DMG, install text, and SHA-256 sums.

Limitation: not notarized; formal release QA file/tag are absent.

## 6. Product and Technical Architecture

### Platforms and Technologies

**Implemented**:

- macOS 13+.
- AppKit.
- WebKit.
- Plain HTML/CSS/JavaScript.
- localStorage.
- Shell scripts.
- Swift scripts.
- Ad-hoc code signing.

No runtime services, backend, package manager, telemetry, authentication, network requests, database server, or cloud sync are present.

### Data Flow

User input to saved state:

1. User fills editor.
2. JS normalizes title/category/body.
3. Snippet array mutates.
4. JSON is written to localStorage under `dewdrops.snippets.v1`.
5. UI re-renders from in-memory state.

Saved state to copied output:

1. User clicks a card.
2. JS passes `snippet.body` to copy function.
3. Packaged app sends native bridge message.
4. Swift writes exact text to pasteboard.
5. User pastes into another app.

Backup flow:

1. JS serializes snippets to JSON.
2. Packaged app sends native export message.
3. Swift opens save panel and writes the file.

### Sources of Truth

Primary source of truth at runtime is the in-memory `snippets` array. Durable source of truth is localStorage. There is no remote authority.

### Privacy and Security

**Implemented**: No network code is visible in app source; `AGENTS.md` forbids fetch/XHR/WebSocket. Data stays local to the Mac per README and architecture.

**Partial**: Local-only does not mean encrypted. The app does not implement custom encryption, authentication, lock screen, redaction, or secret handling. It should not claim vault-like security.

### Reliability and Scalability

Dewdrops is designed for a small personal library. localStorage and full re-rendering are fine for that scale. Very large snippet sets may expose performance, quota, and UI scanning limits.

Operational cost is effectively zero because there is no server. Maintenance cost is concentrated in macOS/WebKit compatibility, packaging, and the large `index.html` surface.

## 7. Differentiation and Positioning

### Comparable Workflows

Dewdrops overlaps with clipboard managers, text expanders, note apps, prompt managers, and team knowledge bases.

### Meaningful Differences Evidenced Today

- Offline by design.
- Mac menu-bar first.
- One-click card copy.
- No account or cloud setup.
- Small, transparent data model.
- User-owned JSON backup.
- Appearance choices give the utility personality without changing data.

### Defensibility

**Experiential defensibility**: moderate. A fast menu-bar shelf can become habit-forming if it is consistently faster than alternatives.

**Technical defensibility**: low to moderate. The implementation is intentionally simple and could be copied by another developer.

**Operational defensibility**: low today because there is no distribution, support, sync, data network, or ecosystem.

**Privacy positioning**: credible, as long as claims stay narrow: local/offline, not encrypted vault.

### What Competitors Could Copy Easily

The core local snippet shelf, search, categories, and JSON export/import are straightforward. The harder part is not engineering complexity; it is getting the workflow to feel reliable enough that users build a habit.

### Evidence That Would Validate Positioning

- Users keep Dewdrops running for weeks.
- Users add their own snippets rather than only using starters.
- Daily or weekly copy actions are high.
- Users export backups before upgrades.
- Users say Dewdrops replaces a heavier app or scattered prompt file.

## 8. Maturity, Quality, and Trust

### What Genuinely Works

**Implemented and verified**:

- Build gate passes.
- Core card copy bridge.
- Starter drops.
- localStorage persistence.
- Search and filters.
- Add, favorite, delete, duplicate.
- Look selection and persistence.
- Export bridge payload.
- Import confirmation guard.
- App bundle code signature verification.

### Prototype-Level or Partial Areas

- Formal release QA missing.
- No notarization.
- No automated visual regression checks.
- No deep accessibility test coverage.
- No data migration framework beyond current normalization.
- No observability or crash reporting.

### Where Users May Lose Trust

- macOS first-launch warning due to ad-hoc signing.
- Data loss if users clear/import without backups, though guards reduce accidental actions.
- Confusion if import replaces snippets but not every preference as a full settings backup.
- Visual regressions in one of the many themes.

### Does Implementation Support Product Claims?

Yes for the core claim: fast local snippet copy. The smoke suite directly exercises it. The repo also supports the offline/local claim. It should avoid stronger claims like team readiness, enterprise support, secure vault, full backup of all preferences, or market-leading prompt management.

## 9. Feasibility and Longevity

### Technical Feasibility

High. The product is already implemented with stable platform primitives. The technical scope is modest.

### Dependency and Vendor Risk

Low server/vendor risk because there is no cloud. Moderate platform risk because it depends on macOS, AppKit, WebKit, and localStorage behavior for file-loaded content. One known fragile point is the WebView background KVC call.

### Operating Costs

Near zero for the app itself. Distribution cost depends on whether the project later wants notarization, paid developer signing, update hosting, or support.

### Licensing and Regulatory Risk

Unknown from repository evidence. No third-party runtime dependencies are present. Privacy/regulatory risk is low if the app remains local-only and avoids collecting data, but this is not a legal assessment.

### Maintenance Burden

Current maintenance burden is low but CSS complexity is rising. The single-file architecture is lovely for distribution and a bit prickly for theme iteration.

### Likely Failure Modes

- macOS/WebKit behavior changes.
- localStorage corruption or quota issues.
- Accidental data replacement by import/clear.
- Visual regressions in compact layouts.
- User confusion around install warnings.
- Project drift away from the two-click core promise.

### What Would Make It Durable

- Formal release QA and signed tags.
- Notarized builds if distributed beyond personal use.
- Automated visual smoke tests for themes.
- Better backup/restore semantics, possibly including categories/settings.
- Keyboard accessibility and simple onboarding polish.
- A clear promise: "local snippet shelf," not "knowledge platform."

## 10. Roadmap and Priorities

### Minimum Credible Release Requirements

1. Complete `RELEASE-QA.md` honestly against `/Applications/Dewdrops.app`.
2. Tag `v1.1` only if the verdict is SHIP.
3. Keep `zsh scripts/verify.sh` green at final HEAD.
4. Confirm install path from DMG/ZIP still works.

### Highest-Value User-Facing Work

1. Stronger keyboard accessibility: navigate and copy without mouse.
2. More obvious backup/restore language, including what import replaces.
3. Theme polish only where it protects clarity and click targets.
4. Optional quick-copy keyboard shortcut if it can be done without bloating the product.

### Technical Foundations

1. Visual regression harness for active looks.
2. Persistence migration helper before adding schema fields.
3. Release QA artifact and tag discipline.
4. Package verification script that checks ZIP/DMG contents automatically.

### Defer or Avoid

- Cloud sync until there is clear user pull.
- Team/workspace features.
- Rich editor or markdown rendering.
- Plugin systems.
- AI-generated snippets inside the app.
- Anything that adds a backend before the local utility is validated.

### User Validation

Run tiny studies:

- Watch five users install it.
- Ask them to add five real snippets.
- Measure whether they still use it after a week.
- Ask which snippet they copied most.
- Ask what nearly made them stop using it.

## 11. Communication Pack

### Website Introduction

Dewdrops is a tiny offline Mac menu-bar shelf for the text you reuse all day. Save prompts, replies, notes, and templates, then copy any one of them with a click.

### User-Facing Product Explanation

Dewdrops sits in your Mac menu bar. Click the droplet to open your shelf, search or filter your saved drops, and click a card to copy its text. You can add, edit, duplicate, favorite, import, and export drops. Everything stays on your Mac.

### Technical Explanation for Industry Peers

Dewdrops is a local-first AppKit/WebKit utility. AppKit owns the accessory app shell, status item, transient popover, native clipboard, and JSON save panel. A bundled single-file HTML/CSS/JS app owns rendering and state. Snippets persist in WebKit localStorage under stable keys, and a small `dewdropsNative` bridge handles copy, export, and close messages. The project has no runtime dependencies and no backend.

### 30-Second Elevator Pitch

People keep rewriting or hunting for the same small pieces of text: prompts, follow-ups, support notes, bug templates. Dewdrops puts those snippets in a fast offline Mac menu-bar shelf. Open it, click a card, paste. It is intentionally small, local, and boring in the best way: no account, no server, no sync mystery.

### Three User Stories

1. As an AI-heavy worker, I want my best prompts one click away so I do not rebuild them from memory.
2. As a support operator, I want reusable replies and install notes so I can respond consistently.
3. As a developer, I want bug report and review templates close by so I can structure messages quickly.

### Frequently Asked Questions

**Does Dewdrops need an internet connection?**
No. The app is designed to run offline.

**Where is my data stored?**
In local WebKit storage on your Mac, using the app's bundle id.

**Can I back up my drops?**
Yes. Export JSON saves your snippet library to a file.

**Does import merge with my current library?**
No. Import replaces the library and asks for confirmation first.

**Does it sync across Macs?**
No. Sync is not implemented.

**Is it notarized?**
No. The README documents the right-click Open path for first launch.

**Should I store secrets in it?**
No. It is a convenience shelf, not a password manager or encrypted vault.

### Why This Matters

Small repeated text has a strange way of becoming invisible work. Dewdrops is useful because it removes that tiny friction without asking users to adopt a whole knowledge system. Its best version is not bigger; it is calmer, faster, and more trustworthy.

### Honest Current Limitations

- macOS only.
- Local only, no sync.
- Not notarized.
- No rich text or variables.
- No undo/version history.
- Import replaces the snippet library.
- Formal release QA artifact is missing in the current repo.
- Very large libraries are not proven.

## 12. Final Assessment

**Strongest case**: Dewdrops has a crisp job, a minimal local architecture, and verified core behavior. It does one useful thing with very little machinery.

**Strongest criticism**: It is still a small personal utility, not a validated product business or mature release process. Its differentiation is experiential, not technically hard to copy.

**Biggest unresolved risk**: trust. The product promise includes "never lost," but the current repository lacks the formal release QA artifact required by its own roadmap. Backup/export exists, but release discipline needs to match the promise.

**Highest-value next step**: complete the real `RELEASE-QA.md` against the installed packaged app, restore the user's pre-QA library, and tag `v1.1` only if the verdict is SHIP.

**Overall verdict**: promising and genuinely useful as a focused Mac utility; premature only if positioned as a broad prompt manager, team product, or secure knowledge system. Keep it local, fast, and exact.

Evidence that would change the conclusion: real user retention, repeated daily copy usage, successful installs on fresh Macs, clean formal QA, and user feedback showing Dewdrops replaces an existing workflow rather than merely looking nice in a demo.
