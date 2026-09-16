import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root
    width: 620
    height: 260

    readonly property string sample: "the terminal hums quietly while the lock waits in the dark"
    property string typed: ""
    property var startTime: null

    readonly property bool done: typed.length >= sample.length
    readonly property int correctCount: {
        var c = 0
        for (var i = 0; i < typed.length; i++) if (typed[i] === sample[i]) c++
        return c
    }
    readonly property real wpm: {
        if (!startTime) return 0
        var mins = Math.max((Date.now() - startTime) / 60000, 1 / 60)
        return Math.max(0, Math.round((correctCount / 5) / mins))
    }
    readonly property int accuracy: typed.length ? Math.round((correctCount / typed.length) * 100) : 100

    function reset() {
        typed = ""
        startTime = null
        input.text = ""
        input.forceActiveFocus()
    }

    Component.onCompleted: input.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: "#14120f"
        border.color: "#ffffff1a"; border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 18

            Row {
                width: parent.width
                Text { text: "Typing Test"; color: "#f2ede6"; font.pixelSize: 15; font.bold: true }
                Item { width: parent.width - 200 - statsRow.width; height: 1 }
                Row {
                    id: statsRow
                    spacing: 16
                    Text { text: root.wpm + " wpm"; color: "#f2ede6a0"; font.pixelSize: 12 }
                    Text { text: root.accuracy + "% acc"; color: "#f2ede6a0"; font.pixelSize: 12 }
                }
            }

            Flow {
                width: parent.width
                spacing: 0
                Repeater {
                    model: root.sample.length
                    delegate: Text {
                        property string ch: root.sample[index]
                        text: ch
                        font.pixelSize: 19
                        font.family: "monospace"
                        color: index < root.typed.length
                               ? (root.typed[index] === ch ? "#f2ede6" : "#ff8a8a")
                               : (index === root.typed.length ? "#f2ede6" : "#f2ede660")
                    }
                }
            }

            TextField {
                id: input
                width: parent.width
                placeholderText: "start typing…"
                font.pixelSize: 14
                color: "#f2ede6"
                background: Rectangle { radius: 10; color: "#ffffff0d"; border.color: "#ffffff1f"; border.width: 1 }
                onTextChanged: {
                    if (text.length > root.sample.length) text = text.substring(0, root.sample.length)
                    if (root.startTime === null && text.length > 0) root.startTime = Date.now()
                    root.typed = text
                }
            }

            Row {
                visible: root.done
                spacing: 14
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Done — " + root.wpm + " wpm, " + root.accuracy + "% accuracy"
                    color: "#b6d99a"; font.pixelSize: 13
                }
                Rectangle {
                    width: restartLabel.width + 28; height: 32; radius: 10
                    color: restartMa.containsMouse ? "#ffffff1a" : "#ffffff0a"
                    border.color: "#ffffff20"; border.width: 1
                    Text { id: restartLabel; anchors.centerIn: parent; text: "Restart"; color: "#f2ede6"; font.pixelSize: 13 }
                    MouseArea { id: restartMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.reset() }
                }
            }

            Text { text: "Esc to exit"; color: "#f2ede660"; font.pixelSize: 11 }
        }
    }
}
