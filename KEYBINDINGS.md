# Keybindings — DesktopDesigner setup

This repo layers a custom Quickshell shell suite ("DesktopDesigner") plus a
standalone Rust terminal clock on top of the existing Niri setup documented in
[`linux_conf-main/Full-Setup/arch/KEYBINDINGS.md`](/home/arden/Coding/linux_conf-main/Full-Setup/arch/KEYBINDINGS.md)
(source of truth for what's already live: `dotfiles/niri/config.kdl`,
`dotfiles/hypr/hyprland.conf`, `dotfiles/hypr/hyprlock.conf`,
`dotfiles/dankmaterialshell/settings.json`).

**Rule for this whole setup:** an existing keybind is never reassigned to a
different action, and never removed. Where a new component does the *same
job* an existing bind already points at (lock, wallpaper picker, spotlight,
notepad), the keybind is reused as-is and only the backend it launches
changes. A brand new global keybind is only introduced where the reference
repo has genuinely nothing bound to that key — verified below by grepping
`config.kdl`, `hyprland.conf`, and DMS's `settings.json`.

## Resolution table

| Component | Keybind | Status | Before | After |
|---|---|---|---|---|
| Lock Screen | `Mod+Alt+L` | **Reused** | `spawn "hyprlock"` | `spawn "desktopdesigner-lock"` (see [01-lockscreen.md](docs/01-lockscreen.md)) |
| Wallpaper Picker | `Mod+W` | **Reused** | `spawn-sh "~/.config/wallpaper/select.sh"` (→ `carousel.qml`) | `spawn "qs" "-c" "desktopdesigner" "ipc" "call" "wallpaperPicker" "toggle"` (see [05-wallpaper-picker.md](docs/05-wallpaper-picker.md)) |
| Spotlight | `Mod+Space` | **Reused** | `spawn "dms" "ipc" "call" "spotlight" "toggle"` | `spawn "qs" "-c" "desktopdesigner" "ipc" "call" "spotlight" "toggle"` (see [03-spotlight.md](docs/03-spotlight.md)) |
| Quick Notes | `Mod+Shift+N` | **Reused** | `spawn "dms" "ipc" "call" "notepad" "toggle"` | `spawn "qs" "-c" "desktopdesigner" "ipc" "call" "quickNotes" "toggle"` (see [04-notepad.md](docs/04-notepad.md)) |
| Bar (notifications section) | `Mod+N` | **Reused** | `spawn "dms" "ipc" "call" "notifications" "toggle"` | `spawn "qs" "-c" "desktopdesigner" "ipc" "call" "notificationCenter" "toggle"` (see [02-bar.md](docs/02-bar.md)) |
| Terminal Clock | `Mod+T` | **New** — grepped clean across `config.kdl`, `hyprland.conf`, `tmux.conf` (only `prefix+t` exists, a different scope) | *(unbound)* | `spawn-sh "~/.config/terminal-clock/popup.sh"` (see [06-terminal-clock.md](docs/06-terminal-clock.md)) |
| Snake game (inside Lock Screen) | `Ctrl+G` | **New**, but scoped to the lock screen's own QML `Keys.onPressed` — not a niri/compositor bind, so it can't collide with anything global | *(n/a)* | Opens Snake overlay without unlocking |
| Exit Snake game | `Esc` | **New**, same lock-screen-local scope | *(n/a)* | Returns to password field |
| Network & Bluetooth Center | *(none, click-only)* | **Deferred** | *(n/a)* | Opened by clicking the Wi-Fi/Bluetooth icon in the Bar's system-controls section (see [07-network-bluetooth.md](docs/07-network-bluetooth.md)); the spec itself only asks for a click trigger with an optional shortcut "added later" — no global keybind is invented for it now (YAGNI) |

## Explicitly left alone

These existing DMS-backed binds have no corresponding component in this batch
of specs, so they keep pointing at DMS unchanged:

| Keybind | Stays as |
|---|---|
| `Mod+X` | Power menu (DMS) |
| `Mod+Shift+V` | Clipboard manager (DMS) |
| `Mod+M` | Task manager (DMS) |
| `Mod+Comma` | Settings panel (DMS) |
| `Mod+Y` | DMS's own wallpaper browser (dankdash) — redundant with the upgraded `Mod+W` picker, but pre-existing redundancy isn't this batch's problem to resolve |
| `prefix+t` (tmux) | `bigclock.sh` popup — unrelated scope to the new `Mod+T` terminal clock; both can coexist |

Everything else (window management, workspaces, resize, screenshots, media
keys, monitor focus) is untouched — none of the 7 new components touch
window-manager mechanics.

## Verification method

```bash
grep -n "Mod+T\|SUPER, T" dotfiles/niri/config.kdl dotfiles/hypr/hyprland.conf
grep -n "Mod+G\|SUPER, G" dotfiles/niri/config.kdl dotfiles/hypr/hyprland.conf
grep -in "bind\|shortcut" dotfiles/dankmaterialshell/settings.json
```

Re-run this against the reference repo before adding any further new bind —
if a future component wants a key, check it here first.
