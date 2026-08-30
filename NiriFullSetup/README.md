# NiriFullSetup

niri + noctalia desktop, as configured in the 2026-08-28 session that
replaced DankMaterialShell (DMS) with noctalia on the real machine. `setup/setup.sh`
reproduces it end to end: packages, niri config + keybinds, noctalia's bar/
panel/session-menu customization, and the two helper scripts noctalia
itself doesn't provide (Overview backdrop color sync, floating-centered
btop from the bar's CPU/RAM/GPU/network meters).

## Install (Arch)

```
./setup/setup.sh
```

Run it inside a fresh VM to try the whole thing risk-free (see
`setup/VIRTUALBOX.md`), or on a real machine to actually adopt it — it only
touches niri/noctalia paths under `$HOME` plus the package installs at the
top. If DMS is already enabled on the target, the script disables
`dms.service` before installing noctalia (needed — both fight over the
compositor's notification D-Bus name).

Everything noctalia needs is in the official `extra` repo now
(`sudo pacman -S noctalia`) — no AUR helper or `quickshell-git` required,
unlike noctalia v4.

## What's in here

- `niri/config.kdl`, `niri/binds.kdl` — full niri config, installed to
  `~/.config/niri/`.
- `noctalia/settings.toml` — installed to
  `~/.local/state/noctalia/settings.toml` (the settings.toml noctalia's
  config stack always applies last, overriding anything else). `@@HOME@@`
  placeholders get substituted with the real `$HOME` by setup.sh.
- `scripts/sync-overview-color.sh` — keeps niri's Overview (`Mod+Tab`)
  backdrop color matched to noctalia's current palette; wired to
  noctalia's `hooks.colors_changed` event.
- `scripts/launch-btop-float.sh` — toggles a floating, centered `btop`;
  bound to left-clicking the CPU/RAM/GPU/network bar meters. Explicitly
  floats/sizes/centers the window via `niri msg action` rather than a
  `window-rule`, because niri doesn't reliably match a window's `app-id`
  at map time (see the script's own comment, and
  [niri-wm/niri#3420](https://github.com/niri-wm/niri/issues/3420)).
- `assets/wallpaper.jpg` — seed wallpaper so the desktop isn't blank on
  first login.
- `docker/` — a throwaway container for quick syntax/sanity checks of the
  configs (niri itself needs a real DRM device or a VM, see
  `setup/VIRTUALBOX.md`).

## What changed from DankMaterialShell

- Bar: numbered-pill workspace indicator (not DMS's default), media +
  clock centered, wifi/Bluetooth icon-only (no SSID/device name), CPU/RAM/
  GPU/network throughput as icon-only meters (network up/down as small
  gauge bars, no separate up/down icons).
- Control Center and the session (power) menu float centered on screen
  with the background dimmed behind them, instead of DMS's bar-attached
  dropdown. Session menu is a single-column list (Reboot/Lock/Suspend/
  Log Out/Shut Down) with a keyboard shortcut letter per row and a
  press-again-to-confirm countdown on the destructive ones.
- New direct-to-tab hotkeys: `Mod+Shift+N` wifi, `Mod+B` bluetooth,
  `Mod+M` system resources — all open the same floating Control Center,
  just starting on that tab.
- Wallpaper-driven theming: noctalia regenerates its palette from the
  current wallpaper (`theme.source = "wallpaper"`, off by default) and
  pushes it into GTK3/4, alacritty, Qt apps, btop, and niri's own window
  borders on every change.

### Known limits (checked noctalia's config schema directly, not skipped by choice)

- No wifi/Bluetooth signal-strength meter widget — only icon or icon+label
  display modes exist for those widget types.
- No per-widget color thresholds for the volume widget (sysmon widgets
  get activity/critical thresholds; volume doesn't).
- No "hold key for N seconds with a fill/progress indicator" confirm
  gesture for the session menu — only the press-again-to-confirm countdown
  above.
- No noctalia template for niri's `overview` block, hence the separate
  sync script instead of a built-in theming hook.

The old DMS-era `swaybg` wallpaper carousel (`select.sh`/`restore.sh`/
`carousel.qml`) has been fully retired — `Mod+W` now opens noctalia's own
wallpaper picker directly (same thing the redundant `Mod+Y` used to do,
so that bind is gone too), and noctalia's daemon manages the background
itself. No more `swaybg`/`quickshell`/`jq` dependency for wallpapers.

## Keys

Full list in `niri/binds.kdl`. Highlights:

- `Mod+Return` — terminal (alacritty)
- `Mod+D` — app launcher (fuzzel); `Mod+Space` — noctalia's own launcher
- `Mod+N` — Control Center · `Mod+Shift+N` wifi · `Mod+B` bluetooth ·
  `Mod+M` system resources
- `Mod+X` — power menu (Reboot/Lock/Suspend/Log Out/Shut Down)
- `Mod+Shift+V` — clipboard manager
- `Mod+W` — wallpaper picker (noctalia's own)
- `Mod+Tab` — overview · `Mod+Shift+Slash` — hotkey overlay
- `Mod+1`–`9` — workspaces · `Mod+H/J/K/L` — vim-style focus movement

skipped: qswitch, vicinae (both explored mid-session, neither kept —
qswitch targets Hyprland + Quickshell-era shells specifically and doesn't
apply to niri or noctalia v5's native rewrite; vicinae is a Raycast-style
launcher noctalia's built-in one already covers).
