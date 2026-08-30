import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Theme
import qs.Services
import qs.SnakeGame

// docs/01-lockscreen.md MVP. WlSessionLock is the real ext-session-lock-v1
// grab (same protocol hyprlock/swaylock use) — confirmed via Quickshell's
// own qmltypes + cross-checked against DankMaterialShell's production
// Modules/Lock/Lock.qml, not guessed. PAM is real too (Services/Pam.qml).
//
// Deliberately NOT wired to the real compositor's Mod+Alt+L this session —
// tested only inside the isolated Docker nested-niri environment. See
// docs/01-lockscreen.md's own setup checklist: this is step 4 of 7, PAM
// verified in a nested session before it ever gets near a real lock key.
Item {
    id: root
    property bool locked: true

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        onLockedChanged: {
            if (!locked)
                root.locked = false;
        }

        WlSessionLockSurface {
            id: surface
            color: Theme.color.background

            Pam {
                id: pam
                username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
                onSucceeded: {
                    passwordField.text = "";
                    unlockFlash.start();
                    unlockTimer.start();
                }
                onFailed: reason => {
                    passwordField.text = "";
                    shakeAnim.start();
                    errorText.text = reason;
                    errorTimer.restart();
                }
            }

            Timer {
                id: unlockTimer
                interval: 400
                onTriggered: sessionLock.locked = false
            }

            // Idle mode — fade to just clock+wallpaper after 15s (default),
            // any input restores it without clearing the typed password.
            property bool idle: false
            Timer {
                id: idleTimer
                interval: 15000
                running: !snake.active
                onTriggered: surface.idle = true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: {
                    surface.idle = false;
                    idleTimer.restart();
                }
                onPressed: {
                    surface.idle = false;
                    idleTimer.restart();
                }
                propagateComposedEvents: true
            }

            // Background — flat color at MVP; real wallpaper source is the
            // same path select.sh/carousel.qml write to (docs/05), wire up
            // once this lock screen is verified end-to-end.
            Rectangle {
                anchors.fill: parent
                color: Theme.color.background
            }

            Column {
                id: authColumn
                anchors.centerIn: parent
                spacing: 16
                opacity: surface.idle ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clockTimer.now, "HH:mm")
                    color: Theme.color.surfaceText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.display
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clockTimer.now, "dddd, d MMMM")
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pam.username
                    color: Theme.color.surfaceText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.large
                    topPadding: 24
                }

                Rectangle {
                    id: fieldBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 260
                    height: 44
                    radius: Theme.radius.medium
                    color: Theme.color.surfaceContainer
                    border.width: 1
                    border.color: pam.authenticating ? Theme.color.accent : Theme.color.outline

                    property real shakeOffset: 0
                    anchors.horizontalCenterOffset: shakeOffset

                    SequentialAnimation {
                        id: shakeAnim
                        loops: 1
                        NumberAnimation {
                            target: fieldBox
                            property: "shakeOffset"
                            to: -8
                            duration: 40
                        }
                        NumberAnimation {
                            target: fieldBox
                            property: "shakeOffset"
                            to: 8
                            duration: 40
                        }
                        NumberAnimation {
                            target: fieldBox
                            property: "shakeOffset"
                            to: -6
                            duration: 40
                        }
                        NumberAnimation {
                            target: fieldBox
                            property: "shakeOffset"
                            to: 0
                            duration: 40
                        }
                    }

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        anchors.margins: 10
                        color: Theme.color.surfaceText
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.normal
                        echoMode: TextInput.Password
                        focus: !snake.active
                        verticalAlignment: TextInput.AlignVCenter

                        onAccepted: if (text.length > 0 && !pam.authenticating)
                            pam.authenticate(text)

                        Keys.onPressed: event => {
                            surface.idle = false;
                            idleTimer.restart();
                            if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
                                passwordField.text = "";
                                event.accepted = true;
                            } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ControlModifier)) {
                                snake.active = true;
                                event.accepted = true;
                            }
                        }
                    }
                }

                Text {
                    id: errorText
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.color.error
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.small
                    opacity: text.length > 0 ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationFast
                        }
                    }
                }

                Timer {
                    id: errorTimer
                    interval: 3000
                    onTriggered: errorText.text = ""
                }

                Rectangle {
                    id: unlockFlash
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.color.success
                    opacity: 0
                    function start() {
                        flashAnim.start();
                    }
                    SequentialAnimation {
                        id: flashAnim
                        NumberAnimation {
                            target: unlockFlash
                            property: "opacity"
                            to: 1
                            duration: 150
                        }
                        NumberAnimation {
                            target: unlockFlash
                            property: "opacity"
                            to: 0
                            duration: 250
                        }
                    }
                }
            }

            SnakeGame {
                id: snake
                anchors.fill: parent
                onExitRequested: active = false
            }

            Item {
                id: clockTimer
                property var now: new Date()
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockTimer.now = new Date()
                }
            }
        }
    }
}
