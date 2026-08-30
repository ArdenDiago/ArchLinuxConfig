import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Services

// Top bar — docs/02-bar.md's 5 sections. MVP scope: WM capsules (real Niri
// IPC), centered clock, CPU/RAM sparklines (real), notification bell
// (static — see docs/02-bar.md's mako-handoff question, unresolved so this
// stays a stub), battery (real, auto-hidden), system icons (static
// placeholders — wifi/bt/volume backends are Network/Bluetooth Center's
// job, docs/07, not built yet).
PanelWindow {
    id: bar

    signal networkIconClicked

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 36
    color: Theme.color.background

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // Section 1 — WM window capsules
        RowLayout {
            id: wmSection
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Niri.focusedWorkspaceWindows
                delegate: WindowCapsule {
                    required property var modelData
                    appId: modelData.app_id || ""
                    title: modelData.title || ""
                    focused: !!modelData.is_focused
                    onClicked: Niri.focusWindow(modelData.id)
                    onMiddleClicked: Niri.closeWindow(modelData.id)
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Section 2 — centered clock
        Text {
            id: clock
            Layout.alignment: Qt.AlignVCenter
            color: Theme.color.surfaceText
            font.family: Theme.font.family
            font.pixelSize: Theme.font.normal

            property var now: new Date()
            text: Qt.formatDateTime(now, "ddd d MMM   HH:mm")

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.now = new Date()
            }
        }

        // Sections 3-6 — graphs, notifications, battery, system icons
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 14

            RowLayout {
                spacing: 8
                Text {
                    text: "CPU"
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.small
                }
                Sparkline {
                    implicitWidth: 48
                    implicitHeight: 16
                    history: Sensors.cpuHistory
                    lineColor: Theme.color.cpu
                }
                Text {
                    text: Math.round(Sensors.cpuPercent * 100) + "%"
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.small
                }
            }

            RowLayout {
                spacing: 8
                Text {
                    text: "RAM"
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.small
                }
                Sparkline {
                    implicitWidth: 48
                    implicitHeight: 16
                    history: Sensors.ramHistory
                    lineColor: Theme.color.ram
                }
                Text {
                    text: Math.round(Sensors.ramPercent * 100) + "%"
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.small
                }
            }

            // Notifications — static stub, see docs/02-bar.md
            Text {
                text: "🔔"
                font.pixelSize: Theme.font.normal
            }

            // Battery — hidden entirely when absent (desktop system)
            Text {
                visible: Sensors.hasBattery
                text: (Sensors.batteryCharging ? "⚡" : "🔋") + " " + Math.round(Sensors.batteryPercent * 100) + "%"
                color: Theme.color.surfaceText
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small
            }

            // System controls — status icons only, static for now
            RowLayout {
                spacing: 8
                Text {
                    text: "📶"
                    font.pixelSize: Theme.font.normal
                    TapHandler {
                        onTapped: bar.networkIconClicked()
                    }
                }
                Text {
                    text: "🔊"
                    font.pixelSize: Theme.font.normal
                }
            }
        }
    }
}
