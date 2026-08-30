import QtQuick

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

    FontLoader { id: fieldFont; source: "../font/field/Orbitron-VariableFont_wght.ttf" }

    readonly property color cAmber: "#e8a040"
    readonly property color cWhite: "#f0ede8"

    Rectangle { anchors.fill: parent; color: "#0a1416" }
    Image { anchors.fill: parent; source: "../themes/assets/field-bg-dark.png"; fillMode: Image.PreserveAspectCrop }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0.0; color: "#00000000" } GradientStop { position: 1.0; color: "#80000000" } }
    }

    Column {
        anchors.left: parent.left; anchors.top: parent.top; anchors.leftMargin: 70; anchors.topMargin: 60; spacing: 6
        Text { id: clockText; color: root.cWhite; font.family: fieldFont.name; font.pixelSize: 78; font.weight: Font.Light }
        Text { id: dateText; color: "#d8eef8"; opacity: 0.7; font.family: fieldFont.name; font.pixelSize: 12; font.letterSpacing: 3 }
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
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: 70; anchors.bottomMargin: 190
        width: 220
        transform: Translate { id: shakeT; x: 0 }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45 }
        }

        Text { anchors.right: parent.right; text: root.userName.toLowerCase(); color: root.cWhite; font.family: fieldFont.name; font.pixelSize: 21; font.weight: Font.Light; font.letterSpacing: 3 }
        Item { width: 1; height: 22 }
        Item {
            width: parent.width; height: 40; opacity: root.passwordActive ? 1.0 : 0.5
            TextInput {
                id: pwInput
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignRight; verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "·"
                color: root.cWhite; font.family: fieldFont.name; font.pixelSize: 18; font.letterSpacing: 6
                enabled: !root.locked
                Keys.onReturnPressed: if (text.length > 0) root.loginRequested(text)
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "password"; color: root.cWhite; opacity: pwInput.text.length === 0 ? 0.55 : 0; font.family: fieldFont.name; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; enabled: !root.locked; cursorShape: Qt.IBeamCursor; onClicked: { root.requestPasswordActivate(); pwInput.forceActiveFocus() } }
            }
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: root.authError ? "#e06060" : (root.passwordActive ? root.cAmber : "#35f0ede8") }
        }
        Item { width: 1; height: 18 }
        Row {
            anchors.right: parent.right; spacing: 20
            Text { text: "session"; color: root.cWhite; opacity: 0.65; font.family: fieldFont.name; font.pixelSize: 11; font.letterSpacing: 1 }
            Text { text: "reboot"; color: root.cWhite; opacity: rebootMa.containsMouse ? 1.0 : 0.65; font.family: fieldFont.name; font.pixelSize: 11; font.letterSpacing: 1
                MouseArea { id: rebootMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (typeof sddm !== "undefined") sddm.reboot() } }
            Text { text: "power"; color: root.cWhite; opacity: powerMa.containsMouse ? 1.0 : 0.65; font.family: fieldFont.name; font.pixelSize: 11; font.letterSpacing: 1
                MouseArea { id: powerMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (typeof sddm !== "undefined") sddm.powerOff() } }
        }
        Text { anchors.right: parent.right; text: root.authError ? "wrong password" : ""; color: "#e06060"; font.family: fieldFont.name; font.pixelSize: 11; font.letterSpacing: 1 }
    }
}
