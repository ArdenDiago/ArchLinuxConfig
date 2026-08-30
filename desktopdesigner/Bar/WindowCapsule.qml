import QtQuick
import qs.Theme

// One capsule per open window on the focused workspace (docs/02-bar.md
// Section 1). Icon-lookup from the system icon theme is a real chunk of
// work (needs .desktop-entry-to-icon-name resolution, same problem
// Spotlight's ApplicationProvider has) — deferred; shows the app_id text
// instead of an icon for now, hover-expand animates it in from a narrow
// icon-only width once icons exist.
Rectangle {
    id: root
    property string appId: ""
    property string title: ""
    property bool focused: false
    signal clicked
    signal middleClicked

    implicitWidth: label.implicitWidth + 20
    implicitHeight: 26
    radius: Theme.radius.large
    color: focused ? Theme.color.accentContainer : (hover.hovered ? Theme.color.surfaceContainerHigh : Theme.color.surfaceContainer)
    border.width: focused ? 1 : 0
    border.color: Theme.color.accent

    Behavior on color {
        ColorAnimation {
            duration: Theme.animationFast
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.appId || root.title || "?"
        color: root.focused ? Theme.color.accentText : Theme.color.surfaceText
        font.family: Theme.font.family
        font.pixelSize: Theme.font.small
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: root.middleClicked()
    }
}
