import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme

// docs/05-wallpaper-picker.md MVP: directory scan, cover-flow-style
// carousel (manual index-distance scaling rather than a full PathView —
// same visual result, far less code), keyboard nav, apply via detected
// backend. Filesystem watcher (live-refresh on new files) and search are
// deferred — rescans on open, which is fine until the collection is large
// enough for that to be annoying.
PanelWindow {
    id: root
    property bool active: false
    visible: active
    focusable: active

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // ponytail: override via WALLPAPER_DIR for testing without needing a
    // real ~/Pictures/Wallpapers full of images. Real default per spec.
    readonly property string wallpaperDir: {
        const override = Quickshell.env("WALLPAPER_DIR");
        return override && override.length > 0 ? override : (Quickshell.env("HOME") + "/Pictures/Wallpapers");
    }

    property var images: []
    property int currentIndex: 0
    readonly property string currentPath: images.length > 0 ? images[currentIndex] : ""

    onActiveChanged: if (active)
        scanProcess.running = true

    function open() {
        active = true;
    }

    function close() {
        active = false;
    }

    function toggle() {
        active = !active;
    }

    function apply() {
        if (!currentPath)
            return;
        backendDetect.running = true;
    }

    Process {
        id: scanProcess
        command: ["sh", "-c", `find "${root.wallpaperDir}" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.split("\n").filter(l => l.length > 0);
                root.currentIndex = 0;
            }
        }
    }

    // Backend abstraction per docs/05: prefer swww if present, else just
    // update currentPath (the preview below already renders it — visible
    // confirmation even with no wallpaper daemon installed, e.g. in this
    // test container).
    Process {
        id: backendDetect
        command: ["sh", "-c", `command -v swww >/dev/null 2>&1 && swww img "${root.currentPath}" || echo NO_BACKEND`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "NO_BACKEND")
                    console.log("WallpaperPicker: no swww backend found, preview-only apply of", root.currentPath);
                root.close();
            }
        }
    }

    // Dim backdrop — no blur/glass per spec.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.6
    }

    // Live preview of the selected wallpaper filling the background, behind the carousel.
    Image {
        anchors.fill: parent
        source: root.currentPath ? "file://" + root.currentPath : ""
        fillMode: Image.PreserveAspectCrop
        opacity: 0.35
        asynchronous: true
        cache: false
    }

    Column {
        anchors.centerIn: parent
        spacing: 24

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Wallpaper Picker"
            color: Theme.color.surfaceText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.large
        }

        Item {
            width: 640
            height: 260
            visible: root.images.length > 0

            Repeater {
                model: root.images
                delegate: Item {
                    id: thumb
                    required property int index
                    required property string modelData

                    readonly property int distance: index - root.currentIndex
                    readonly property real absDistance: Math.abs(distance)
                    readonly property bool isCurrent: distance === 0

                    width: 160
                    height: 200
                    x: 640 / 2 - width / 2 + distance * 130
                    y: 260 / 2 - height / 2
                    z: -absDistance
                    scale: isCurrent ? 1.0 : Math.max(0.55, 1.0 - absDistance * 0.18)
                    opacity: absDistance > 3 ? 0 : Math.max(0.25, 1.0 - absDistance * 0.28)

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animationNormal
                            easing.type: Theme.easing
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animationNormal
                            easing.type: Theme.easing
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationNormal
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.medium
                        color: Theme.color.surfaceContainer
                        border.width: thumb.isCurrent ? 2 : 0
                        border.color: Theme.color.accent

                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false

                            layer.enabled: true
                        }
                    }

                    TapHandler {
                        onTapped: root.currentIndex = thumb.index
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.images.length === 0
            text: "No wallpapers found in " + root.wallpaperDir
            color: Theme.color.surfaceVariantText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.normal
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.images.length > 0
            text: (root.currentPath.split("/").pop() || "") + "   " + (root.currentIndex + 1) + " / " + root.images.length
            color: Theme.color.surfaceVariantText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.small
        }
    }

    Item {
        anchors.fill: parent
        focus: root.active
        Keys.onLeftPressed: root.currentIndex = Math.max(0, root.currentIndex - 1)
        Keys.onRightPressed: root.currentIndex = Math.min(root.images.length - 1, root.currentIndex + 1)
        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: root.apply()
    }
}
