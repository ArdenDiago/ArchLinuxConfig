# ArchLinuxNewConfig — DesktopDesigner setup

Setup documentation for a custom Quickshell shell suite ("DesktopDesigner")
plus a standalone Rust terminal clock, built on top of the existing Niri +
DankMaterialShell (DMS) config in
[`linux_conf-main/Full-Setup/arch`](/home/arden/Coding/linux_conf-main/Full-Setup/arch).

This repo does not fork or copy that reference config — it documents *what
changes on top of it*: which existing keybinds get a new backend, which new
keybinds get added, and how to build/install each of the 7 requested
components. The reference repo's dotfiles remain the actual source of truth
for anything not explicitly called out here.

## Read first

1. **[`KEYBINDINGS.md`](KEYBINDINGS.md)** — every keybind decision in this
   setup, and why. No existing keybind is reassigned or removed; new binds
   only exist where the reference repo genuinely has nothing on that key.
2. **[`docs/00-overview.md`](docs/00-overview.md)** — architecture: how the
   6 Quickshell components fit into one `desktopdesigner` process (plus a
   separate lock-screen process for security isolation), shared services,
   Material 3 theming, and the recommended build order.

## Components

| Doc | Component | Reused bind | New bind |
|---|---|---|---|
| [01-lockscreen.md](docs/01-lockscreen.md) | Lock Screen + Snake game | `Mod+Alt+L` | `Ctrl+G` / `Esc` (lock-screen-local) |
| [02-bar.md](docs/02-bar.md) | Top Bar | `Mod+N` | — |
| [03-spotlight.md](docs/03-spotlight.md) | Spotlight launcher | `Mod+Space` | — |
| [04-notepad.md](docs/04-notepad.md) | Quick Notes | `Mod+Shift+N` | — |
| [05-wallpaper-picker.md](docs/05-wallpaper-picker.md) | Wallpaper Picker | `Mod+W` | — |
| [06-terminal-clock.md](docs/06-terminal-clock.md) | Terminal Clock (Rust/Ratatui) | — | `Mod+T` |
| [07-network-bluetooth.md](docs/07-network-bluetooth.md) | Network & Bluetooth Center | — | *(click-only, no bind yet)* |

## Build order

See [`docs/00-overview.md#setup-order`](docs/00-overview.md#setup-order):
Theme → Services → Bar → Wallpaper Picker → Spotlight/Quick Notes → Network
Center → Lock Screen (last, deliberately, since it's the one component that
can lock you out if broken) → Terminal Clock (fully independent, any time).

## Installing

Two separate scripts, run in order on a fresh machine/VM:

1. **[`install/setup.sh`](install/setup.sh)** — full system bootstrap (yay,
   Homebrew, git identity, core apps, dev tooling, NVIDIA, SDDM, Hyprland +
   Niri, desktop services, dotfiles, Firefox customizations, login theme,
   lock screen, ble.sh). Forked from
   [`linux_conf-main/Full-Setup/arch`](/home/arden/Coding/linux_conf-main/Full-Setup/arch)'s
   own modular installer, minus its DankMaterialShell module — this repo's
   `desktopdesigner` replaces DMS, so DMS itself is never installed here.
2. **[`setup.sh`](setup.sh)** (repo root) — lets you pick which of
   `desktopdesigner` / `desktopdesigner-lock` / `terminal-clock` to symlink
   into `~/.config/quickshell/` and build.

## Testing

Never develop against the real `~/.config/quickshell/` or `~/.config/niri/`
paths directly. Use [`temp/`](temp/) for throwaway experiments — see
`temp/README.md`. Nothing in `temp/` is load-bearing; verified results get
written into the matching `docs/0N-*.md` and from there into the real
dotfiles by hand.
