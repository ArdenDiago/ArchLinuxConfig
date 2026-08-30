# DesktopDesigner — architecture overview

## What this is

Seven feature specs, condensed into buildable setup docs, that together add a
custom Quickshell shell suite ("DesktopDesigner") plus one standalone Rust
terminal app on top of the existing Niri + DankMaterialShell (DMS) setup in
`linux_conf-main/Full-Setup/arch`. This is **not** a rip-and-replace of DMS —
only the six components below get a native replacement; everything else DMS
already owns (power menu, clipboard manager, task manager, settings panel,
dankdash wallpaper browser) is left running exactly as-is.

| # | Component | Replaces | Tech |
|---|---|---|---|
| 1 | [Lock Screen](01-lockscreen.md) | hyprlock | Quickshell / Qt6 / QML |
| 2 | [Bar](02-bar.md) | DMS bar (WM + clock + graphs + notifications sections only) | Quickshell / Qt6 / QML |
| 3 | [Spotlight](03-spotlight.md) | DMS spotlight | Quickshell / Qt6 / QML |
| 4 | [Quick Notes](04-notepad.md) | DMS notepad | Quickshell / Qt6 / QML |
| 5 | [Wallpaper Picker](05-wallpaper-picker.md) | `carousel.qml` / `select.sh` | Quickshell / Qt6 / QML |
| 6 | [Terminal Clock](06-terminal-clock.md) | *(new, no prior equivalent)* | Rust / Ratatui / Crossterm, run inside a tmux popup |
| 7 | [Network & Bluetooth Center](07-network-bluetooth.md) | *(new — DMS has no dedicated one in this repo)* | Quickshell / Qt6 / QML, DBus (NetworkManager + BlueZ) |

Login itself (SDDM + the Qylock "Pixel · Night City" theme, `modules/22-login-theme.sh`
+ `modules/14-display-manager.sh`) is **unchanged**. The lock-screen spec talks
about "Login Screen" and greetd, but this system uses SDDM, not greetd — see
[01-lockscreen.md](01-lockscreen.md) for how that's scoped down to just the
*lock* screen (post-login, `Mod+Alt+L` / idle-lock), which is the part that
actually maps onto this setup.

## Why one Quickshell instance, not six

Quickshell supports multiple named QML configs (`qs -c <name>`), but running
Lock Screen, Bar, Spotlight, Quick Notes, and Wallpaper Picker as five
separate `qs` processes means five separate QML engines, five separate
DBus/Hyprland-IPC connections, and no shared state (theme, monitor list,
current wallpaper) without re-deriving it five times. Build them as one
Quickshell config, `desktopdesigner`, with one entrypoint (`shell/main.qml`)
that loads each feature as an independent top-level component, controlled
over one IPC namespace (`qs -c desktopdesigner ipc call <target> <action>`).
The Network & Bluetooth Center and Lock Screen are exceptions worth calling
out:

- **Lock screen** should arguably be its own `qs -c desktopdesigner-lock`
  instance — it needs to survive/outlive the main shell (which itself may
  crash or be killed) and must never share a process, DBus connection, or
  QML engine with anything that runs post-authentication. See
  [01-lockscreen.md](01-lockscreen.md) security notes.
- Everything else (Bar, Spotlight, Quick Notes, Wallpaper Picker, Network &
  Bluetooth Center) is safe to share the one `desktopdesigner` instance.

## Shared project layout

