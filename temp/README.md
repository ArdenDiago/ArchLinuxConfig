# temp/

Scratch/testing area only. Anything here is throwaway — validating a KDL
snippet, checking a keybind doesn't already fire something else, etc.

Rules:

- Nothing in here is part of the real setup. `install/dotfiles/` and
  `KEYBINDINGS.md` at the repo root are the source of truth once something
  is verified.
- Never copy files from here into a real dotfile path directly — re-create
  the verified result properly under `install/dotfiles/` instead.
- Safe to delete this whole directory at any time; nothing outside it
  depends on it.

## Docker test environment (verified working)

`docker/` has an isolated Arch container with niri, noctalia, alacritty,
fuzzel, hyprlock, mako, btop, kwallet, and polkit-gnome preinstalled — for
testing the real niri+noctalia setup without touching the host's real
`~/.config/niri/` or `~/.local/state/noctalia/`.

**Build (once, or after editing `temp/docker/Dockerfile`):**
```bash
cd temp/docker
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t niri-desktop-test:latest .
```
`mirrorlist` in this directory is a copy of the host's own pacman mirrorlist
— the container image's built-in default mirrors (`geo`/`fastly.mirror.pkgbuild.com`)
timed out repeatedly on the first attempt; reusing a mirrorlist already known
to work from this machine fixed it.

**Run (interactive shell inside the container, repo mounted at `/workspace`):**
```bash
temp/docker/run.sh
```
This nests a nested-niri-capable environment inside your *current* real
niri session — it renders as an actual window on your desktop (via a
mounted Wayland socket) but can't read or write anything on the host
outside the repo mount. Closing the window / exiting the shell tears it
down; `--rm` means nothing lingers after.

**Automated screenshot capture:**
```bash
temp/docker/screenshot-test.sh [config.kdl] [output.png]
```
Seeds `install/dotfiles/noctalia/settings.toml` + `wallpaper.jpg` into the
container's `$HOME` (same as `install/modules/16-niri.sh` does on a real
install), launches niri nested with the given config (default
`test-config.kdl`), spawns a terminal, screenshots, dumps niri/noctalia
logs, tears down. Screenshots land in `temp/docker/screenshots/`.

**Verified working (2026-08-01, re-verified 2026-08-30 for noctalia):**
- `niri -c <config>` starts nested, gets its own Wayland socket, renders —
  confirmed via `niri validate` (config syntax) and a live nested launch.
- noctalia's bar/wallpaper/panel manager all initialize nested and render
  correctly (confirmed via screenshot).
- `cargo`/`rustc` work for the terminal-clock crate (`docs/terminal-clock.md`).

**Three non-obvious flags in `run.sh`/`screenshot-test.sh`, each found by
trial (see comments in the scripts for the fuller story):**
| Flag | Why |
|---|---|
| `--init` | Without it, `docker stop`/timeouts can hang — niri/noctalia don't handle `SIGTERM` cleanly as PID 1 |
| `--device /dev/dri` | niri needs EGL/GBM even nested-in-a-window; without a GPU device it panics on startup |
| `--tmpfs /run/user/1000:uid=1000,gid=1000` + socket mount **without** `:ro` | niri/noctalia write their own IPC sockets into `$XDG_RUNTIME_DIR`; Docker auto-creates that dir as `root:root` otherwise (container user can't write into it), and a read-only socket bind mount blocks `connect()` outright |

For a GPU-free alternative (software rendering over VNC, works inside a VM
too) see [`../../docker-preview/`](../../docker-preview/README.md) instead.

Use this to test niri/noctalia config changes before anything touches the
real dotfiles under `install/dotfiles/`.
