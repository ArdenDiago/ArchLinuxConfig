#!/usr/bin/env bash
#
# Sanity checks and one-time bootstrapping that every later module relies
# on: a synced package database, base-devel/git for building AUR packages,
# the yay AUR helper, and Homebrew (Linuxbrew) for anything not in either
# pacman's repos or the AUR. Vanilla Arch ships neither, so this bootstraps
# both from scratch the first time this script runs.
#
MODULE_DESC="Preconditions"

module_step() {
  # A pacman transaction killed mid-run (crash, power loss, Ctrl-C) can
  # leave a stale lock file that blocks every future pacman call. Only
  # remove it if no pacman process is actually running.
  if [ -f /var/lib/pacman/db.lck ] && ! pgrep -x pacman &>/dev/null; then
    warn "Removing a stale pacman lock file left over from an interrupted run."
    sudo rm -f /var/lib/pacman/db.lck
  fi

  sudo pacman -Sy --noconfirm || return 1
  pac_install base-devel git || return 1

  if command -v yay &>/dev/null; then
    log "yay already installed, skipping."
  else
    log "Bootstrapping yay (AUR helper)"
    local build_dir="$TMPDIR/yay"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir" || return 1
    # makepkg refuses to run as root, and must not be invoked with sudo.
    track_rollback "sudo pacman -Rns --noconfirm yay 2>/dev/null || true"
    (cd "$build_dir" && makepkg -si --noconfirm) || return 1
  fi

  _bootstrap_homebrew || return 1
  return 0
}

# Homebrew installs to /home/linuxbrew/.linuxbrew (or ~/.linuxbrew as a
# fallback on systems where the installer can't create /home/linuxbrew) and
# needs its own shellenv sourced — it's not on PATH by default the way
# pacman/AUR packages are.
_bootstrap_homebrew() {
  local prefix
  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    prefix="/home/linuxbrew/.linuxbrew"
  elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
    prefix="$HOME/.linuxbrew"
  else
    log "Bootstrapping Homebrew (Linuxbrew)"
    # Homebrew's own installer requires these; base-devel/git are already
    # covered above.
    pac_install procps-ng file || return 1
    track_rollback "sudo rm -rf /home/linuxbrew/.linuxbrew '$HOME/.linuxbrew' 2>/dev/null || true"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1

    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      prefix="/home/linuxbrew/.linuxbrew"
    elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
      prefix="$HOME/.linuxbrew"
    else
      err "Homebrew installer finished but no brew binary found."
      return 1
    fi
  fi

  eval "$("$prefix/bin/brew" shellenv)"
  local line="eval \"\$($prefix/bin/brew shellenv)\""
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    grep -qF "$line" "$rc" 2>/dev/null || { echo "$line" >> "$rc"; log "Added brew shellenv to $(basename "$rc")."; }
  done
  return 0
}
