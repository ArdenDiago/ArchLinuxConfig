# Spotlight

Replaces DMS's spotlight backend. Same job, same key — this is a backend
swap, not a new feature, so the existing bind carries over unchanged.

## Keybinding

| Bind | Status |
|---|---|
| `Mod+Space` | **Reused** — was `dms ipc call spotlight toggle`, becomes `qs -c desktopdesigner ipc call spotlight toggle` |

Toggle behavior (open if closed, close if open) and "close any other
fullscreen overlay before opening" are spec requirements — closing other
overlays means calling this shell's own IPC to close Wallpaper Picker/
Network Center/Quick Notes if open, since they now all live in the same
`desktopdesigner` process (see [00-overview.md](00-overview.md)).

## Directory structure

```
Spotlight/
├── Spotlight.qml            # root: search field + result list + provider indicator
├── SearchField.qml
├── ResultList.qml
├── ResultItem.qml
├── EmptyState.qml
├── SpotlightOverlay.qml     # dimmed backdrop, no blur (spec is explicit: no frosted glass here)
├── SpotlightController.qml  # owns open/close state, exposes the IPC target
├── Providers/
│   ├── BaseProvider.qml
│   ├── ApplicationProvider.qml
│   ├── RecentProvider.qml
│   ├── FavoritesProvider.qml
│   ├── WebProvider.qml       # '=' prefix
│   └── CalculatorProvider.qml # '/' prefix
├── Models/
│   └── SearchResultModel.qml
└── Utils/
    ├── FuzzySearch.js
    └── DesktopEntryLoader.js
```

## Prefix routing

First character of the query selects the provider; no prefix = Applications.

| Prefix | Provider | Status |
|---|---|---|
| *(none)* | Applications | Build now |
| `=` | Web search/URL | Build now |
| `/` | Calculator | Build now |
| `>` `?` `:` `@` `#` | Terminal / Help / Emoji / File / Settings | **Deferred** — spec marks these "(Future)"; `BaseProvider.qml` should make adding one later a registration, not a rewrite |

Router lives in `SpotlightController.qml`: inspect `text[0]`, look up a
`{prefix: providerId}` map, fall back to `applications`. Adding a provider
later = one map entry + one `Providers/*.qml` file, per the spec's own
"no changes to Spotlight UI required" requirement.

### Application provider

Source: `.desktop` entries under `/usr/share/applications` +
`~/.local/share/applications`, cached at startup (spec's own perf
requirement: avoid re-scanning on every keystroke). Fuzzy/acronym/substring
match — `Utils/FuzzySearch.js` is a single small scoring function (subsequence
match + acronym bonus + prefix bonus); this does not need a fuzzy-matching
library, it's ~40 lines.

### Web provider (`=`)

URL-or-search detection: if the remainder after `=` parses as a URL
(has a scheme, or matches `^[\w-]+\.[a-z]{2,}`) → prepend `https://` if no
scheme and open via `xdg-open`. Otherwise URL-encode and substitute into the
configured search-engine template (`%s` placeholder, default Google).
`xdg-open` is already the right tool here — don't shell out to a specific
browser binary, respect whatever's set as the default.

### Calculator provider (`/`)

Evaluate math expressions live as the user types. **Do not write a custom
expression parser/evaluator from scratch** — QML's JS engine already has
`Math.*` for every function the spec lists (`sin/cos/tan/asin/acos/atan/
log/sqrt/pow/abs/floor/ceil/round/min/max`, plus `Math.PI`/`Math.E` for the
constants) and `eval()`-adjacent safe evaluation can be done with a small
recursive-descent parser over just `+ - * / % ^ ( )` and the `Math.*` calls
— a few dozen lines, not a math library dependency. Never call raw `eval()`
on user input even though this is local/trusted input — a syntax-error
input shouldn't be able to throw an uncaught QML exception either, wrap in
try/catch and show nothing (not an error) on parse failure until the
expression is complete.

`Enter` copies to clipboard, `Ctrl+Enter` copies and stays open,
`Shift+Enter` copies and closes — three keybinds but all scoped to this
QML's `Keys.onPressed` while the calculator provider is active, not global.

## Keyboard navigation

All of ↑↓/Ctrl+N/Ctrl+P/Home/End/PageUp/PageDown/Enter/Shift+Enter/Esc from
the spec's table are local `Keys.onPressed` handlers on the result
`ListView` — standard QML list navigation, nothing Niri-specific.

## Material 3 theming

Import `Theme/Theme.qml` (shared, see [00-overview.md](00-overview.md)) —
don't build a second color system here. Modal: 12–16px radius, 550–700px
width, max 70% screen height, resize to content.

## Setup checklist

1. `SpotlightOverlay.qml` + `SearchField.qml`, hardcoded fake results — get
   open/close animation and Material surface styling right first.
2. `ApplicationProvider.qml` + `DesktopEntryLoader.js` + `FuzzySearch.js` —
   real results, no prefix routing yet.
3. `SpotlightController.qml` prefix router, `WebProvider.qml`,
   `CalculatorProvider.qml`.
4. Wire `Mod+Space` in `config.kdl`, replacing the DMS spawn line.
5. Confirm "closes other overlays first" against Wallpaper Picker (05) and
   Quick Notes (04) once those exist.

## Deferred

Files, clipboard history, settings search, emoji/symbol picker, browser
history, AI assistant, plugin marketplace — all explicitly spec'd as future
providers. `BaseProvider.qml`'s job is to make sure adding these later
doesn't require touching `Spotlight.qml`, not to pre-build stubs for them now.
