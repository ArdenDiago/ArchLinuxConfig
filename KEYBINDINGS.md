# Keybindings

Source of truth: [`install/dotfiles/niri/binds.kdl`](install/dotfiles/niri/binds.kdl)
(included from [`config.kdl`](install/dotfiles/niri/config.kdl), installed by
[`install/modules/16-niri.sh`](install/modules/16-niri.sh)). This doc explains
*why* each custom bind is where it is — the `.kdl` files are what actually
runs.

## noctalia panels

Most custom binds route through noctalia's own IPC (`noctalia msg
panel-toggle ...`) rather than spawning a separate process — `noctalia
--daemon` is already running persistently (spawned at niri startup in
`config.kdl`), so these calls always have something to reach.

| Bind | Action | Notes |
|---|---|---|
| `Mod+Space` | App launcher | |
| `Mod+X` | Power menu | |
| `Mod+N` | Control center | noctalia has no standalone notification-center panel — notifications live inside control center alongside quick settings |
| `Mod+Shift+V` | Clipboard manager | `Mod+V` is already `toggle-window-floating` (niri built-in), so clipboard gets `Shift` added |
| `Mod+M` | Control center → System resources tab | |
| `Mod+Shift+M` | Free memory | `~/.config/niri/free-memory.sh` — restarts noctalia to drop its memory leak. If noctalia runs as a `noctalia.service` unit with a `MemoryHigh` cap, apps started from its launcher inherit that cap and swap-thrash; the script first moves them into their own scope so the restart doesn't kill them |
| `Mod+Comma` | Settings | |
| `Mod+Alt+L` | Lock screen | noctalia's own lock screen (`noctalia msg session lock`), same one the power menu's Lock row uses |

## Independent of noctalia

| Bind | Action | Notes |
|---|---|---|
| `Mod+Shift+N` | Wifi (`impala` TUI) | Floating terminal, not noctalia's Control Center tab — keyboard-driven, talks to `iwd` directly. See `launch-wifi-tui.sh`. `Esc` closes it (`dotfiles/alacritty/floating-tui.toml`) |
| `Mod+B` | Bluetooth (`bluetuith` TUI) | Same idea as `Mod+Shift+N`, via `launch-bluetooth-tui.sh` |
| `Mod+W` | Wallpaper picker | skwd-wall (see `modules/26-wallpaper-skwd.sh`), not noctalia's own picker |
| `Mod+Shift+W` | Wallpaper picker (grid) | Same picker, `config.json`'s `displayMode` flipped to `"wall"` first |
| `Mod+Return` | Terminal (alacritty) | |
| `Mod+A` | MTX Panel faders | Toggles the quickshell fader popup of mtxpanel, the per-app audio mixer built from `~/Coding/SystemEQApp`. Not installed by this repo — the bind does nothing until mtxpanel is installed |
| `Mod+D` | App launcher (fuzzel) | Direct spawn, not routed through noctalia — works even if the daemon isn't up yet |
| Media keys (`XF86Audio*`) | Volume/mic/media | Routed through noctalia's backend (`noctalia msg volume-up/down/mute/media ...`) instead of `wpctl`/`playerctl` directly, so the level shown in noctalia's own UI stays in sync |
| `XF86MonBrightness{Up,Down}` | Brightness | `~/.config/niri/brightness-step.sh` |

## Everything else

Window management, workspaces, resize, screenshots, monitor focus — all
niri built-ins, untouched by any of the above. Full list in `binds.kdl`
itself, or press `Mod+Shift+Slash` for niri's live hotkey overlay.

## Verification method

```bash
grep -n "Mod+T" install/dotfiles/niri/binds.kdl
```

Re-run this against `binds.kdl` before adding any further new bind — if a
key's already spoken for, don't double-bind it.
