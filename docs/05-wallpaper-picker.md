# Wallpaper Picker

Upgrades the existing `carousel.qml` / `select.sh` (already Quickshell-based
— `dotfiles/wallpaper/carousel.qml`, `select.sh`, `restore.sh`, installed by
`modules/23-wallpaper.sh`). This is the smallest step in the whole batch:
the reference repo already ships a working centered-carousel wallpaper
picker on `Mod+W`. Read `dotfiles/wallpaper/carousel.qml` before writing
anything new — reuse whatever of it already works (image scanning, apply
mechanism) rather than rebuilding from zero.

## Keybinding

| Bind | Status |
|---|---|
| `Mod+W` | **Reused** — was `spawn-sh "~/.config/wallpaper/select.sh"`, becomes `qs -c desktopdesigner ipc call wallpaperPicker toggle` |

`Mod+Y` (DMS's separate dankdash wallpaper browser) is untouched — see
[`KEYBINDINGS.md`](../KEYBINDINGS.md).

## What's actually new vs. the existing carousel

| Existing (`carousel.qml`) | New spec asks for |
|---|---|
| Basic h/j/k/l carousel | Cover-flow style: center biggest+opaque, sides shrink/fade progressively |
| (check current styling) | Material Design 3 surface/elevation/rounded corners, matching the rest of `desktopdesigner`'s `Theme/` |
| Directory scan | Same directory scan + **filesystem watcher** (inotify) so new wallpapers appear without reopening |
| Direct apply | Same, plus wallpaper metadata line (resolution/size/modified/index) and search field |

## Directory structure

```
WallpaperPicker/
├── WallpaperPicker.qml
├── WallpaperOverlay.qml     # 55–65% dim, no blur/glass — matches Spotlight's overlay treatment
├── WallpaperCarousel.qml    # cover-flow layout
├── WallpaperThumbnail.qml
├── WallpaperInfo.qml        # filename, resolution, modified, size, "N / total"
├── SearchField.qml
├── EmptyState.qml
├── WallpaperController.qml
├── Models/
│   └── WallpaperModel.qml
├── Services/
│   ├── WallpaperScanner.qml    # directory scan, ~/Pictures/Wallpapers default
│   ├── ThumbnailCache.qml      # lazy-load + cache, preload neighbors only
│   ├── WallpaperBackend.qml    # abstracts swww/hyprpaper/swaybg — see below
│   └── FilesystemWatcher.qml   # inotify via Quickshell's FileView/folder watch
└── Components/
```

## Backend abstraction

Check what `select.sh`/`restore.sh` currently call to actually set the
wallpaper before picking a backend here — **reuse that**, don't switch
wallpaper daemons as a side effect of this rebuild. `WallpaperBackend.qml`
should be a thin interface (`apply(path)`) with one implementation matching
whatever's already installed (`swww` is the common Niri-ecosystem choice and
is likely what `restore.sh` already drives on session start — confirm before
assuming).

## Cover-flow carousel

Center thumbnail: largest, full opacity, accent border, highest elevation.
Neighbors shrink/fade with distance from center — a `PathView` with a custom
`path` (or a `ListView` with per-delegate `scale`/`opacity` bound to distance
from `currentIndex`) is the right QML primitive here; this is a standard
"coverflow" pattern, not something requiring a new algorithm.

Keyboard: ←/→/↑/↓/H/L move selection, Enter applies, Esc cancels, Home/End
jump to first/last, mouse wheel scrolls, click selects, double-click
applies-and-closes. All local to this QML's focus scope.

## Setup checklist

1. Read the existing `carousel.qml` fully — identify what's reusable
   (scanning, apply call) vs. what needs rebuilding (cover-flow visuals,
   Material theming).
2. `WallpaperScanner.qml` + `FilesystemWatcher.qml` — confirm the watcher
   actually fires on file add/remove in `~/Pictures/Wallpapers` before
   building UI around it.
3. `WallpaperCarousel.qml` + `WallpaperThumbnail.qml` with the scanned list,
   no search/apply yet — get the cover-flow motion right.
4. `WallpaperInfo.qml` + `SearchField.qml`.
5. Wire `WallpaperBackend.qml` to the confirmed-existing apply mechanism,
   test apply-and-close end to end.
6. Swap `Mod+W`'s target in `config.kdl`, keep `select.sh` around
   untouched/uninstalled-later rather than deleted in the same change.

## Deferred

Multi-monitor per-output wallpapers, collections/tags/favorites/recently-used,
slideshow mode, time-of-day wallpapers, AI generation, EXIF viewer, cloud
sync — all spec'd as future. Categories: ship "All Wallpapers" only, per the
spec's own note that this is fine for the initial build.
