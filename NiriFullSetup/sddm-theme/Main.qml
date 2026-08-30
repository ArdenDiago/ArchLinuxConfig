import QtQuick
import QtQuick.Window
import Qt.labs.settings

Item {
    id: root
    width: Screen.width
    height: Screen.height
    focus: true

    readonly property var skinSources: [
        "themes/SwordSkin.qml",
        "themes/ForestSkin.qml",
        "themes/FieldSkin.qml",
        "themes/LastOfUsSkin.qml",
        "themes/ClockworkSkin.qml"
    ]

    property int layout: 0
    property bool menuOpen: false
    property string overlay: ""
    property bool passwordActive: false
    property bool authError: false
    readonly property bool locked: menuOpen || overlay !== ""

    readonly property string userName: (typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "arden"
    readonly property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0

    Settings {
        id: settings
        category: "qylockDark"
        property int savedLayout: 0
    }
    Component.onCompleted: {
        root.layout = settings.savedLayout
        root.forceActiveFocus()
    }
    onLayoutChanged: settings.savedLayout = layout

    Timer { id: failResetTimer; interval: 600; onTriggered: root.authError = false }

    function attemptLogin(password) {
        if (typeof sddm !== "undefined") {
            sddm.login(root.userName, password, root.sessionIndex)
        } else {
            root.authError = true
            failResetTimer.restart()
        }
    }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.authError = true
            failResetTimer.restart()
        }
    }

    function toggleMenu() {
        if (!root.menuOpen) {
            root.passwordActive = false
            if (skinLoader.item) skinLoader.item.blurPassword()
        }
        root.menuOpen = !root.menuOpen
    }
    function selectLayout(i) { root.layout = i; root.menuOpen = false }
    function openSnake() { root.menuOpen = false; root.overlay = "snake" }
    function openTyping() { root.menuOpen = false; root.overlay = "typing" }
    function closeOverlay() { root.overlay = "" }
    function jumpToPassword() {
        root.menuOpen = false
        root.overlay = ""
        root.passwordActive = true
        if (skinLoader.item) skinLoader.item.focusPassword()
    }

    Loader {
        id: skinLoader
        anchors.fill: parent
        source: root.skinSources[root.layout]
        onLoaded: {
            item.userName = root.userName
            item.passwordActive = Qt.binding(function () { return root.passwordActive })
            item.authError = Qt.binding(function () { return root.authError })
            item.locked = Qt.binding(function () { return root.locked })
        }
        Connections {
            target: skinLoader.item
            function onRequestPasswordActivate() { root.passwordActive = true }
            function onLoginRequested(password) { root.attemptLogin(password) }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.menuOpen
        sourceComponent: CommandMenu {
            currentLayout: root.layout
            onLayoutSelected: (index) => root.selectLayout(index)
            onSnakeRequested: root.openSnake()
            onTypingRequested: root.openTyping()
            onCloseRequested: root.toggleMenu()
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.overlay !== ""
        color: "#0000008c"
        Loader {
            id: overlayLoader
            anchors.centerIn: parent
            active: root.overlay !== ""
            source: root.overlay === "snake" ? "SnakeGame.qml" : (root.overlay === "typing" ? "TypingTest.qml" : "")
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
            if (root.overlay !== "") { root.closeOverlay(); return }
            if (root.menuOpen) { root.toggleMenu(); return }
            if (root.passwordActive) {
                root.passwordActive = false
                if (skinLoader.item) skinLoader.item.blurPassword()
            }
            return
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
            event.accepted = true
            root.jumpToPassword()
            return
        }
        if (root.overlay === "snake") {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && overlayLoader.item && overlayLoader.item.gameOver) {
                event.accepted = true
                overlayLoader.item.restart()
                return
            }
            if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].indexOf(event.key) >= 0) {
                event.accepted = true
                if (overlayLoader.item) overlayLoader.item.handleDirection(event.key)
                return
            }
            return
        }
        if (root.overlay !== "") return
        if (event.key === Qt.Key_Slash && !root.passwordActive) {
            event.accepted = true
            root.toggleMenu()
            return
        }
    }
}
