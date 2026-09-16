# Terminal Clock

The only non-Quickshell component in this batch — standalone Rust binary,
runs inside a fullscreen tmux popup. No prior equivalent in the reference
repo to replace; `dotfiles/tmux/bigclock.sh` (bound to tmux's `prefix+t`) is
a much simpler existing clock popup — this coexists with it rather than
replacing it (see keybinding table).

## Keybinding

| Bind | Status |
|---|---|
| `Mod+T` | **New** — confirmed unbound in `config.kdl`, `hyprland.conf`, and `tmux.conf` (only `prefix+t`, a different scope, exists) |
| any key (inside the clock) | Exit |

The spec explicitly asks to check `Super+T` availability before assuming it
— confirmed clean via `grep -n "Mod+T\|SUPER, T" dotfiles/niri/config.kdl
dotfiles/hypr/hyprland.conf`, nothing matched. See
[`KEYBINDINGS.md`](../KEYBINDINGS.md).

## Compositor → tmux popup integration

The spec says the app runs "inside a fullscreen tmux popup" but the trigger
is a **compositor-level** keybind (`Mod+T`), not a tmux prefix binding —
this needs a small wrapper the niri bind actually spawns, since
`tmux display-popup` requires an attached client/session to target:

```bash
#!/usr/bin/env bash
# ~/.config/terminal-clock/popup.sh
# Reuses bigclock.sh's own pattern (dotfiles/tmux/tmux.conf line 85):
#   bind-key t display-popup -w 100% -h 100% -E "~/.config/tmux/bigclock.sh"
# but triggered globally instead of from inside an attached tmux client.
session="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)"
if [ -n "$session" ]; then
  tmux display-popup -t "$session" -w 100% -h 100% -E terminal-clock
else
  alacritty -e terminal-clock
fi
```

Niri bind: `Mod+T hotkey-overlay-title="Terminal Clock" { spawn-sh "~/.config/terminal-clock/popup.sh"; }`.
Falls back to a plain Alacritty window if no tmux session is running yet —
matches the spec's "completely independent" runtime requirement (it
shouldn't hard-require a live tmux session to be reachable at all).

## Directory structure (from spec, unchanged)

```
terminal-clock/
├── src/
│   ├── main.rs  app.rs  renderer.rs  glyph_renderer.rs  typography.rs
│   ├── layout.rs  clock.rs  animations.rs  terminal.rs  config.rs  utils.rs
├── assets/
├── config/
│   └── default.toml
└── Cargo.toml
```

## Dependencies

```toml
[dependencies]
ratatui = "0.29"
crossterm = "0.28"
```

Nothing else — no FIGlet crate, no ASCII-art font library (explicitly
forbidden by the spec: custom glyph renderer only), no chrono strictly
required (`std::time::SystemTime` + a small calendar calc is enough, but
`chrono` is fine if it's already a habit — either is "stdlib-adjacent" here,
pick whichever's less code for date formatting).

## Custom glyph renderer — the actual engineering work here

This is the one genuinely nontrivial piece: hand-built digit glyphs (0–9, `:`,
AM/PM) using Unicode box-drawing characters, scaled by terminal size, with
per-digit animation on change (not full-screen redraw). Design as a lookup
table: `Glyph = Vec<Vec<char>>` (or a small bitmap-per-digit format) at a
canonical size, then `typography.rs` scales stroke/spacing proportionally to
fit the largest size that comfortably fits `terminal_width × terminal_height`
minus margins. Ratatui's `Buffer` diffing already avoids redundant terminal
writes at the cell level — lean on that instead of hand-rolling dirty-rect
tracking; just make sure per-second updates only touch the cells that
actually changed (this falls out naturally if `renderer.rs` only rebuilds the
digit widgets whose value changed, not the whole `Buffer`).

## Layout

```
────────────────────────────────────────
              LARGE CLOCK
────────────────────────────────────────
        Wednesday · 01 August 2026
────────────────────────────────────────
CPU 7% │ RAM 23% │ Battery 94% │ Uptime 3d 12h
────────────────────────────────────────
```

Status row sources — the same raw system files noctalia's own bar widgets
read, just read directly here since this is a standalone Rust binary with
no access to noctalia's internals: `/proc/stat` (CPU), `/proc/meminfo` (RAM),
`/sys/class/power_supply/BAT*` (battery, hide if absent), `/proc/uptime`.
1s refresh, matching the spec.

## Theming

Inherit terminal foreground/background — i.e. **don't set any color at
all**, use `Color::Reset`/default styling so whatever terminal theme
(Catppuccin, Gruvbox, Tokyo Night, whatever Alacritty's configured with) just
shows through. This is simpler than the spec's own suggestion of detecting
and adapting to specific themes — zero color code IS the correct
implementation of "look beautiful regardless of terminal theme."

## Setup checklist

1. `terminal.rs` + `app.rs` — raw mode, alternate screen, restore on exit
   (including on panic — set a panic hook that restores the terminal before
   the default panic handler prints, or the tmux pane is left in a broken
   state).
2. `glyph_renderer.rs` + `typography.rs` — get one digit (say `2`) rendering
   and scaling correctly before building all ten + `:`/AM/PM.
3. `clock.rs` + `layout.rs` — full HH:MM, date line, centered.
4. `animations.rs` — per-digit change animation, ≤200ms.
5. Status row (CPU/RAM/battery/uptime).
6. `popup.sh` wrapper + `Mod+T` niri bind.

## Deferred

Stopwatch, Pomodoro, countdown, world clock, multiple timezones, ambient
screensaver, meeting/focus timers — spec marks all of these future and
explicitly "disabled in the initial release."
