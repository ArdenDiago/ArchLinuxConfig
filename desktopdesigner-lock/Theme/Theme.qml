pragma Singleton
import QtQuick
import Quickshell

// Single shared theme singleton (Colors/Fonts/Radius collapsed into one file —
// at this size a 4-file split just adds navigation cost for no benefit; split
// out if/when any one section actually grows unwieldy).
//
// ponytail: static Material-ish palette, not wallpaper-derived. matugen is
// already installed on this system (dankmaterialshell uses it) and writes
// theme fragments as plain files — the real upgrade path is a FileView on
// matugen's generated colors.json/scss here, not a custom color-extraction
// pipeline. Static palette is the correct starting point until that's wired up.
Singleton {
    readonly property QtObject color: QtObject {
        readonly property color background: "#131318"
        readonly property color surface: "#1d1d24"
        readonly property color surfaceContainer: "#26262e"
        readonly property color surfaceContainerHigh: "#302f3a"
        readonly property color outline: "#48454e"
        readonly property color surfaceText: "#e6e1e9"
        readonly property color surfaceVariantText: "#a8a5ad"

        readonly property color accent: "#a8c7fa"
        readonly property color accentText: "#0a2f5c"
        readonly property color accentContainer: "#28456b"

        readonly property color error: "#f2b8b5"
        readonly property color warning: "#f5c99b"
        readonly property color success: "#a8d8b9"

        // Bar sparkline series colors — see docs/02-bar.md's metric table.
        readonly property color cpu: "#8ab4f8"
        readonly property color ram: "#c58af9"
        readonly property color gpu: "#81c995"
        readonly property color network: "#78d9ec"
    }

    readonly property QtObject radius: QtObject {
        readonly property int small: 8
        readonly property int medium: 14
        readonly property int large: 20
    }

    readonly property QtObject font: QtObject {
        // ponytail: hardcoded to what's actually installed in the test
        // container (ttf-dejavu). Real target system should have DMS's own
        // font stack already (modules/26-dankmaterialshell.sh) — swap for
        // whatever that provides (Inter/Roboto-ish) once building for real.
        readonly property string family: "DejaVu Sans"
        readonly property string mono: "DejaVu Sans Mono"
        readonly property int small: 12
        readonly property int normal: 14
        readonly property int large: 18
        readonly property int display: 40
    }

    readonly property int animationFast: 150
    readonly property int animationNormal: 200
    readonly property int easing: Easing.OutCubic
}
