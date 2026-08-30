#!/usr/bin/env bash
# Interactive installer: pick which components to set up, symlink them into
# the real Quickshell config dir, build terminal-clock. Never touches niri's
# live config.kdl itself — that's install/modules/16-niri.sh's job, and its
# copy of dotfiles/niri/config.kdl already has the desktopdesigner/
# terminal-clock keybinds baked in (see KEYBINDINGS.md). This script just
# builds the binaries those binds point at. See docs/0N-*.md for detail.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="$HOME/.config/quickshell"

# Installs a pacman package if the binary it provides isn't already on PATH.
# --noconfirm: sudo -v below already got the one password prompt/confirmation
# up front, so each of these shouldn't stop and ask again.
need_pkg() {
  local bin="$1" pkg="$2"
  command -v "$bin" &>/dev/null && return
  echo "==> $bin not found, installing $pkg..."
  sudo pacman -S --needed --noconfirm "$pkg"
}

CHOICES=$(whiptail --checklist "Select components to set up (space to toggle, enter to confirm)" 20 78 5 \
  desktopdesigner    "Bar/Spotlight/QuickNotes/WallpaperPicker/NetworkCenter" ON \
  desktopdesigner-lock "Lock screen + Snake game (separate qs instance)"      OFF \
  terminal-clock     "Rust/Ratatui fullscreen clock, Mod+T popup"             OFF \
  3>&1 1>&2 2>&3) || { echo "Cancelled."; exit 0; }

[ -z "$CHOICES" ] && { echo "Nothing selected."; exit 0; }

eval "CHOICES=($CHOICES)"

# Whiptail needs a real terminal, so logging only starts after it's done —
# tee-ing stdout/stderr earlier would break its checklist UI. Overwritten
# (not appended) each run, so it only ever holds the latest run's output.
# Written under ~/.cache, not the repo dir: a VM shared-folder mount
# (vboxsf/9p/virtiofs) can read the repo but silently refuses new files in
# it — same reason the terminal-clock build had to move outside the repo too.
mkdir -p "$HOME/.cache"
LOG_FILE="$HOME/.cache/archlinuxnewconfig-setup.log"
exec > >(tee "$LOG_FILE") 2>&1
echo "==> Logging this run to $LOG_FILE"

# One password prompt for the whole run instead of one per package.
sudo -v

# Dependencies first, per selected component, before any symlinking/building.
for choice in "${CHOICES[@]}"; do
  case "$choice" in
    desktopdesigner|desktopdesigner-lock) need_pkg qs quickshell ;;
    terminal-clock) need_pkg cargo rust; need_pkg tmux tmux; need_pkg alacritty alacritty ;;
  esac
done

for choice in "${CHOICES[@]}"; do
  case "$choice" in
    desktopdesigner)
      mkdir -p "$QS_DIR"
      ln -sfn "$REPO_DIR/desktopdesigner" "$QS_DIR/desktopdesigner"
      echo "==> Linked $QS_DIR/desktopdesigner -> $REPO_DIR/desktopdesigner"
      echo "    Run with: qs -c desktopdesigner"

      # desktopdesigner replaces DankMaterialShell (README: "DMS itself is
      # deliberately never installed here"). If a prior install left
      # dms.service enabled, it keeps relaunching DMS's own bar/IPC on
      # every login and fights desktopdesigner for the same layer-shell
      # surface — same symptom as no bar/keybinds ever showing up.
      if systemctl --user is-enabled dms.service &>/dev/null || systemctl --user is-active dms.service &>/dev/null; then
        systemctl --user disable --now dms.service
        echo "==> Disabled dms.service (DankMaterialShell) — it was still enabled from a prior install and would otherwise keep competing with desktopdesigner for the bar."
      fi
      ;;
    desktopdesigner-lock)
      mkdir -p "$QS_DIR"
      ln -sfn "$REPO_DIR/desktopdesigner-lock" "$QS_DIR/desktopdesigner-lock"
      echo "==> Linked $QS_DIR/desktopdesigner-lock -> $REPO_DIR/desktopdesigner-lock"
      echo "    Manual step (docs/01-lockscreen.md): point Mod+Alt+L at 'loginctl lock-session'"
      echo "    instead of the current hyprlock spawn, once a logind-Lock-signal listener"
      echo "    launches 'qs -c desktopdesigner-lock'. Keep hyprlock installed as fallback."
      ;;
    terminal-clock)
      # Building straight into $REPO_DIR/target fails with "Permission
      # denied" on a VM shared folder (vboxsf/9p/virtiofs) — those mounts
      # commonly can't honor the file locks Cargo's build dir needs. Build
      # outside the shared mount instead; popup.sh checks here first.
      export CARGO_TARGET_DIR="$HOME/.cache/terminal-clock/target"
      (cd "$REPO_DIR/terminal-clock" && cargo build --release)
      echo "==> Built $CARGO_TARGET_DIR/release/terminal-clock"
      echo "    Mod+T is already wired in ~/.config/niri/config.kdl (installed by"
      echo "    install/modules/16-niri.sh) to spawn this popup — nothing left to add."
      ;;
  esac
done

echo "==> Done. Full log: $LOG_FILE"

# Best-effort copy into the repo itself, so it's visible wherever the repo
# is shared/mounted from without copying it over by hand. $LOG_FILE in
# ~/.cache stays the source of truth — this copy just failing quietly
# (same shared-mount write restriction that forced CARGO_TARGET_DIR out of
# the repo earlier) shouldn't fail the whole run.
cp -f "$LOG_FILE" "$REPO_DIR/setup.log" 2>/dev/null \
  && echo "==> Also copied to $REPO_DIR/setup.log" \
  || echo "==> Could not copy the log into $REPO_DIR (mount likely blocks new files there) — read it from $LOG_FILE instead."
