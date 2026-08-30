import QtQuick
import QtMultimedia

Item {
    id: root
    anchors.fill: parent

    property string userName: "arden"
    property bool passwordActive: false
    property bool authError: false
    property bool locked: false

    signal requestPasswordActivate()
    signal loginRequested(string password)

    function focusPassword() { pwInput.forceActiveFocus() }
    function blurPassword() { pwInput.focus = false }

    onAuthErrorChanged: if (authError) { pwInput.text = ""; shakeAnim.start() }

    FontLoader { id: swordFont; source: "../font/sword/TheLastShuriken.ttf" }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#080c14" }
            GradientStop { position: 0.5; color: "#0e1420" }
            GradientStop { position: 1.0; color: "#050810" }
        }
    }

    MediaPlayer {
        id: player
        source: "../themes/assets/sword-bg-dark.mp4"
        videoOutput: bgVideo
        loops: MediaPlayer.Infinite
        Component.onCompleted: play()
    }
    VideoOutput { id: bgVideo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop; opacity: 0.8 }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#a0000000" }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        height: 220; gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#dd000000" }
        }
    }

    Column {
        anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: 70; anchors.topMargin: 60; spacing: 8
        Text { id: clockText; color: "white"; font.family: swordFont.name; font.pixelSize: 76; font.weight: Font.Thin }
        Row {
            spacing: 10
            Rectangle { width: 22; height: 1; color: "#6090b8"; anchors.verticalCenter: parent.verticalCenter }
            Text { id: dateText; color: "#6090b8"; font.family: swordFont.name; font.pixelSize: 13; font.letterSpacing: 3 }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            clockText.text = Qt.formatTime(d, "hh:mm")
            dateText.text = Qt.formatDate(d, "dddd · MMMM d").toUpperCase()
        }
    }

    Column {
        id: loginPanel
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: 40; anchors.bottomMargin: 110
        width: 280

        Text { anchors.right: parent.right; text: root.userName; color: "white"; font.family: swordFont.name; font.pixelSize: 21; font.letterSpacing: 1 }
        Item { width: 1; height: 22 }

        Item {
            width: parent.width; height: 32
            opacity: root.passwordActive ? 1.0 : 0.5
            transform: Translate { id: shakeT; x: 0 }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 45 }
                NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 45 }
                NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 45 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45 }
            }
            TextInput {
                id: pwInput
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignRight; verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "•"
                color: "#fff"; font.family: swordFont.name; font.pixelSize: 16; font.letterSpacing: 2
                enabled: !root.locked
                Keys.onReturnPressed: if (text.length > 0) root.loginRequested(text)
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "Enter password"; color: "#ffffff"; opacity: pwInput.text.length === 0 ? 0.3 : 0
                    font.family: swordFont.name; font.pixelSize: 14
                }
                MouseArea { anchors.fill: parent; enabled: !root.locked; cursorShape: Qt.IBeamCursor; onClicked: { root.requestPasswordActivate(); pwInput.forceActiveFocus() } }
            }
        }
        Rectangle { width: parent.width; height: 1; color: root.authError ? "#d06060" : (root.passwordActive ? "#80b0d8" : "#28607888") }
        Item { width: 1; height: 10 }
        Text { anchors.right: parent.right; height: 15; text: root.authError ? "ACCESS DENIED" : ""; color: "#d06060"; font.family: swordFont.name; font.pixelSize: 11; font.letterSpacing: 1 }
    }

    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 40; anchors.rightMargin: 40; anchors.bottomMargin: 30; height: 1; color: "#15a0c8e0" }
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 40; spacing: 28
        Text { text: "Restart"; color: "white"; opacity: restartMa.containsMouse ? 0.9 : 0.4; font.family: swordFont.name; font.pixelSize: 12; font.letterSpacing: 1
            MouseArea { id: restartMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (typeof sddm !== "undefined") sddm.reboot() } }
        Text { text: "Shut Down"; color: "white"; opacity: shutMa.containsMouse ? 0.9 : 0.4; font.family: swordFont.name; font.pixelSize: 12; font.letterSpacing: 1
            MouseArea { id: shutMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (typeof sddm !== "undefined") sddm.powerOff() } }
    }
}
