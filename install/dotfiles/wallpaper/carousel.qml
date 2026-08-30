// Standalone Quickshell app (launched via `quickshell -p carousel.qml`, see
// select.sh) that shows wallpapers from ~/Pictures/Wallpapers as a centered
// carousel. Pure picker: it never touches swaybg itself — on Enter it writes
// the chosen absolute path to .picker-result and quits; select.sh reads that
// and applies the wallpaper, exactly as it did before with fuzzel. Kept as a
// separate step (rather than calling swaybg from here too) so the existing,
// already-correct pkill-then-respawn sequencing in select.sh doesn't need to
// be duplicated/reordered inside QML.
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string resultPath: Quickshell.env("HOME") + "/.config/wallpaper/.picker-result"
    readonly property string currentPath: Quickshell.env("HOME") + "/.config/wallpaper/current"

    property int currentIndex: 0
    property bool initialIndexApplied: false

    // Runs once, as soon as the folder listing is populated: jumps the
    // carousel to whatever wallpaper is currently applied (saved by
    // select.sh in the "current" file) instead of always opening back at
    // index 0, so reopening the picker continues from where you left off.
    function applyInitialIndex() {
        if (initialIndexApplied || wallpapers.count === 0)
            return;
        initialIndexApplied = true;
        const saved = currentFile.text().trim();
        if (!saved)
            return;
        for (let i = 0; i < wallpapers.count; i++) {
            if (root.pathAt(i) === saved) {
                root.currentIndex = i;
                return;
            }
        }
    }

    function pathAt(i) {
        if (i < 0 || i >= wallpapers.count)
            return "";
        const f = wallpapers.get(i, "filePath");
        return f ? f.toString().replace(/^file:\/\//, "") : "";
    }

    function nameAt(i) {
        if (i < 0 || i >= wallpapers.count)
            return "";
        const f = wallpapers.get(i, "fileName");
        return f ? f.toString() : "";
    }

    function confirmSelection() {
        if (wallpapers.count > 0)
            resultFile.setText(root.pathAt(root.currentIndex));
        Qt.quit();
    }

    function cancel() {
        Qt.quit();
    }

    FolderListModel {
        id: wallpapers
        folder: "file://" + root.wallpaperDir.split('/').map(s => encodeURIComponent(s)).join('/')
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        showDotAndDotDot: false
        caseSensitive: false
        sortField: FolderListModel.Name
        onCountChanged: root.applyInitialIndex()
    }

    // Read-only counterpart to select.sh's STATE_FILE — just tells us what's
    // currently applied so applyInitialIndex() can find it in the list.
    FileView {
        id: currentFile
        path: root.currentPath
        blockLoading: true
        printErrors: false
    }

    // Emptied before every launch by select.sh, so a stale result can never
    // leak into a run that was cancelled (see cancel(), which never writes).
    FileView {
        id: resultFile
        path: root.resultPath
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    PanelWindow {
        id: win

        // Monitor name is resolved by select.sh (hyprctl/niri msg, whichever
        // compositor is live) and passed in via env var — see select.sh for
        // why this can't be figured out reliably from inside a fresh
        // quickshell process instead.
        screen: {
            const name = Quickshell.env("WALLPAPER_CAROUSEL_MONITOR");
            const match = Quickshell.screens.find(s => s.name === name);
            return match || Quickshell.screens[0];
        }

        color: "transparent"

        WlrLayershell.namespace: "wallpaper-carousel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.55

            MouseArea {
                anchors.fill: parent
                onClicked: root.cancel()
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (wallpapers.count === 0) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.cancel();
                    event.accepted = true;
                    return;
                }
                switch (event.key) {
                case Qt.Key_H:
                case Qt.Key_K:
                case Qt.Key_Left:
                case Qt.Key_Up:
                    root.currentIndex = (root.currentIndex - 1 + wallpapers.count) % wallpapers.count;
                    event.accepted = true;
                    break;
                case Qt.Key_L:
                case Qt.Key_J:
                case Qt.Key_Right:
                case Qt.Key_Down:
                    root.currentIndex = (root.currentIndex + 1) % wallpapers.count;
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.confirmSelection();
                    event.accepted = true;
                    break;
                case Qt.Key_Escape:
                    root.cancel();
                    event.accepted = true;
                    break;
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(960, win.width * 0.75)
                height: Math.min(620, win.height * 0.75)
                radius: 24
                color: "#1e1e2e"
                border.color: "#313244"
                border.width: 1

                // Swallow clicks so tapping the card doesn't fall through to
                // the dim layer's cancel-on-click MouseArea behind it.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 18

                    Text {
                        text: wallpapers.count > 0 ? "Select Wallpaper" : "No wallpapers found"
                        color: "#cdd6f4"
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Item {
                        width: parent.width
                        height: 420
                        visible: wallpapers.count > 0

                        Row {
                            anchors.centerIn: parent
                            spacing: 24

                            Repeater {
                                model: 5

                                delegate: Item {
                                    id: slot
                                    required property int index
                                    readonly property int offset: index - 2
                                    readonly property int wIndex: ((root.currentIndex + offset) % wallpapers.count + wallpapers.count) % wallpapers.count
                                    readonly property bool isCenter: offset === 0
                                    readonly property int side: isCenter ? 380 : (Math.abs(offset) === 1 ? 150 : 80)

                                    width: side
                                    height: side
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: "#11111b"
                                        border.color: slot.isCenter ? "#89b4fa" : "#313244"
                                        border.width: slot.isCenter ? 3 : 1
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: wallpapers.count > 0 ? "file://" + root.pathAt(slot.wIndex) : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: slot.isCenter ? 400 : 160
                                            sourceSize.height: slot.isCenter ? 400 : 160
                                            opacity: slot.isCenter ? 1 : 0.45
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: wallpapers.count > 0 ? (root.nameAt(root.currentIndex) + "  (" + (root.currentIndex + 1) + "/" + wallpapers.count + ")") : "Add images to ~/Pictures/Wallpapers"
                        color: "#a6adc8"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: wallpapers.count > 0 ? "h/j/k/l or arrows to browse · Enter to apply · Esc to cancel" : "Esc to close"
                        color: "#6c7086"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
