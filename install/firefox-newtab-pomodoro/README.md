# New Tab — Search + Pomodoro

A small Firefox WebExtension that overrides `about:newtab` entirely with
its own page: the same centered glass search pill from the
`firefox-themes/hover-titlebar` theme, a working Pomodoro timer below it,
and a radial quick-links launcher on the left edge — in place of the
stock weather widget and "Customize New Tab" gear, which simply don't
exist on this page at all, rather than being hidden.

This is a separate mechanism from `firefox-themes/`, not an extension of
it. That project is CSS-only (`userChrome.css`/`userContent.css`) and
can't run JavaScript — a real countdown timer with start/pause/reset and
a completion notification needs actual script, and `about:newtab` is a
privileged page that plain content-page CSS/JS can't reach. Overriding
the page via `chrome_url_overrides.newtab` in a WebExtension is the
standard, sanctioned way to do that.

**If this extension is active, it replaces `about:newtab` outright** —
`firefox-themes/hover-titlebar/content.css`'s New Tab styling no longer
applies, since Activity Stream isn't being loaded anymore. The chrome
side of that theme (hiding the title bar/tabs/nav-bar on hover) is
unrelated to New Tab content and keeps working normally alongside this.

## Files

| File            | Purpose                                                        |
|-----------------|------------------------------------------------------------------|
| `manifest.json` | Declares the New Tab override and the `search`/`notifications` permissions. |
| `newtab.html`   | The page structure: search form, Pomodoro widget, radial launcher. |
| `newtab.css`    | Same aurora/glass visual language as the CSS theme, reimplemented here since this is a standalone page. |
| `newtab.js`     | Timer logic (state, persistence, notifications) and search submission. |
| `launcher.js`   | The radial quick-links launcher — circular queue, rendering, keybinds. |

## How the timer works

- 25-minute focus session, 5-minute short break, 15-minute long break
  every 4th session — standard Pomodoro cadence, defined at the top of
  `newtab.js` (`DURATIONS`, `LONG_BREAK_EVERY`) if you want to change it.
- State (mode, remaining time, running/paused, session count) is kept in
  `localStorage`, keyed off a wall-clock `endTime` rather than a plain
  countdown — so it stays accurate even if the tab is backgrounded/
  throttled or the New Tab page is closed and reopened mid-session.
- On completion, a `browser.notifications` toast fires (needs the
  `notifications` permission, already in the manifest) and the mode
  advances automatically (work → break → work...).

## How search works

Typing a query and hitting Enter calls `browser.search.search()` — the
same WebExtension API real search UI uses — so it goes through your
actual default search engine, not a hardcoded one. If that API is ever
unavailable for some reason, it falls back to a direct Google query URL.

## How the radial launcher works

A small hub tab sits half-off the left edge of the window, vertically
centered. Click it (or `Alt+K`) to open it into a circle of small icons
— five defaults (GitHub, YouTube, Wikipedia, Reddit, Gmail) to start,
plus anything you add yourself. Links persist in `localStorage`.

The icons are backed by an actual **circular queue** (`CircularQueue` in
`launcher.js`): a plain array plus a rotating `start` offset. "Selected"
is always whichever link sits at `start` — rotating changes that offset
rather than moving any data, so the underlying list order never
changes, only which item currently reads as selected. Icons are spread
evenly around a *full* 360° circle centered on the hub; only the right
half is ever inside the viewport, so with more than a couple of links,
some sit past the left edge at any given moment — rotating brings them
into view while the current ones cycle out, which is what actually
makes it look like a revolving wheel rather than a static row.

Icon DOM nodes are only rebuilt when the link list itself changes (add/
remove) — rotating just recomputes each existing node's angle and lets
the CSS `transition` on `transform` animate the move.

**Keybinds** (once the panel is open — `Alt+K` opens/closes it from
anywhere):

| Key                     | Action                                      |
|--------------------------|----------------------------------------------|
| `Alt+K`                  | Open or close the panel                     |
| `↑` / `←`                | Rotate the queue back a step                |
| `↓` / `→`                | Rotate the queue forward a step             |
| `Enter`                  | Open the currently selected link            |
| `Delete` / `Backspace`   | Remove the currently selected link          |
| `Esc`                    | Close the panel                             |

Clicking any icon directly opens it (rotating to select it first isn't
required with a mouse — that's purely a keyboard affordance). Clicking
outside the launcher, or the hub again, closes the panel without
changing the list.

## Loading it (temporary, sandbox-only)

WebExtensions loaded this way are **not signed or published anywhere**
— nothing leaves your machine, and nothing is installed system-wide.

1. Open `about:debugging#/runtime/this-firefox` in the profile you want
   to test this in (e.g. the same sandbox profile used for
   `firefox-themes/`).
2. Click **Load Temporary Add-on…**.
3. Select `manifest.json` in this folder.
4. Open a new tab — it should show the search box + Pomodoro widget.

Temporary add-ons are unloaded when Firefox restarts — you'll need to
repeat steps 1–3 each session. To make it persist across restarts
*within a specific profile* (without touching Firefox's installation or
your other profiles), set `xpinstall.signatures.required` to `false` in
that profile's `about:config`/`user.js`, then install it permanently via
`about:addons` → gear icon → **Install Add-on From File**, pointing at a
zipped copy of this folder (`.zip` renamed to `.xpi`).

## Limitations

- No custom icon is set — Firefox will show its default extension icon
  in `about:addons`. Add an `icons` entry to `manifest.json` and a PNG
  here if you want one.
- The search fallback URL is hardcoded to Google; it only ever triggers
  if `browser.search`/`browser.tabs` are unavailable, which shouldn't
  happen in normal use.
