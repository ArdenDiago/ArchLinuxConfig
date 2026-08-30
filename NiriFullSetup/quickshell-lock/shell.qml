import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    property string passwordBuffer: ""
    property bool authError: false

    Timer { id: errorResetTimer; interval: 500; onTriggered: root.authError = false }
    Timer { id: quitTimer; interval: 250; onTriggered: Qt.quit() }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER") || ""

        onResponseRequiredChanged: {
            if (responseRequired) respond(root.passwordBuffer)
        }
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                sessionLock.locked = false
                quitTimer.start()
            } else {
                root.authError = true
                errorResetTimer.restart()
            }
        }
    }

    function attemptLogin(password) {
        root.passwordBuffer = password
        pam.start()
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            LockRoot {
                anchors.fill: parent
                userName: Quickshell.env("USER") || "user"
                authError: root.authError
                onLoginRequested: (password) => root.attemptLogin(password)
            }
        }
    }
}
