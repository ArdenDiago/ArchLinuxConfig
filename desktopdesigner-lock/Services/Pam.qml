pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pam

// Real PAM auth via Quickshell's built-in PamContext — no custom C helper
// needed (docs/01-lockscreen.md originally scoped one before this API was
// confirmed against Quickshell.Services.Pam's actual qmltypes + DankMaterial-
// Shell's Modules/Lock/Pam.qml, which uses this exact same event flow).
//
// config: "login" — the plain system login PAM service, works out of the
// box on any Arch install with no dedicated /etc/pam.d/desktopdesigner
// file to maintain. DMS supports swapping to a custom service; not needed
// here at MVP scope.
Item {
    id: root

    property string username: ""
    property bool authenticating: false
    property bool lastResultSuccess: false
    property string lastErrorMessage: ""

    signal succeeded
    signal failed(string reason)

    // Never logged, never exposed outside this respond() call, cleared the
    // instant PAM either succeeds or fails — see clearBuffer().
    property string _pendingPassword: ""

    function authenticate(password) {
        if (root.authenticating)
            return;
        root._pendingPassword = password;
        root.authenticating = true;
        root.lastErrorMessage = "";
        pam.user = root.username;
        pam.start();
    }

    function abort() {
        pam.abort();
        clearBuffer();
        root.authenticating = false;
    }

    function clearBuffer() {
        root._pendingPassword = "";
    }

    PamContext {
        id: pam
        config: "login"

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root._pendingPassword);
        }

        onCompleted: result => {
            root.authenticating = false;
            const success = result === PamResult.Success;
            root.lastResultSuccess = success;
            root.clearBuffer();
            if (success) {
                root.succeeded();
            } else {
                const reason = result === PamResult.MaxTries ? "Too many attempts" : result === PamResult.Error ? "Authentication error" : "Incorrect password";
                root.lastErrorMessage = reason;
                root.failed(reason);
            }
        }
    }
}
