# Bar

Replaces the DMS bar's **WM / Date / System-graphs / Notifications**
sections only. Battery and System Controls sections in the spec map onto
things DMS's bar already does reasonably (battery %, wifi/bt/volume icons) —
rebuild them here too since the spec asks for one cohesive 6-section bar, but
know that `Mod+X` (power menu), `Mod+Shift+V` (clipboard), `Mod+M` (task
manager), `Mod+Comma` (settings) stay pointed at DMS regardless — this bar
doesn't need to replicate those popups, just the icons/status that live in
its own Section 6.

## Keybindings

| Bind | Status |
|---|---|
| `Mod+N` | **Reused** — notification center toggle, was `dms ipc call notifications toggle`, becomes `qs -c desktopdesigner ipc call notificationCenter toggle` |

No other component in this spec owns a keybind — every other interaction
(window capsules, date popup, graph hover/click, system controls popup) is
mouse/click-driven per the spec itself. Don't invent global shortcuts for
them.

## Layout — 5 sections (spec numbers them 1–6, but WM+Date+Graphs+Notifications+Battery+System read as one visual "System" cluster on the right; keep the balanced-5-region description from the spec's own diagram)

```
┌────────────────────────────────────────────────────────────────┐
│   WM        DATE & TIME        SYSTEM GRAPHS   NOTIF   SYSTEM   │
└────────────────────────────────────────────────────────────────┘
```

Date always centered; other sections resize with monitor width via
`Layout.fillWidth` weighting, not fixed pixel widths — required for
ultrawide support the spec calls out explicitly.

## Directory structure

```
Bar/
├── WM/            # window capsules, direction indicator "(..|..)", drag-reorder
├── Clock/         # centered date/time + Calendar popup
├── Graphs/        # sparkline graphs per metric + threshold lines + dashboard popup
├── Notifications/ # bell icon + accent-colored unread dot + slide-down center
├── Battery/       # %, charging anim, time remaining — auto-hidden on desktops (no battery path in /sys/class/power_supply)
└── System/        # wifi/bt/volume/brightness/vpn/mic icons → opens NetworkCenter (07) / QuickControls
```

## Section 1 — WM (window capsules)

Data source: **Niri IPC**, not Hyprland IPC — the spec was written against a
Hyprland-flavored vocabulary (workspace/window events) but this setup's
compositor is Niri (per the prompt: "Desktop Manager: Niri"). Use
`niri msg -j event-stream` (a persistent JSON event stream over a socket) for
live window list/focus updates — no polling. Wrap it once in
`Services/Hyprland/` — name kept from the spec's own `Services/Hyprland/`
folder for continuity with the other docs, but implement it against Niri's
IPC socket (`$NIRI_SOCKET`), not Hyprland's.

Each open window on the active workspace → one capsule (icon only by
default, hover expands to icon+name+glow). Focused window gets accent
border. Left-click focus, middle-click close, right-click context menu
(Move/Float/Pin/Fullscreen/Send-to-workspace/Close) — all map onto Niri
IPC actions (`niri msg action focus-window`, `close-window`, etc.) run
through the same socket connection, not shelled-out `niri msg` calls per
click (keep one connection open, issue requests over it).

**Direction indicator** `(..|..)`: count windows left/right of the focused
column in the current workspace (Niri already models the workspace as
columns of windows — this maps directly onto niri's own column model, no
need to reinvent window ordering). Cap visible dots at 3, then `3+`.

## Section 2 — Date & Time + Calendar popup

Centered clock, minute-tick animation. Calendar popup on click: month grid,
week numbers, sunrise/sunset (compute from lat/long — either a config value
or IP-geolocation fallback, don't hardcode a location), moon phase (pure
math, no API/network call needed — a phase-from-date formula is ~10 lines).
Holidays and "upcoming events" are explicitly spec'd as future — leave them
out.

## Section 3 — System graphs

Sparklines, 60s rolling window, one `Services/Sensors/` poller per metric
family since these genuinely have no event source:

| Metric | Source | Poll interval |
|---|---|---|
| CPU | `/proc/stat` | 1s |
| RAM | `/proc/meminfo` | 1s |
| GPU (integrated/dedicated) | `hwmon` / vendor tool (`nvidia-smi` if present — this repo already has NVIDIA per `modules/13-nvidia.sh`) | 1s |
| Network | `/proc/net/dev` delta | 1s |
| Disk I/O | `/proc/diskstats` delta | 1s |
| Temp / Fan | `lm_sensors` (`sensors -j`) or `hwmon` directly | 1s |
| Battery power draw | `/sys/class/power_supply/*/power_now` | 1s |

1s is the spec's own refresh cadence for the fullscreen terminal clock's
status row — reuse it here too; this is the "absolutely no event source
exists" exception the overview doc calls out, not a violation of the
no-polling rule.

Threshold lines (80% red, 50% orange) are drawn as static overlay geometry
on the sparkline canvas, recomputed only when the graph's max value changes
— not redrawn every frame.

## Section 4 — Notifications

Bell icon, accent-colored dot (never hardcoded red) when unread > 0. Backend:
`Services/Notifications/` implementing the `org.freedesktop.Notifications`
DBus interface **only if** DMS's own listener is disabled/reconfigured to
hand off — right now `mako` owns notification display (per
`modules/26-dankmaterialshell.sh`'s own comments: "mako already owns that
[BusName]"). Decide explicitly before building this: either (a) this Bar's
notification center becomes the new DBus notification daemon and `mako` gets
disabled, or (b) it reads mako's history via mako's own IPC (`makoctl history`)
instead of owning the DBus name itself. Option (b) is less invasive — it
doesn't fight `mako`/`dms.service` over the `BusName`, which is exactly the
crash-loop bug `dms.service.override.conf` already had to work around once.
Prefer (b) unless there's a specific reason to fully replace mako.

## Section 5/6 — Battery & System controls

Battery: read `/sys/class/power_supply/BAT*/capacity` + `status`; hide the
whole section if no `BAT*` path exists (desktop system).

System controls icons (wifi/bt/volume/mic/vpn) are **status only** here —
clicking the wifi/bt icon opens [Network & Bluetooth Center](07-network-bluetooth.md).
Volume/brightness/mic get their own small popovers (spec calls this the
"Quick Control Center", inspired by Nothing OS) — build as
`Dashboards/QuickControls/`, shared trigger point for whichever icon was
clicked (wifi → Network tab, volume → Audio tab, etc.), not five separate
popups.

## Setup checklist

1. `Services/Hyprland/` (Niri IPC wrapper) + `WM/` — this is the part that
   most needs live verification against your actual workspace layout.
2. `Clock/` (no popup yet) — trivial, confirms Theme/ is wired.
3. `Graphs/` one metric at a time (CPU first), threshold lines, then the rest.
4. `Notifications/` — decide the mako-handoff question above before writing
   any DBus code.
5. `Battery/` + `System/` icons (status display only).
6. Calendar popup, Performance dashboard, Notification Center, Quick
   Controls — these are all "click opens a bigger view" and can be built
   incrementally after the bar itself is visually complete and stable.

## Deferred

Per-application volume mixer inside Quick Controls' Audio tab, HDR toggle,
gamma control, VPN management beyond a status icon — spec marks these
future/optional; skip for the initial build.
