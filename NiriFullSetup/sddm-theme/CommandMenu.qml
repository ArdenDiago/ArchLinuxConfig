import QtQuick

Item {
    id: root
    anchors.fill: parent

    property int currentLayout: 0
    readonly property var layouts: [
        { label: "Sword", sub: "thin · navy" },
        { label: "Forest", sub: "glass · green" },
        { label: "Field", sub: "flat · amber" },
        { label: "The Last of Us", sub: "tactical · peach" },
        { label: "Clockwork", sub: "orbital · mono" }
    ]

    signal layoutSelected(int index)
    signal snakeRequested()
    signal typingRequested()
    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: "#0000008c"

        MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            height: contentCol.implicitHeight + 44
            radius: 18
            color: "#14120f"
            border.color: "#ffffff1a"; border.width: 1

            MouseArea { anchors.fill: parent } // swallow clicks so they don't hit the backdrop

            Column {
                id: contentCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 22
                spacing: 8

                Text { text: "LAYOUT"; color: "#f2ede680"; font.pixelSize: 11; font.letterSpacing: 3 }

                Repeater {
                    model: root.layouts
                    delegate: Rectangle {
                        width: contentCol.width; height: 42; radius: 10
                        property bool active: index === root.currentLayout
                        color: tileMa.containsMouse ? "#ffffff1a" : (active ? "#e7dcc81f" : "#ffffff0a")
                        border.color: active ? "#e7dcc8" : "#ffffff14"; border.width: 1
                        Row {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14; anchors.rightMargin: 14
                            spacing: 10
                            Text { text: modelData.label; color: "#f2ede6"; font.pixelSize: 14; font.bold: true }
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.sub; color: "#f2ede680"; font.pixelSize: 12
                        }
                        MouseArea { id: tileMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.layoutSelected(index) }
                    }
                }

                Item { width: 1; height: 6 }
                Text { text: "GAMES"; color: "#f2ede680"; font.pixelSize: 11; font.letterSpacing: 3 }
                Rectangle {
                    width: contentCol.width; height: 42; radius: 10
                    color: snakeMa.containsMouse ? "#ffffff1a" : "#ffffff0a"
                    border.color: "#ffffff14"; border.width: 1
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "Snake"; color: "#f2ede6"; font.pixelSize: 14; font.bold: true }
                    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "play"; color: "#f2ede680"; font.pixelSize: 12 }
                    MouseArea { id: snakeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.snakeRequested() }
                }

                Item { width: 1; height: 6 }
                Text { text: "UTILITIES"; color: "#f2ede680"; font.pixelSize: 11; font.letterSpacing: 3 }
                Rectangle {
                    width: contentCol.width; height: 42; radius: 10
                    color: typingMa.containsMouse ? "#ffffff1a" : "#ffffff0a"
                    border.color: "#ffffff14"; border.width: 1
                    Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "Typing Test"; color: "#f2ede6"; font.pixelSize: 14; font.bold: true }
                    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "wpm & accuracy"; color: "#f2ede680"; font.pixelSize: 12 }
                    MouseArea { id: typingMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.typingRequested() }
                }

                Item { width: 1; height: 8 }
                Rectangle { width: contentCol.width; height: 1; color: "#ffffff14" }
                Item { width: 1; height: 4 }
                Row {
                    spacing: 18
                    Text { text: "/ close"; color: "#f2ede660"; font.pixelSize: 11 }
                    Text { text: "Esc back"; color: "#f2ede660"; font.pixelSize: 11 }
                    Text { text: "Ctrl+P password"; color: "#f2ede660"; font.pixelSize: 11 }
                }
            }
        }
    }
}
