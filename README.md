# ArchLinuxNewConfig

Arch Linux desktop setup: niri (scrollable-tiling Wayland compositor) +
noctalia (bar, panels, launcher, lock screen), SDDM with the `qylock-dark`
login theme, and the apps/dev tooling that go with it.

## Installing

On a fresh Arch install:

```bash
./install/setup.sh
```

Every file in [`install/modules/`](install/modules/) is a self-contained,
idempotent step, run in filename order; a failed step is rolled back and
logged to `install/errors.log` while the rest carry on. Safe to re-run.

## Layout

- `install/setup.sh`, `install/lib/common.sh` — the module runner and its
  helpers (`pac_install`, `aur_install`, `install_dotfile`, rollback).
- `install/modules/` — one step each; `16-niri.sh` is the desktop itself.
- `install/dotfiles/` — the configs those modules copy into `$HOME`.
- `install/firefox-newtab-pomodoro/` — New Tab extension packaged by
  `19-firefox.sh`.
- `sddm-theme/` — the login theme installed by `22-login-theme.sh`.

## Docs

- [`KEYBINDINGS.md`](KEYBINDINGS.md) — every custom bind and why;
  `install/dotfiles/niri/binds.kdl` is the source of truth.
- [`docs/virtualbox-niri.md`](docs/virtualbox-niri.md) — why niri shows a
  black screen in VirtualBox, and what works instead.
- [`docs/nvim-jupyter.md`](docs/nvim-jupyter.md) — editing and running
  `.ipynb` notebooks in nvim.
