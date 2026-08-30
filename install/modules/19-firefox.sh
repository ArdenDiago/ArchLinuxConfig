#!/usr/bin/env bash
#
# Firefox, plus two personal customizations that used to require fully
# manual setup:
#
#   - ArcFox (https://github.com/betterbrowser/arcfox), an Arc-browser-style
#     userChrome.css + extension pair. The userChrome.css is fetched fresh
#     from its latest GitHub release (upstream is the source of truth, so
#     nothing is vendored here) and copied into every profile found in
#     profiles.ini, along with the one about:config pref it requires.
#
#   - The New Tab extension (firefox-newtab-pomodoro/, at the repo root,
#     shared with the Omarchy setup) is packaged into a .xpi, ready to
#     install, but NOT force-installed automatically.
#
# Both extensions (ArcFox's and the New Tab one) stay a single manual
# install step each: about:addons -> gear icon -> Install Add-on From
# File. Three different unattended install paths were tried against a
# real running profile for the New Tab extension — enterprise policy
# ExtensionSettings, an unpacked-directory sideload, and a .xpi dropped
# straight into extensions/ — and none of them actually showed up in the
# profile's extensions.json on this Firefox version. Rather than ship
# automation that silently doesn't work, both extensions follow the same
# proven-manual path.
#
# The niri/Wayland fixes (native Wayland rendering, screen-share, file
# picker) live in modules/16-niri.sh instead, since they're env vars and
# a portal config that niri itself needs to own, not something scoped to
# the Firefox package. See that module and dotfiles/niri/niri-portals.conf.
#
MODULE_DESC="Firefox"

FIREFOX_EXT_SRC="$SCRIPT_DIR/firefox-newtab-pomodoro"
FIREFOX_EXT_ID="newtab-pomodoro@linux-conf.local"
ARCFOX_CHROME_URL="https://github.com/betterbrowser/arcfox/releases/latest/download/userChrome.css"
ARCFOX_XPI_URL="https://addons.mozilla.org/firefox/downloads/latest/arcfox/"

# _ensure_user_pref <file> <name> <value>
# Idempotently ensures a user_pref line exists in a Firefox prefs file,
# replacing any existing line for the same pref instead of duplicating
# it or clobbering whatever else is already in the file.
_ensure_user_pref() {
  local file="$1" name="$2" value="$3"
  local line="user_pref(\"$name\", $value);"
  touch "$file"
  if grep -q "\"$name\"" "$file"; then
    sed -i "s|.*\"$name\".*|$line|" "$file"
  else
    echo "$line" >> "$file"
  fi
}

# _setup_profile <profile-dir> <userChrome.css source>
# Drops ArcFox's userChrome.css into <profile>/chrome/ (a re-run always
# overwrites, same as install_dotfile would for a single file) and
# idempotently sets every pref it needs, plus
# xpinstall.signatures.required=false so the New Tab extension's
# unsigned .xpi will actually install from the manual step below instead
# of being rejected.
_setup_profile() {
  local profile_dir="$1" chrome_css="$2"
  mkdir -p "$profile_dir/chrome"
  cp "$chrome_css" "$profile_dir/chrome/userChrome.css"

  _ensure_user_pref "$profile_dir/user.js" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
  _ensure_user_pref "$profile_dir/user.js" "xpinstall.signatures.required" "false"
}

module_step() {
  pac_install firefox zip || return 1

  local moz_dir="$HOME/.mozilla/firefox"
  local profiles_ini="$moz_dir/profiles.ini"
  mkdir -p "$moz_dir"

  if [ ! -f "$profiles_ini" ]; then
    log "No Firefox profile yet — creating one."
    mkdir -p "$moz_dir/default-release"
    cat > "$profiles_ini" << 'EOF'
[Profile0]
Name=default
IsRelative=1
Path=default-release
Default=1

[General]
StartWithLastProfile=1
Version=2
EOF
  fi

  local ext_dir="$HOME/.local/share/firefox-extensions"
  mkdir -p "$ext_dir"

  local arcfox_css="$ext_dir/arcfox-userChrome.css"
  curl --retry 5 --retry-delay 3 --retry-all-errors -fsSL "$ARCFOX_CHROME_URL" -o "$arcfox_css" || return 1
  log "Fetched ArcFox userChrome.css from upstream."

  local rel_path found=0
  while IFS= read -r rel_path; do
    found=1
    _setup_profile "$moz_dir/$rel_path" "$arcfox_css"
    log "Applied ArcFox theme + prefs to profile: $rel_path"
  done < <(grep -oP '^Path=\K.*' "$profiles_ini")

  if [ "$found" -eq 0 ]; then
    warn "Could not find any profile path in $profiles_ini — theme not applied."
  fi

  local arcfox_xpi="$ext_dir/arcfox.xpi"
  curl --retry 5 --retry-delay 3 --retry-all-errors -fsSL "$ARCFOX_XPI_URL" -o "$arcfox_xpi" || return 1
  log "Fetched ArcFox extension: $arcfox_xpi"

  local xpi="$ext_dir/$FIREFOX_EXT_ID.xpi"
  if [ ! -f "$xpi" ] || [ "$FIREFOX_EXT_SRC/manifest.json" -nt "$xpi" ]; then
    rm -f "$xpi"
    (cd "$FIREFOX_EXT_SRC" && zip -qr "$xpi" .) || return 1
    log "Packaged New Tab extension: $xpi"
  fi

  log "Two manual steps left for the extensions (about:addons won't let"
  log "  an unattended script click through its own file picker):"
  log "  about:addons -> gear icon (top right) -> Install Add-on From File"
  log "  -> select $arcfox_xpi (ArcFox)"
  log "  -> select $xpi (New Tab)"

  if pgrep -x firefox &>/dev/null; then
    warn "Firefox is running — restart it for the theme/prefs to take effect."
  fi

  return 0
}
