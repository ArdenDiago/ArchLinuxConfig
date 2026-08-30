import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme

// docs/07-network-bluetooth.md MVP. Shells out to nmcli/bluetoothctl for
// both listing and mutating actions — the doc explicitly allows this
// ("shelling out for one-shot mutating actions is acceptable if it
// measurably shortens the implementation"); native NetworkManager/BlueZ
// DBus (Services/NetworkManager.qml, Services/BlueZ.qml, shared with the
// Bar's status icons per docs/00-overview.md) is the documented upgrade
// path once this needs live signal-driven updates instead of poll-on-open.
//
// ponytail: no live re-scan/polling loop — (re)scans once when opened.
// Add a refresh timer only if leaving it open for a while while networks
// change turns out to matter in practice.
PanelWindow {
    id: root
    property bool active: false
    visible: active
    focusable: active

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    property string tab: "wifi" // "wifi" | "bluetooth"
    property var wifiNetworks: []
    property var bluetoothDevices: []
    property bool wifiAvailable: true
    property bool bluetoothAvailable: true

    function toggle() {
        active = !active;
    }

    function close() {
        active = false;
    }

    onActiveChanged: {
        if (active) {
            wifiScan.running = true;
            btScan.running = true;
            Qt.callLater(() => keyArea.forceActiveFocus());
        }
    }

    Process {
        id: wifiScan
        command: ["sh", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY,ACTIVE dev wifi list 2>/dev/null"]
        property string _output: ""
        stdout: StdioCollector {
            onStreamFinished: wifiScan._output = text
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.wifiAvailable = false;
                root.wifiNetworks = [];
                return;
            }
            root.wifiAvailable = true;
            const seen = new Set();
            const list = [];
            for (const line of _output.split("\n")) {
                if (!line)
                    continue;
                const parts = line.split(":");
                const ssid = parts[0];
                if (!ssid || seen.has(ssid))
                    continue;
                seen.add(ssid);
                list.push({
                    "ssid": ssid,
                    "signal": parts[1] || "0",
                    "security": parts[2] || "",
                    "active": parts[3] === "yes"
                });
            }
            list.sort((a, b) => b.active - a.active || Number(b.signal) - Number(a.signal));
            root.wifiNetworks = list;
        }
    }

    Process {
        id: btScan
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null"]
        property string _output: ""
        stdout: StdioCollector {
            onStreamFinished: btScan._output = text
        }
        onExited: exitCode => {
            if (exitCode !== 0 || _output.includes("No default controller")) {
                root.bluetoothAvailable = false;
                root.bluetoothDevices = [];
                return;
            }
            root.bluetoothAvailable = true;
            const list = [];
            for (const line of _output.split("\n")) {
                const m = line.match(/^Device ([0-9A-Fa-f:]+) (.+)$/);
                if (m)
                    list.push({
                        "mac": m[1],
                        "name": m[2]
                    });
            }
            root.bluetoothDevices = list;
        }
    }

    Process {
        id: wifiConnect
        property string ssid: ""
        command: ["sh", "-c", `nmcli dev wifi connect "${wifiConnect.ssid}"`]
        onExited: wifiScan.running = true
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
        TapHandler {
            onTapped: root.close()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 700
        height: 500
        radius: Theme.radius.large
        color: Theme.color.surface

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Text {
                text: "Network & Bluetooth"
                color: Theme.color.surfaceText
                font.family: Theme.font.family
                font.pixelSize: Theme.font.large
            }

            Row {
                spacing: 8
                Repeater {
                    model: [
                        {
                            "id": "wifi",
                            "label": "Wi-Fi"
                        },
                        {
                            "id": "bluetooth",
                            "label": "Bluetooth"
                        }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 100
                        height: 32
                        radius: Theme.radius.small
                        color: root.tab === modelData.id ? Theme.color.accentContainer : Theme.color.surfaceContainer
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.tab === modelData.id ? Theme.color.accentText : Theme.color.surfaceText
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.small
                        }
                        TapHandler {
                            onTapped: root.tab = modelData.id
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.color.outline
            }

            // Wi-Fi list
            Column {
                width: parent.width
                visible: root.tab === "wifi"
                spacing: 4

                Text {
                    visible: !root.wifiAvailable
                    text: "NetworkManager not available in this environment."
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                }

                Repeater {
                    model: root.wifiNetworks
                    delegate: Rectangle {
                        required property var modelData
                        width: 660
                        height: 40
                        radius: Theme.radius.small
                        color: modelData.active ? Theme.color.accentContainer : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Text {
                                text: (modelData.active ? "●" : "○")
                                color: modelData.active ? Theme.color.accentText : Theme.color.surfaceVariantText
                            }
                            Text {
                                text: modelData.ssid
                                color: modelData.active ? Theme.color.accentText : Theme.color.surfaceText
                                font.family: Theme.font.family
                                font.pixelSize: Theme.font.normal
                            }
                            Text {
                                text: modelData.signal + "%  " + modelData.security
                                color: Theme.color.surfaceVariantText
                                font.family: Theme.font.family
                                font.pixelSize: Theme.font.small
                            }
                        }

                        TapHandler {
                            onTapped: {
                                wifiConnect.ssid = modelData.ssid;
                                wifiConnect.running = true;
                            }
                        }
                    }
                }
            }

            // Bluetooth list
            Column {
                width: parent.width
                visible: root.tab === "bluetooth"
                spacing: 4

                Text {
                    visible: !root.bluetoothAvailable
                    text: "No Bluetooth controller available in this environment."
                    color: Theme.color.surfaceVariantText
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.normal
                }

                Repeater {
                    model: root.bluetoothDevices
                    delegate: Rectangle {
                        required property var modelData
                        width: 660
                        height: 40
                        radius: Theme.radius.small
                        color: "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name + "   " + modelData.mac
                            color: Theme.color.surfaceText
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.normal
                        }
                    }
                }
            }
        }
    }

    Item {
        id: keyArea
        anchors.fill: parent
        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: root.tab = "wifi"
        Keys.onRightPressed: root.tab = "bluetooth"
    }
}
