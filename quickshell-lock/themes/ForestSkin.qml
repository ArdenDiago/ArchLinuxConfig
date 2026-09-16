import QtQuick
import QtMultimedia
import Qt5Compat.GraphicalEffects

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

    FontLoader { id: forestFont; source: "../font/forest/Figtree-Bold.ttf" }

    readonly property color accent: "#d3eaad"

    Rectangle { anchors.fill: parent; color: "#05100a" }

    MediaPlayer {
        id: player
        source: "../themes/assets/forest-bg-dark.mp4"
        videoOutput: bgVideo
        loops: MediaPlayer.Infinite
        Component.onCompleted: play()
    }
    VideoOutput { id: bgVideo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0.0; color: "#00000000" } GradientStop { position: 1.0; color: "#70000000" } }
    }

    // Clock pebble
    Rectangle {
        id: clockPebble
        x: 100; y: 100; width: 300; height: 130; radius: 25
        color: "#ffffff0d"; border.color: "#ffffff1f"; border.width: 1
        layer.enabled: true
        layer.effect: DropShadow { transparentBorder: true; color: "#66000000"; radius: 24; verticalOffset: 8 }
        Column {
            anchors.centerIn: parent; spacing: 5
            Text { id: clockText; anchors.horizontalCenter: parent.horizontalCenter; color: "white"; font.family: forestFont.name; font.pixelSize: 58; opacity: 0.95 }
            Text { id: dateText; anchors.horizontalCenter: parent.horizontalCenter; color: root.accent; font.family: forestFont.name; font.pixelSize: 13; font.letterSpacing: 3; opacity: 0.8 }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            clockText.text = Qt.formatTime(d, "hh:mm")
            dateText.text = Qt.formatDate(d, "dddd, MMMM d").toUpperCase()
        }
    }

    // Login panel
    Column {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 100
        width: 340; spacing: 14

        Rectangle {
            width: parent.width; height: 66; radius: 20
            color: "#ffffff0d"; border.color: "#ffffff1f"; border.width: 1
            layer.enabled: true
            layer.effect: DropShadow { transparentBorder: true; color: "#66000000"; radius: 24; verticalOffset: 8 }
            Row {
                anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                Rectangle { width: 40; height: 40; radius: 20; color: root.accent
                    Text { anchors.centerIn: parent; text: root.userName.length ? root.userName[0].toUpperCase() : "A"; font.pixelSize: 16; font.weight: Font.Black; color: "#0d1b0d" } }
                Column {
                    Text { text: "WELCOME BACK"; font.family: forestFont.name; font.pixelSize: 10; color: "white"; opacity: 0.5; font.letterSpacing: 2 }
                    Text { text: root.userName.toUpperCase(); font.family: forestFont.name; font.pixelSize: 18; color: "white"; font.letterSpacing: 0.5 }
                }
            }
        }

        Rectangle {
            id: pwCard
            width: parent.width; height: 54; radius: 20
            color: "#ffffff0d"
            border.color: root.authError ? "#ff6666" : (root.passwordActive ? root.accent : "#ffffff1f")
            border.width: root.passwordActive ? 1.5 : 1
            opacity: root.passwordActive ? 1.0 : 0.5
            layer.enabled: true
            layer.effect: DropShadow { transparentBorder: true; color: "#66000000"; radius: 24; verticalOffset: 8 }
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
                anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 60
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "●"
                color: root.accent; font.family: forestFont.name; font.pixelSize: 16; font.letterSpacing: 2
                enabled: !root.locked
                Keys.onReturnPressed: if (text.length > 0) root.loginRequested(text)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Enter Passcode"; color: "white"; opacity: pwInput.text.length === 0 ? 0.3 : 0; font.family: forestFont.name; font.pixelSize: 14 }
                MouseArea { anchors.fill: parent; enabled: !root.locked; cursorShape: Qt.IBeamCursor; onClicked: { root.requestPasswordActivate(); pwInput.forceActiveFocus() } }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38; radius: 19; color: "#ffffff14"
                Text { anchors.centerIn: parent; text: "→"; color: "white"; font.pixelSize: 18 }
            }
        }
        Text { anchors.right: parent.right; text: root.authError ? "ACCESS DENIED" : ""; color: "#ff8888"; font.family: forestFont.name; font.pixelSize: 11; font.letterSpacing: 2 }

        Row {
            width: parent.width; spacing: 16
            Rectangle { width: (parent.width - 16) / 2; height: 46; radius: 16; color: "#ffffff0a"; border.color: "#ffffff14"; border.width: 1
                Text { anchors.centerIn: parent; text: "REBOOT"; color: "white"; opacity: 0.75; font.family: forestFont.name; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; onClicked: if (typeof sddm !== "undefined") sddm.reboot() } }
            Rectangle { width: (parent.width - 16) / 2; height: 46; radius: 16; color: "#ffffff0a"; border.color: "#ffffff14"; border.width: 1
                Text { anchors.centerIn: parent; text: "POWER"; color: "white"; opacity: 0.75; font.family: forestFont.name; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; onClicked: if (typeof sddm !== "undefined") sddm.powerOff() } }
        }
    }
}
