import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Theme

// docs/04-notepad.md MVP: slide-in-from-right panel, flush edge, plain
// TextArea, in-memory session persistence. Persistence is implicit here —
// Quickshell unmaps (doesn't destroy) a PanelWindow on visible:false, so the
// TextArea's own `text` property already survives hide/show without a
// separate SessionStore.qml; that file only earns its keep once optional
// disk persistence (spec's deferred feature) actually gets built.
PanelWindow {
    id: root
    property bool active: false
    visible: active
    focusable: active

    anchors {
        top: true
        bottom: true
        right: true
    }
    implicitWidth: 380
    color: "transparent"

    function toggle() {
        active = !active;
    }

    function close() {
        active = false;
    }

    onActiveChanged: if (active)
        Qt.callLater(() => editor.forceActiveFocus())

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Theme.color.surface
        opacity: 0.9

        // Slide-in-from-right feel on each reveal (see file header — the
        // window itself maps/unmaps instantly; this animates the content
        // within it so it still reads as a slide, not a hard cut).
        property real revealX: root.active ? 0 : width
        x: revealX
        Behavior on revealX {
            NumberAnimation {
                duration: Theme.animationNormal
                easing.type: Theme.easing
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: Theme.color.outline
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Text {
                text: "Notes"
                color: Theme.color.surfaceVariantText
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small
            }

            TextArea {
                id: editor
                width: parent.width
                height: parent.height - 28
                color: Theme.color.surfaceText
                font.family: Theme.font.mono
                font.pixelSize: Theme.font.normal
                wrapMode: TextArea.Wrap
                selectByMouse: true
                background: null

                Keys.onEscapePressed: root.close()
            }
        }
    }
}
