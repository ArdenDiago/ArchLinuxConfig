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

    FontLoader { id: cwFont; source: "../font/clockwork/Outfit-Black.ttf" }

    Rectangle { anchors.fill: parent; color: "#000000" }

    Row {
        anchors.left: parent.left; anchors.leftMargin: 60; anchors.verticalCenter: parent.verticalCenter
        spacing: 40

        Canvas {
            width: 260; height: 260
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2
                ctx.strokeStyle = "#1a1a1a"; ctx.lineWidth = 1.5
                ctx.setLineDash([1.5, 8.5])
                ctx.beginPath(); ctx.arc(cx, cy, 92, 0, Math.PI * 2); ctx.stroke()
                ctx.strokeStyle = "#444"; ctx.lineWidth = 2
                ctx.setLineDash([2, 43])
                ctx.beginPath(); ctx.arc(cx, cy, 92, 0, Math.PI * 2); ctx.stroke()
                ctx.strokeStyle = "#161616"; ctx.lineWidth = 1
                ctx.setLineDash([])
                ctx.beginPath(); ctx.arc(cx, cy, 68, 0, Math.PI * 2); ctx.stroke()
            }
        }

        Text { id: hourText; anchors.verticalCenter: parent.verticalCenter; color: "white"; font.family: cwFont.name; font.pixelSize: 128; font.weight: Font.Black }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 300; height: 84; radius: 42; color: "#080808"; border.color: "#333"; border.width: 1
            Row {
                anchors.fill: parent
                Item { width: parent.width / 2; height: parent.height
                    Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 18; anchors.bottomMargin: 18; width: 1; color: "#222" }
                    Text { id: minText; anchors.centerIn: parent; color: "white"; font.family: cwFont.name; font.pixelSize: 26; font.weight: Font.Bold }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 24; leftPadding: 24; spacing: 3
                    Text { id: fullDateText; color: "#555"; font.family: cwFont.name; font.pixelSize: 11; font.letterSpacing: 3 }
                    Text { id: weekdayText; color: "white"; font.family: cwFont.name; font.pixelSize: 15; font.letterSpacing: 6; font.weight: Font.Bold }
                }
            }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            var h12 = d.getHours() % 12; if (h12 === 0) h12 = 12
            hourText.text = String(h12).padStart(2, "0")
            minText.text = String(d.getMinutes()).padStart(2, "0")
            fullDateText.text = Qt.formatDate(d, "dd MMM yyyy").toUpperCase()
            weekdayText.text = Qt.formatDate(d, "dddd").toUpperCase()
        }
    }

    Row {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 50; spacing: 25
        Text { text: "REBOOT"; color: "#666"; font.family: cwFont.name; font.pixelSize: 10; font.letterSpacing: 3
            MouseArea { anchors.fill: parent; onClicked: if (typeof sddm !== "undefined") sddm.reboot() } }
        Rectangle { width: 1; height: 10; color: "#333" }
        Text { text: "SHUTDOWN"; color: "#666"; font.family: cwFont.name; font.pixelSize: 10; font.letterSpacing: 3
            MouseArea { anchors.fill: parent; onClicked: if (typeof sddm !== "undefined") sddm.powerOff() } }
    }

    Column {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 80
        width: 350
        transform: Translate { id: shakeT; x: 0 }
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 45 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 45 }
        }

        Text { anchors.right: parent.right; text: root.userName.toUpperCase(); color: "#666"; font.family: cwFont.name; font.pixelSize: 18; font.weight: Font.Bold; font.letterSpacing: 8 }
        Item { width: 1; height: 8 }
        Item {
            width: parent.width; height: 30; opacity: root.passwordActive ? 1.0 : 0.5
            TextInput {
                id: pwInput
                anchors.fill: parent
                horizontalAlignment: TextInput.AlignRight; verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password; passwordCharacter: "•"
                color: "#aaa"; font.family: cwFont.name; font.pixelSize: 14; font.letterSpacing: 8
                enabled: !root.locked
                Keys.onReturnPressed: if (text.length > 0) root.loginRequested(text)
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "WAITING FOR KEY"; color: "#333"; opacity: pwInput.text.length === 0 ? 0.7 : 0; font.family: cwFont.name; font.pixelSize: 10; font.letterSpacing: 4 }
                MouseArea { anchors.fill: parent; enabled: !root.locked; cursorShape: Qt.IBeamCursor; onClicked: { root.requestPasswordActivate(); pwInput.forceActiveFocus() } }
            }
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: root.authError ? "#ff4444" : (root.passwordActive ? "#ffffff" : "#333333") }
        }
        Item { width: 1; height: 10 }
        Text { anchors.right: parent.right; text: "ENTER KEY"; color: "#666"; font.family: cwFont.name; font.pixelSize: 10; font.letterSpacing: 2 }
        Text { anchors.right: parent.right; text: root.authError ? "ACCESS DENIED" : ""; color: "#ff4444"; font.family: cwFont.name; font.pixelSize: 10; font.letterSpacing: 2 }
    }
}
