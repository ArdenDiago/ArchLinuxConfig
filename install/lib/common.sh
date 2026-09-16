#!/usr/bin/env bash
#
# Shared helpers sourced once by setup.sh and used by every module.
# Not meant to be executed directly.
#

# ---------------------------------------------------------------------------
# Color setup — respects NO_COLOR (https://no-color.org) and falls back to
# plain text when stdout isn't a terminal (e.g. piped into a log file) or
# the terminal doesn't support enough colors.
# ---------------------------------------------------------------------------
_supports_color() {
  [ -t 1 ] || return 1
  [ -z "${NO_COLOR:-}" ] || return 1
  command -v tput &>/dev/null || return 1
  [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]
}

if _supports_color; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[38;5;203m'
  C_GREEN=$'\033[38;5;114m'
  C_YELLOW=$'\033[38;5;221m'
  C_CYAN=$'\033[38;5;80m'
  C_MAGENTA=$'\033[38;5;176m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN='' C_MAGENTA=''
fi

log()  { echo -e "\n${C_BOLD}${C_GREEN}➜${C_RESET} ${C_BOLD}$*${C_RESET}"; }
warn() { echo -e "${C_BOLD}${C_YELLOW}⚠${C_RESET}  ${C_YELLOW}$*${C_RESET}"; }
err()  { echo -e "${C_BOLD}${C_RED}✖${C_RESET}  ${C_RED}$*${C_RESET}"; }
ok()   { echo -e "${C_BOLD}${C_GREEN}✓${C_RESET}  ${C_GREEN}$*${C_RESET}"; }

FAILED_STEPS=()

# ---------------------------------------------------------------------------
# Rollback tracking. Each module gets a clean slate (reset_rollback_state)
# right before it runs. Modules register undo actions as they go via
# track_rollback and the pac_install/aur_install wrappers below; if the
# module's step function returns non-zero, run_step calls
# rollback_current_step to undo everything registered so far, so a failed
# step doesn't leave the system half-configured.
# ---------------------------------------------------------------------------
_ROLLBACK_ACTIONS=()
_NEW_PACMAN_PKGS=()
_NEW_AUR_PKGS=()

reset_rollback_state() {
  _ROLLBACK_ACTIONS=()
  _NEW_PACMAN_PKGS=()
  _NEW_AUR_PKGS=()
}

# track_rollback "shell command to undo something this module just did"
# Registered actions run in reverse order (last done, first undone) if the
# current module fails.
track_rollback() { _ROLLBACK_ACTIONS+=("$1"); }

rollback_current_step() {
  local did_something=0 i

  for (( i=${#_ROLLBACK_ACTIONS[@]}-1; i>=0; i-- )); do
    did_something=1
    bash -c "${_ROLLBACK_ACTIONS[$i]}" &>/dev/null || true
  done

  if [ "${#_NEW_AUR_PKGS[@]}" -gt 0 ]; then
    did_something=1
    sudo pacman -Rns --noconfirm "${_NEW_AUR_PKGS[@]}" &>/dev/null || true
  fi
  if [ "${#_NEW_PACMAN_PKGS[@]}" -gt 0 ]; then
    did_something=1
    sudo pacman -Rns --noconfirm "${_NEW_PACMAN_PKGS[@]}" &>/dev/null || true
  fi

  [ "$did_something" -eq 1 ] && warn "Rolled back the partial changes from this step."
}

pac_installed() { pacman -Qi "$1" &>/dev/null; }

# Installs one or more official-repo packages via pacman. --needed makes
# this naturally idempotent: already-installed packages are skipped. Only
# packages that weren't already present get recorded for rollback, so a
# later failure in the same module won't remove something the user already
# had installed before this script ran.
pac_install() {
  local pkg newly=()
  for pkg in "$@"; do
    pac_installed "$pkg" || newly+=("$pkg")
  done
  sudo pacman -S --needed --noconfirm "$@" || return 1
  _NEW_PACMAN_PKGS+=("${newly[@]}")
  return 0
}

aur_installed() { pacman -Qi "$1" &>/dev/null; }

# Installs one or more AUR packages via yay. Never run yay as root/sudo —
# it escalates internally only for the pacman parts it needs.
aur_install() {
  if ! command -v yay &>/dev/null; then
    err "yay is not available — cannot install AUR package(s): $*"
    return 1
  fi
  local pkg newly=()
  for pkg in "$@"; do
    aur_installed "$pkg" || newly+=("$pkg")
  done
  yay -S --needed --noconfirm "$@" || return 1
  _NEW_AUR_PKGS+=("${newly[@]}")
  return 0
}

# ensure_on_path <command-name> <candidate-path-or-glob> [more candidates...]
# Some installers (curl-based ones especially) are supposed to drop a
# symlink on PATH but sometimes don't (e.g. a known upstream bug in the
# Claude Code native installer skipping the ~/.local/bin/claude symlink).
# This checks whether <command-name> already resolves; if not, it searches
# the candidate paths/globs for a real executable and links it into
# ~/.local/bin so it works globally right away, in this same shell too.
ensure_on_path() {
  local name="$1"; shift
  if command -v "$name" &>/dev/null; then
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  local link="$HOME/.local/bin/$name"
  local pattern f
  for pattern in "$@"; do
    for f in $pattern; do
      if [ -f "$f" ] && [ -x "$f" ]; then
        if [ "$f" -ef "$link" ]; then
          log "'$name' is already at $f — adding ~/.local/bin to PATH is enough."
        else
          ln -sf "$f" "$link"
          log "Linked '$name' -> $f — it now runs from anywhere, no path needed."
        fi
        export PATH="$HOME/.local/bin:$PATH"
        hash -r
        return 0
      fi
    done
  done

  warn "Could not find a '$name' binary to link into ~/.local/bin — you'll need to run it by its full path for now."
  return 1
}

# install_dotfile <src> <dest>
# Copies src over dest. Skips if they're already identical. If dest exists
# and differs, backs it up to dest.bak — but only the first time, so the
# backup always holds whatever was there before this script ever touched
# it, not a stale copy from a previous run.
install_dotfile() {
  local src="$1" dest="$2"
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    log "$(basename "$dest") already up to date, skipping."
    return 0
  fi
  if [ -f "$dest" ] && [ ! -f "$dest.bak" ]; then
    cp "$dest" "$dest.bak"
    warn "Backed up your existing $(basename "$dest") to $(basename "$dest").bak"
  fi
  cp "$src" "$dest"
  log "Installed $(basename "$dest")."
}

# ---------------------------------------------------------------------------
# Step runner. Captures the step's combined output (so it can be written to
# ERROR_LOG on failure) while still streaming it live to the terminal, runs
# rollback on failure, and never aborts the overall script.
# ---------------------------------------------------------------------------
run_step() {
  local desc="$1"; shift
  reset_rollback_state

  local capture="$TMPDIR/last-step-output.log"
  : > "$capture"

  local out_fd
  exec {out_fd}> >(tee -a "$capture")
  local tee_pid=$!

  local status=0
  "$@" >&"$out_fd" 2>&"$out_fd" || status=$?

  exec {out_fd}>&-
  wait "$tee_pid" 2>/dev/null || true

  if [ "$status" -eq 0 ]; then
    return 0
  fi

  err "Step failed: $desc — continuing with the rest of the script."
  rollback_current_step
  FAILED_STEPS+=("$desc")

  if [ -n "${ERROR_LOG:-}" ]; then
    {
      echo "===== $(date '+%Y-%m-%d %H:%M:%S') — $desc ====="
      cat "$capture"
      echo
    } >> "$ERROR_LOG"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Terminal UI: banner + boxed summary. Purely cosmetic — safe to ignore if
# you're grepping logs, since box-drawing degrades gracefully to plain text
# lines when NO_COLOR is set or output isn't a terminal (colors drop out,
# the unicode border characters remain but stay readable).
# ---------------------------------------------------------------------------
_box_width=56

_box_border() { printf '─%.0s' $(seq 1 "$_box_width"); }

# _box_line "text" "color-code"
# Centers `text` inside a box of width $_box_width using printf's own
# character counting, so it stays correct regardless of text length.
_box_line() {
  local text="$1" color="$2"
  local pad=$(( _box_width - ${#text} ))
  (( pad < 0 )) && pad=0
  local pad_left=$(( pad / 2 ))
  local pad_right=$(( pad - pad_left ))
  printf "%b│%b%*s%s%*s%b│%b\n" \
    "$color" "$C_RESET" "$pad_left" "" "$text" "$pad_right" "" "$color" "$C_RESET"
}

banner() {
  echo
  echo -e "${C_MAGENTA}╭$(_box_border)╮${C_RESET}"
  _box_line "ARCH LINUX SETUP" "${C_BOLD}${C_CYAN}"
  echo -e "${C_MAGENTA}╰$(_box_border)╯${C_RESET}"
  echo -e "${C_DIM}  Vanilla Arch — Niri${C_RESET}"
  echo -e "${C_DIM}  DankMaterialShell is NOT installed here — noctalia replaces it${C_RESET}"
  echo -e "${C_DIM}  on the Niri session (see modules/16-niri.sh).${C_RESET}"
}

# summary_box "color" "line one" "line two" ...
summary_box() {
  local color="$1"; shift
  echo -e "${color}╭$(_box_border)╮${C_RESET}"
  local line
  for line in "$@"; do
    _box_line "$line" "$color"
  done
  echo -e "${color}╰$(_box_border)╯${C_RESET}"
}

format_duration() {
  local total="$1" m s
  m=$(( total / 60 ))
  s=$(( total % 60 ))
  if [ "$m" -gt 0 ]; then
    printf '%dm %ds' "$m" "$s"
  else
    printf '%ds' "$s"
  fi
}