Combining every component's requested `Project Structure` section into one
tree (this is the target layout under `~/.config/quickshell/desktopdesigner/`,
i.e. Quickshell's default config search path):

```
desktopdesigner/
│
├── main.qml                     # entrypoint: loads Bar always-on; Spotlight,
│                                 # Quick Notes, Wallpaper Picker as toggleable
│                                 # top-level Loaders driven by IPC
├── shell.qml                    # legacy alias some Quickshell versions expect
│
├── Bar/
│   ├── WM/  Clock/  Graphs/  Notifications/  Battery/  System/
│
├── Spotlight/
│   ├── Spotlight.qml  SearchField.qml  ResultList.qml  ResultItem.qml
│   ├── EmptyState.qml  SpotlightOverlay.qml  SpotlightController.qml
│   ├── Providers/  Models/  Utils/
│
├── QuickNotes/
│   ├── QuickNotes.qml  NotesPanel.qml  NotesEditor.qml
│   ├── NotesController.qml  SessionStore.qml  Components/
│
├── WallpaperPicker/
│   ├── WallpaperPicker.qml  WallpaperOverlay.qml  WallpaperCarousel.qml
│   ├── WallpaperThumbnail.qml  WallpaperInfo.qml  SearchField.qml
│   ├── EmptyState.qml  WallpaperController.qml  Models/  Services/  Components/
│
├── NetworkCenter/
│   ├── NetworkCenter.qml  Overlay.qml  TabBar.qml  StatusBar.qml
│   ├── Wifi/  Bluetooth/  Services/  Components/
│
├── Dashboards/
│   ├── Performance/  NotificationCenter/  Calendar/  QuickControls/
│
├── Services/                    # shared, not duplicated per-component
│   ├── Hyprland/ (Niri IPC in this setup)   Notifications/
│   ├── Network/  Bluetooth/  Battery/  Audio/  Sensors/  Calendar/
│   ├── Users/  Wallpaper/  Session/
│
├── Components/                  # shared widgets (Buttons/, Cards/, Graphs/, Popups/, Common/)
├── Theme/                       # Colors.qml, Fonts.qml, Radius.qml, Theme.qml — Material 3, wallpaper-derived
└── Assets/

desktopdesigner-lock/            # separate qs config, see 01-lockscreen.md
├── LockScreen.qml  LoginView.qml  UserSelector.qml  PasswordField.qml
├── Clock.qml  Wallpaper.qml  IdleMode.qml
├── SnakeGame/  Components/
└── Services/ (PAM/, Authentication/, Users/, Wallpaper/, Session/)

terminal-clock/                  # separate Rust crate, see 06-terminal-clock.md
├── src/  assets/  config/  Cargo.toml
```

`Services/` is deduplicated across specs on purpose — five of the six specs
each ask for their own `Services/Network/`, `Services/Wallpaper/`, etc.; those
are the same NetworkManager/BlueZ/UPower/wallpaper-backend connections, so
build them once under the shared `Services/` and have each feature import
from there instead of re-implementing its own DBus glue.

## Cross-cutting requirements from every spec

- **No polling where an event source exists.** Niri IPC (`niri msg -j`
  event-stream) for window/workspace state, DBus for UPower/NetworkManager/
  BlueZ/logind, PipeWire/WirePlumber for audio, `inotify` for the wallpaper
  directory watcher. Poll only for things with no event source (e.g. `sysfs`
  hwmon temps).
- **Material Design 3, dynamic color.** One `Theme/Theme.qml` generates
  Material tokens from the active wallpaper (matugen is already installed by
  `modules/26-dankmaterialshell.sh` — reuse it rather than re-implementing
  color extraction) and is imported by every component. Never hardcode a
  color anywhere else.
- **Animation budget:** 150–200ms, no bounce/spring easing, anywhere in the
  suite.
- **Memory targets add up.** Bar <100MB, Spotlight <10ms search latency,
  Quick Notes <30MB, Lock Screen <100MB, Terminal Clock <10MB. Since Bar,
  Spotlight, Quick Notes, Wallpaper Picker, and Network Center share one `qs`
  process, budget the *shared* process against the largest single figure
  (~100MB), not the sum.
- **Never break the reference repo's existing binds.** See
  [`KEYBINDINGS.md`](../KEYBINDINGS.md) at the repo root — every keybind
  decision for this suite is centralized there, not repeated per-doc.

## Setup order

Dependency order, not spec order — build so each step is independently
testable before the next depends on it:

1. `Theme/` (Colors/Fonts/Radius, matugen wiring) — everything else imports it.
2. `Services/` (Niri IPC wrapper, Network, Bluetooth, Battery, Audio, Sensors) —
   Bar, Network Center, and the lock screen's session info all need these.
3. [Bar](02-bar.md) — the always-on shell; validates Theme + Services end to end.
4. [Wallpaper Picker](05-wallpaper-picker.md) — smallest surface area, direct
   upgrade of an existing working script.
5. [Spotlight](03-spotlight.md) and [Quick Notes](04-notepad.md) — independent
   of each other, can be built in either order.
6. [Network & Bluetooth Center](07-network-bluetooth.md) — needs `Services/Network`
   and `Services/Bluetooth` from step 2 fully working first.
7. [Lock Screen](01-lockscreen.md) — separate `qs` instance, build and test it
   last since a broken lock screen risks locking you out; test in a nested
   Wayland session (`niri --session` inside a VM/second seat, or Quickshell's
   own windowed preview mode) before wiring it to `Mod+Alt+L` for real.
8. [Terminal Clock](06-terminal-clock.md) — fully independent Rust crate, can
   happen any time in parallel with the above.

## Testing without touching the real config

Don't develop against `~/.config/quickshell/` or `~/.config/niri/` directly.
Use `temp/` at the repo root (see `temp/README.md`) for throwaway QML/KDL/Rust
experiments — e.g. `qs -c temp-desktopdesigner` pointed at a scratch config
dir, or a scratch niri `binds {}` block validated with `niri validate -c`
before it's copied into the real `config.kdl`. Nothing in `temp/` is ever the
source of truth; once a piece works, its *final* form goes into the matching
`docs/0N-*.md` and from there into the real dotfiles.
