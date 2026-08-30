# temp/

Scratch/testing area only. Anything here is throwaway — validating a KDL
snippet, trying a QML component in isolation, checking a keybind doesn't
already fire something else, etc.

Rules:

- Nothing in here is part of the real setup. `docs/` and `KEYBINDINGS.md`
  at the repo root are the source of truth once something is verified.
- Never copy files from here into a real dotfile path directly — re-create
  the verified result properly under the right doc/section instead.
- Safe to delete this whole directory at any time; nothing outside it
  depends on it.

## Docker test environment (verified working)

`docker/` has an isolated Arch container with niri, quickshell, rust/cargo,
tmux, alacritty, mako, networkmanager, and bluez preinstalled — for testing
DesktopDesigner components without touching the host's real
`~/.config/niri/` or `~/.config/quickshell/`.

```bash
temp/docker/run.sh    # builds nothing itself — build first, see below
```

**Build (once, or after editing `temp/docker/Dockerfile`):**
```bash
cd temp/docker
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t desktopdesigner-test:latest .
```
`mirrorlist` in this directory is a copy of the host's own pacman mirrorlist
— the container image's built-in default mirrors (`geo`/`fastly.mirror.pkgbuild.com`)
timed out repeatedly on the first attempt; reusing a mirrorlist already known
to work from this machine fixed it.

**Run (interactive shell inside the container, repo mounted at `/workspace`):**
```bash
temp/docker/run.sh
```
This nests a nested-niri-capable, Quickshell-capable environment inside your
*current* real niri session — it renders as an actual window on your desktop
(via a mounted Wayland socket) but can't read or write anything on the host
outside the repo mount. Closing the window / exiting the shell tears it down;
`--rm` means nothing lingers after.

**Verified working (2026-08-01):**
- `niri -c <config>` starts nested, gets its own Wayland socket, renders —
  confirmed via `niri validate` (config syntax) and a live nested launch.
- `qs -p <path/to/shell.qml>` loads and runs QML against the nested session —
  confirmed with a `Component.onCompleted` smoke test.
- `cargo`/`rustc` work for the terminal-clock crate (06-terminal-clock.md).

**Three non-obvious flags in `run.sh`, each found by trial (see comments in
the script for the fuller story):**
| Flag | Why |
|---|---|
| `--init` | Without it, `docker stop`/timeouts can hang — niri/Quickshell don't handle `SIGTERM` cleanly as PID 1 |
| `--device /dev/dri` | niri needs EGL/GBM even nested-in-a-window; without a GPU device it panics on startup |
| `--tmpfs /run/user/1000:uid=1000,gid=1000` + socket mount **without** `:ro` | niri/Quickshell write their own IPC sockets into `$XDG_RUNTIME_DIR`; Docker auto-creates that dir as `root:root` otherwise (container user can't write into it), and a read-only socket bind mount blocks `connect()` outright |

Use this to test each component doc's setup checklist (`docs/01-*.md` through
`docs/07-*.md`) before anything touches the real dotfiles.
