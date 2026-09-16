# Docker preview (no VM, no host risk)

Runs niri + noctalia in a container using software rendering (Mesa
llvmpipe — no GPU passthrough needed, sidesteps the VirtualBox DRM problem
documented in `docs/virtualbox-niri.md` entirely) and serves the display
over VNC. Your host's real niri session/config/keybinds are never touched.
Pulls its config straight from `install/dotfiles/niri/` and
`install/dotfiles/noctalia/` — the same files `install/modules/16-niri.sh`
installs for real, not a separate copy.

## Build and run

From the repo root (the Dockerfile COPYs from `install/dotfiles/`, so the
build context has to be the root, not this directory):

```
docker build -t niri-preview -f docker-preview/Dockerfile .
docker run --rm -p 5901:5901 niri-preview
```

## View it

Connect any VNC viewer app to `localhost:5901`, no password. On Arch:

```
sudo pacman -S tigervnc   # ships the `vncviewer` CLI
vncviewer localhost:5901
```

Or use any GUI VNC client (Remmina, etc).

## Notes

- `Mod` inside nested niri is `Alt`, not `Super` — niri does this
  automatically in nested/winit mode, so typing into the VNC window won't
  collide with your host's real keybinds even by accident.
- `docker stop`/closing the VNC viewer ends the preview; nothing persists
  outside the container.
- Some noctalia widgets (network manager, bluetooth) may show empty/errored
  in a container with no real hardware backing them — expected, this is
  just for checking the wallpaper/bar/launcher layout, not full functionality.
