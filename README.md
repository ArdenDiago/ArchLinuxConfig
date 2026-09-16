# ArchLinuxNewConfig

Arch Linux desktop setup: niri (scrollable-tiling Wayland compositor) +
noctalia (bar/panels/launcher/wallpaper shell), plus two standalone extras —
a custom lock screen with a Snake game (`quickshell-lock/`, not yet wired to
the lock keybind) and a Rust/Ratatui fullscreen terminal clock
(`terminal-clock/`, `Mod+T`).

## Installing

Two scripts, run in order on a fresh machine/VM:

1. **[`install/setup.sh`](install/setup.sh)** — full system bootstrap: yay,
   Homebrew, git identity, core apps, dev tooling, NVIDIA, SDDM,
   Niri (with noctalia as the shell), desktop services, dotfiles, Firefox
   customizations, login theme, lock screen, ble.sh. Modular — every file in
   `install/modules/` is a self-contained, idempotent step; see
   [`install/modules/16-niri.sh`](install/modules/16-niri.sh) for the
   niri+noctalia install specifically.
2. **[`setup.sh`](setup.sh)** (repo root) — picks which of the two optional
   extras (`quickshell-lock` / `terminal-clock`) to build/symlink into
   `~/.config/quickshell/`. The real desktop shell is part of step 1, not a
   choice here.

## Keybindings

See [`KEYBINDINGS.md`](KEYBINDINGS.md) — every custom bind, why it's there,
and what it spawns. `install/dotfiles/niri/binds.kdl` is the source of truth
these docs describe.

## Testing changes safely

Never develop against the real `~/.config/niri/` or `~/.local/state/noctalia/`
paths directly.

- **[`temp/docker/`](temp/docker/README.md)** — nests a real niri (+
  optionally noctalia) session inside your *current* live Wayland session as
  an actual on-screen window, fully isolated from host config otherwise.
  Needs a real GPU/DRM device and an existing graphical session; best for
  fast, high-fidelity iteration on a machine you're already using.
- **[`docker-preview/`](docker-preview/README.md)** — runs niri + noctalia
  with software rendering (Mesa llvmpipe) and serves the display over VNC.
  No GPU, no live session, no VM needed — works anywhere Docker does,
  including inside a VM where niri's own DRM requirements would otherwise
  hit the problem documented in
  [`docs/virtualbox-niri.md`](docs/virtualbox-niri.md).

Nothing in `temp/` is load-bearing — verified results get written into the
real dotfiles under `install/dotfiles/` by hand, never copied out of `temp/`
directly.

## Docs

- [`docs/terminal-clock.md`](docs/terminal-clock.md) — the terminal clock's
  design (custom glyph renderer, layout, compositor integration).
- [`docs/virtualbox-niri.md`](docs/virtualbox-niri.md) — why niri shows a
  black screen in VirtualBox specifically, and what actually works instead
  (real hardware, `docker-preview/`, or a QEMU/KVM + virtio-gpu VM).
- [`docs/nvim-jupyter.md`](docs/nvim-jupyter.md) — editing and running
  `.ipynb` notebooks in nvim (jupytext.nvim + molten-nvim).

## Not yet wired up

`quickshell-lock/` (Snake-game lock screen) and `sddm-theme/` (a
SnakeGame/CommandMenu/TypingTest SDDM greeter) exist as working QML but
aren't installed by either setup script yet — no logind-Lock-signal listener
launches `quickshell-lock` in place of hyprlock, and no module points SDDM
at `sddm-theme/`. `install/modules/22-login-theme.sh` installs a different,
already-wired SDDM theme (Qylock) in the meantime. `setup.sh` (repo root)
will symlink `quickshell-lock/` into `~/.config/quickshell/` if you want to
try it manually against a running `qs` session.
