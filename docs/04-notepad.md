# Quick Notes

Replaces DMS's notepad backend. Same job, same key.

## Keybinding

| Bind | Status |
|---|---|
| `Mod+Shift+N` | **Reused** — was `dms ipc call notepad toggle`, becomes `qs -c desktopdesigner ipc call quickNotes toggle` |

`Esc` to hide and all the text-editing shortcuts (Ctrl+A/C/V/X/Z/Shift+Z,
Ctrl+Backspace/Delete) are local to the `TextArea` — QML's `TextArea`
already implements standard undo/redo/select-all/copy/paste/cut for free;
only Ctrl+Backspace (delete previous word) and Ctrl+Delete (delete next
word) typically need an explicit `Keys.onPressed` override since Qt's
default word-delete binding varies by platform style — verify against
Kirigami/QQC2 defaults before adding a redundant handler.

## Directory structure

```
QuickNotes/
├── QuickNotes.qml       # panel root, slide-in-from-right layout
├── NotesPanel.qml       # translucent surface, flush right edge, rounded inner corners
├── NotesEditor.qml      # plain-text TextArea, monospace, no toolbar/tabs/status bar
├── NotesController.qml  # open/close state, IPC target, focus management
├── SessionStore.qml     # in-memory only by default
└── Components/
```

## Behavior

- Plain text only — no markdown, no rich text, no line numbers, no minimap.
  This is a `TextArea` in a `Flickable`/`ScrollView`, full stop; resist the
  urge to add anything from the spec's own "Future Features" list.
- Session-only persistence: content lives in `NotesController`'s in-memory
  property for the life of the `desktopdesigner` process. Closing the panel
  does not clear it (it's a `Loader`/visibility toggle, not a re-instantiation
  — don't destroy the editor's `TextArea` item on hide, just hide it).
- Logging out / process restart clears it — this is the explicit default
  (`persistence: false`), don't wire up file persistence now.
- Optional persistent mode: leave a single boolean on `NotesController`
  (`property bool persistenceEnabled: false`) with the save/load path as a
  dead branch (`if (persistenceEnabled) { ... }` with a TODO, not a fleshed
  out `SessionStore` writing to disk) — the spec explicitly wants the
  architecture ready without building it.

## Appearance

- Slides in from the right edge, flush against the screen (no compositor
  gap — position the Quickshell `PanelWindow` at `anchors.right: true` with
  zero margin).
- ~70% opacity, wallpaper faintly visible through it. No blur, no frosted
  glass, no heavy shadow — this is a deliberately *lighter* treatment than
  the other overlays (Spotlight/Wallpaper Picker use dim+no-blur; Network
  Center uses dim+blur; Quick Notes uses translucency with no dim at all,
  since it's not meant to feel modal).
- Monospace font, 14px, from `Theme/Fonts.qml` (JetBrains Mono / Fira Code /
  Cascadia Mono — whichever's already installed; check before pulling in a
  new font package).

## Focus behavior

On open: `NotesEditor`'s `TextArea` grabs focus immediately, cursor ready.
On close: restore focus to whatever had it before — Quickshell's
`PanelWindow` doesn't automatically hand focus back on hide, so
`NotesController` needs to snapshot the previously-focused Niri window
(via the same Niri IPC connection `Bar/WM` already holds) before opening,
and call `focus-window` on it when closing.

## Setup checklist

1. `NotesPanel.qml` + `NotesEditor.qml` with a hardcoded string — confirm
   slide animation, translucency, and flush-edge positioning.
2. `NotesController.qml` — real open/close/focus-restore via `Mod+Shift+N`.
3. `SessionStore.qml` as pure in-memory state, verify content survives
   hide/show across many toggles.
4. Leave the `persistenceEnabled` dead branch in, don't build it further.

## Deferred

Everything in the spec's "Future Features" list — markdown mode, checklists,
search, multiple notes, pin/tags/export/import, clipboard-history
integration, AI summaries, calendar integration, Vim/Emacs mode. None of
these get scaffolding; the whole point of this component is staying a
scratchpad.
