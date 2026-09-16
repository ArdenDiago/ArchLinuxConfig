#!/usr/bin/env bash
# Interactive installer for the optional, not-yet-wired-into-the-main-
# bootstrap extras: quickshell-lock (custom lock screen + Snake game) and
# terminal-clock (Rust/Ratatui fullscreen clock, Mod+T popup). The real
# desktop shell (niri + noctalia) is part of install/setup.sh's system
# bootstrap now, not a symlink choice here — see install/modules/16-niri.sh.
# This script just builds/symlinks the two standalone extras and never
# touches niri's live config.kdl itself. See README.md for the full picture.
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
  quickshell-lock "Lock screen + Snake game (separate qs instance, not yet wired to Mod+Alt+L)" OFF \
  terminal-clock  "Rust/Ratatui fullscreen clock, Mod+T popup"                                  ON \
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
    quickshell-lock) need_pkg qs quickshell ;;
    terminal-clock) need_pkg cargo rust; need_pkg tmux tmux; need_pkg alacritty alacritty ;;
  esac
done

for choice in "${CHOICES[@]}"; do
  case "$choice" in
    quickshell-lock)
      mkdir -p "$QS_DIR"
      ln -sfn "$REPO_DIR/quickshell-lock" "$QS_DIR/quickshell-lock"
      echo "==> Linked $QS_DIR/quickshell-lock -> $REPO_DIR/quickshell-lock"
      echo "    Manual step: point Mod+Alt+L at 'loginctl lock-session' instead of the"
      echo "    current hyprlock spawn, once a logind-Lock-signal listener launches"
      echo "    'qs -c quickshell-lock'. Keep hyprlock installed as fallback."
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
