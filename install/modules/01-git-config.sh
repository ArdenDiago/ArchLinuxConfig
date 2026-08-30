#!/usr/bin/env bash
#
# Git identity (asked interactively rather than hardcoded) plus an ed25519
# SSH key for GitHub, tagged with that same email, plus the GitHub CLI
# (gh) itself. Auth is deliberately not run inline here — 'gh auth login'
# is interactive (browser or device code) and would block the rest of
# the script waiting on the user. If a graphical session is already up,
# it's launched in its own detached terminal instead, so the user can log
# in on their own time without holding up everything after this module;
# on a bare TTY (e.g. the very first run, before Hyprland/Niri exist)
# there's nowhere to open a terminal, so it just prints instructions
# instead. All steps are idempotent: re-running this script won't
# re-prompt, regenerate a key, or reopen a login terminal if already done.
#
MODULE_DESC="Git identity + SSH key + GitHub CLI"

module_step() {
  pac_install git openssh github-cli || return 1

  local name email

  if git config --global user.name &>/dev/null && git config --global user.email &>/dev/null; then
    name="$(git config --global user.name)"
    email="$(git config --global user.email)"
    log "Git identity already configured: $name <$email>"
  else
    if [ ! -t 0 ]; then
      warn "Not running interactively — skipping git identity prompt."
      warn "Set it manually: git config --global user.name \"...\" && git config --global user.email \"...\""
      return 0
    fi

    read -rp "Git user.name: " name
    read -rp "Git user.email: " email

    if [ -z "$name" ] || [ -z "$email" ]; then
      warn "Name/email left blank — skipping git identity and SSH key setup."
      return 0
    fi

    git config --global user.name "$name"
    git config --global user.email "$email"
    log "Git identity set: $name <$email>"
  fi

  local key="$HOME/.ssh/id_ed25519"
  if [ -f "$key" ]; then
    log "SSH key already exists at $key, skipping."
  else
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    track_rollback "rm -f '$key' '$key.pub'"
    ssh-keygen -t ed25519 -C "$email" -f "$key" -N "" || return 1
    log "Generated a new ed25519 SSH key for $email."
  fi

  log "Public key — add this to https://github.com/settings/keys:"
  echo
  cat "$key.pub"
  echo

  if command -v wl-copy &>/dev/null; then
    # wl-copy forks a background daemon to keep serving the clipboard; left
    # unredirected it inherits stdout/stderr from run_step's tee pipe, which
    # then never sees EOF and hangs the whole step waiting on that fd.
    wl-copy < "$key.pub" >/dev/null 2>&1 && log "Copied to clipboard."
  fi

  if gh auth status &>/dev/null; then
    log "GitHub CLI already authenticated: $(gh auth status 2>&1 | grep -o 'as [^ ]*' | head -1)"
  elif [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v alacritty &>/dev/null; then
    # setsid + disown: fully detach from this script's process group so
    # the login terminal survives (and this step returns immediately)
    # regardless of how long the user takes to actually log in.
    setsid alacritty -e gh auth login >/dev/null 2>&1 &
    disown
    log "Opened 'gh auth login' in its own terminal — log in there whenever you're ready, this script isn't waiting on it."
  else
    warn "GitHub CLI not authenticated — 'gh auth login' opens a browser and waits for you, so it's not run here."
    warn "Log in yourself whenever you're ready: gh auth login"
  fi

  return 0
}
