# Lock Screen (+ Snake game)

Replaces: **hyprlock** (`dotfiles/hypr/hyprlock.conf`, installed by
`modules/24-lockscreen.sh`). SDDM + Qylock (`modules/22-login-theme.sh`,
`modules/14-display-manager.sh`) stays as the actual login greeter —
**unchanged**. The source spec talks about greetd/login-screen, but this repo
uses SDDM, not greetd; scope this build to the *lock* screen only (what
`Mod+Alt+L` and idle-lock trigger post-login), which is the part that
actually replaces something real here. Treat greetd/PAM-login-manager support
as a documented future option, not something to build now (nothing in this
repo runs greetd, so there's nothing to integrate against yet).

## Keybinding

| Bind | Status |
|---|---|
| `Mod+Alt+L` | **Reused** — was `spawn "hyprlock"`, becomes `spawn "loginctl" "lock-session"` (see Activation below) |
| `Ctrl+G` (enter Snake) | New, scoped to this QML's own `Keys.onPressed` — lock-screen-local, not a compositor bind |
| `Esc` (exit Snake) | New, same local scope |

Full resolution + "why" lives in [`KEYBINDINGS.md`](../KEYBINDINGS.md).

## Activation mechanism

Don't spawn the lock QML directly from the niri bind — that's how the
current hyprlock setup works, but it means anything that can kill/crash the
lock process (or just the user hitting Alt+F4-equivalent) fully unlocks the
session with no re-auth. Use the standard two-layer pattern instead:

1. A tiny systemd user service (or a Quickshell background process already
   running) listens for `org.freedesktop.login1.Session.Lock` via
   `systemd-logind`, and for idle timeout via `swayidle`-equivalent
   (`niri`'s own idle-notify protocol, or `swayidle` spawning
   `loginctl lock-session`).
2. `Mod+Alt+L` calls `loginctl lock-session` (not the QML binary directly).
   `logind` then emits the `Lock` signal, which the listener catches and
   launches `qs -c desktopdesigner-lock`, which grabs the Wayland
   `ext-session-lock-v1` protocol (same protocol hyprlock/swaylock use — this
   is what actually blocks input from reaching the session, not the QML app
   itself).
3. On successful auth, the QML calls `session_unlock()` against the
   `ext-session-lock-v1` handle and exits its own process.

This means killing the QML process alone (SIGKILL, crash) does **not**
unlock the session — the compositor keeps the lock surface until the
protocol is told to release it, which only successful PAM auth triggers.
That's the actual security property hyprlock relies on today; preserve it.

## Why a separate Quickshell instance

`qs -c desktopdesigner-lock`, not a `Loader` inside the main `desktopdesigner`
shell. Reasons, in priority order:

- The main shell (Bar, Spotlight, etc.) runs as the logged-in user with full
  session access. The lock screen must keep working even if that process
  crashes, gets OOM-killed, or is compromised — sharing a process defeats
  that isolation.
- PAM conversation state (the password buffer, the authentication handle)
  must never be reachable from anything that also loads user-session QML
  (Spotlight providers, Quick Notes, etc.) — process separation is the
  simplest way to guarantee that rather than relying on QML-level scoping.
- `Services/PAM/`, `Services/Authentication/`, `Services/Session/` under this
  config are **not** shared with `desktopdesigner/Services/` — duplicate the
  small amount of overlap (Users/, Wallpaper/) rather than importing across
  the process boundary.

## Directory structure

```
desktopdesigner-lock/
├── LockScreen.qml       # top-level: composes everything below
├── LoginView.qml        # avatar + username/dropdown + password field
├── UserSelector.qml     # multi-user dropdown, sorted: current → recent → alphabetical
├── PasswordField.qml    # hidden input, reveal toggle, caps/num-lock indicators, shake-on-fail
├── Clock.qml            # HH:MM + weekday/date, minute-boundary animation
├── Wallpaper.qml         # blur/tint/parallax, multi-monitor aware
├── IdleMode.qml          # 15s-default idle → fade UI, keep clock+wallpaper
├── SnakeGame/
│   ├── Snake.qml  Board.qml  GameEngine.qml  Scoreboard.qml
└── Components/

Services/
├── PAM/            # pam_authenticate() wrapper, async, off the render thread
├── Authentication/ # orchestrates PAM + (future) fprintd/pkcs11, exposes one signal-based API to LoginView
├── Users/           # enumerate /etc/passwd (uid >= 1000, or just $USER for single-user), avatar/initials fallback
├── Wallpaper/        # read current wallpaper path (same source select.sh/carousel.qml write to)
└── Session/          # ext-session-lock-v1 grab/release, idle-notify subscription
```

## Dependencies

```bash
pacman -S quickshell qt6-base qt6-declarative pam
```

PAM auth from QML needs a small native helper — Quickshell doesn't expose
`libpam` directly. Two options, pick the one that matches how much C++ you
want to maintain:

- A minimal C helper binary (`pam_authenticate` for the `login` or a custom
  `desktopdesigner` PAM service file under `/etc/pam.d/`) invoked via
  `Quickshell.Io.Process`, stdin/stdout JSON, one line in / one line out.
  Simplest, but a process spawn per auth attempt.
- A Quickshell C++ plugin exposing a QML-callable async PAM object. More
  work, no process-spawn overhead. Only worth it if the process-spawn
  approach measurably fails the "async, never freeze the UI" requirement —
  it won't at one attempt every few seconds, so start with the helper binary.

Add `/etc/pam.d/desktopdesigner` mirroring `/etc/pam.d/login` (or just point
at `system-auth` the way most Arch PAM services do) rather than inventing PAM
stack rules from scratch.

## Security requirements (non-negotiable, from the spec)

- Password buffer is a `QByteArray`/char array that gets explicitly zeroed
  immediately after the PAM call returns, success or failure — not left to
  QML string GC. A plain QML `string` for the password field is *not*
  acceptable for the final buffer handed to PAM; convert at the boundary.
- No `console.log`, no `Quickshell.Io.Process` argv, no signal payload ever
  carries the raw password.
- The lock screen ignores any shortcut not explicitly whitelisted in its own
  `Keys.onPressed` (i.e. it should NOT inherit niri's global binds while
  locked — `ext-session-lock-v1` already gives it exclusive input, so this is
  mostly about not building an accidental escape hatch into the QML itself).
- Snake game must not get a reference to anything session-related — it's a
  self-contained `GameEngine.qml` with no import of `Services/Authentication`
  or `Services/Session`.

## Idle mode

Default 15s timeout, shared behavior/timing constant with whatever Login/Signup
screens exist later (none exist in this repo today — just document the
constant in `Theme/` or a shared `IdleMode.qml` config value so it's not
duplicated if one gets built). Fade password/username/buttons, keep
clock+date+wallpaper, restore on any input without clearing the password
buffer unless the idle timeout itself is configured to force-clear (off by
default, per spec: "unless timed out for security reasons" — leave that a
config flag, default false, since the spec doesn't mandate force-clear).

## Setup checklist

1. Build `Services/Session/` first — get an `ext-session-lock-v1` grab
   working with a **blank** QML rectangle before any UI. Verify locked
   session actually blocks input and that `loginctl lock-session` triggers
   it, in `temp/`, before writing any LoginView.
2. Add `Clock.qml` + `Wallpaper.qml` — visually confirm layout before wiring
   auth (nothing here needs PAM to test).
3. Wire `PasswordField.qml` to a **stub** `Services/Authentication` that
   always succeeds/fails on a fixed string, to get animations (shake,
   success, loading) right without touching real PAM.
4. Swap the stub for real `Services/PAM/`, test with your actual account
   password in a nested session — never on your only unlocked TTY.
5. Add `IdleMode.qml`.
6. Add `SnakeGame/` last — fully decorative relative to the auth flow, zero
   risk of blocking the security-critical path if it's last.
7. Wire `Mod+Alt+L` → `loginctl lock-session` in `config.kdl`, replacing the
   `spawn "hyprlock"` line. Keep `hyprlock` installed/configured as a
   fallback until the new lock screen has been used for real for a while —
   don't uninstall it in the same change that switches the bind.

## Deferred (spec says "future", keep it that way)

Fingerprint (fprintd), smart cards, screen readers. Don't scaffold interfaces
for these now — `Services/Authentication/` should expose one
`authenticate(password) -> Promise/signal` API; adding a second auth method
later means adding a second function to that same service, not building a
plugin system for auth methods nobody's implementing yet.
