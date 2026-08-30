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

    FontLoader { id: louFont; source: "../font/last-of-us/Outfit-Black.ttf" }

    readonly property color textPrimary: "#fffdf5"
    readonly property color textSecondary: "#a89e8d"
    readonly property color accent: "#f7c594"

    Rectangle { anchors.fill: parent; color: "#0a0a09" }
    MediaPlayer {
        id: player
        source: "../themes/assets/last-of-us-bg-dark.mp4"
        videoOutput: bgVideo
        loops: MediaPlayer.Infinite
        Component.onCompleted: play()
    }
    VideoOutput { id: bgVideo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
    Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.0; color: "#00000000" } GradientStop { position: 1.0; color: "#66000000" } } }

    Repeater {
        model: 10
        delegate: Rectangle {
            property real sx: 180 + index * 38 + (index % 3) * 14
            width: 2 + (index % 3); height: width; radius: width / 2
            color: "#fff0d4"; opacity: 0
            x: sx; y: root.height - 20
            SequentialAnimation on y {
                loops: Animation.Infinite
                PauseAnimation { duration: index * 900 }
                NumberAnimation { to: root.height - 220; duration: 14000 + (index % 5) * 3000; easing.type: Easing.InOutSine }
                PropertyAction { target: parent; property: "y"; value: root.height - 20 }
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: index * 900 }
                NumberAnimation { to: 0.4; duration: 5000 }
                NumberAnimation { to: 0; duration: 10000 }
            }
        }
    }

    Column {
        anchors.left: parent.left; anchors.leftMargin: 160; anchors.top: parent.top; anchors.topMargin: 130; spacing: 4
        Text { id: clockText; color: root.textPrimary; font.family: louFont.name; font.pixelSize: 88; font.weight: Font.DemiBold; opacity: 0.95 }
        Text { id: dateText; color: root.textSecondary; font.family: louFont.name; font.pixelSize: 13; font.letterSpacing: 7 }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            clockText.text = Qt.formatTime(d, "hh:mm")
            dateText.text = Qt.formatDate(d, "dddd / MMMM d").toUpperCase()
        }
    }

    Column {
        anchors.left: parent.left; anchors.leftMargin: 160; anchors.bottom: parent.bottom; anchors.bottomMargin: 200
        width: 380; spacing: 0
        transform: Translate { id: shakeT; x: 0 }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45 }
        }

        Text { text: "CURRENT OPERATIVE"; color: root.textSecondary; opacity: 0.6; font.family: louFont.name; font.pixelSize: 10; font.letterSpacing: 2 }
        Text { text: root.userName.toUpperCase(); color: root.textPrimary; font.family: louFont.name; font.pixelSize: 32; font.weight: Font.Bold; font.letterSpacing: 1 }
        Item { width: 1; height: 26 }

        Rectangle {
            width: parent.width; height: 46; radius: 4
            color: "#ffffff08"
            border.color: root.authError ? "#f06060" : (root.passwordActive ? "#f7c59466" : "#ffffff0d")
            border.width: 1
            opacity: root.passwordActive ? 1.0 : 0.5
            TextInput {
                id: pwInput
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 60
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "·"
                color: root.textPrimary; font.family: louFont.name; font.pixelSize: 18; font.letterSpacing: 4
                enabled: !root.locked
                Keys.onReturnPressed: if (text.length > 0) root.loginRequested(text)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "ENTER ACCESS KEY"; color: root.textSecondary; opacity: pwInput.text.length === 0 ? 0.35 : 0; font.family: louFont.name; font.pixelSize: 12; font.letterSpacing: 4 }
                MouseArea { anchors.fill: parent; enabled: !root.locked; cursorShape: Qt.IBeamCursor; onClicked: { root.requestPasswordActivate(); pwInput.forceActiveFocus() } }
            }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "GO"; color: root.accent; font.family: louFont.name; font.pixelSize: 11; font.letterSpacing: 3; font.weight: Font.Bold }
        }
        Item { width: 1; height: 10 }
        Text { text: root.authError ? "ACCESS DENIED" : ""; color: "#f06060"; font.family: louFont.name; font.pixelSize: 12; font.letterSpacing: 2 }
    }

    Row {
        anchors.left: parent.left; anchors.leftMargin: 160; anchors.bottom: parent.bottom; anchors.bottomMargin: 100
        spacing: 60
        Text { text: "SHUTDOWN"; color: root.textSecondary; font.family: louFont.name; font.pixelSize: 15; font.letterSpacing: 2
            MouseArea { anchors.fill: parent; onClicked: if (typeof sddm !== "undefined") sddm.powerOff() } }
        Text { text: "REBOOT"; color: root.textSecondary; font.family: louFont.name; font.pixelSize: 15; font.letterSpacing: 2
            MouseArea { anchors.fill: parent; onClicked: if (typeof sddm !== "undefined") sddm.reboot() } }
    }
}
