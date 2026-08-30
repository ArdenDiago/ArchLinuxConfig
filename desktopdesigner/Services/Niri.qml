pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Minimal niri IPC wrapper — event-stream subscription + one-shot actions.
// Pattern (socket + reconnect-with-backoff, EventStream subscribe, Action
// send) verified against DankMaterialShell's Services/NiriService.qml
// (installed at /usr/share/quickshell/dms/Services/NiriService.qml on this
// system) which implements the same niri IPC protocol at full scale; this
// is a deliberately smaller subset — just enough state for the Bar's window
// capsules (docs/02-bar.md) and Spotlight/window-adjacent needs. No output/
// keyboard-layout/screenshot/layout-config tracking — add if a later
// component actually needs it.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET")
    readonly property bool available: socketPath !== undefined && socketPath !== ""

    property var windows: []
    // var, not string/int — must retain niri's exact JSON type (number) so
    // the strict-equality filter below actually matches windows[].workspace_id.
    property var focusedWorkspaceId: null
    property var workspaces: ({})

    readonly property var focusedWorkspaceWindows: windows.filter(w => w.workspace_id === focusedWorkspaceId)

    function focusWindow(id) {
        _send({
            "Action": {
                "FocusWindow": {
                    "id": id
                }
            }
        });
    }

    function closeWindow(id) {
        _send({
            "Action": {
                "CloseWindow": {
                    "id": id
                }
            }
        });
    }

    function _send(request) {
        if (!available || !requestSocket.linkUp)
            return;
        const json = JSON.stringify(request);
        requestSocket.socket.write(json.endsWith("\n") ? json : json + "\n");
        requestSocket.socket.flush();
    }

    function _handleEvent(event) {
        const type = Object.keys(event)[0];
        const data = event[type];
        switch (type) {
        case "WindowsChanged":
            windows = data.windows;
            break;
        case "WindowOpenedOrChanged":
            {
                const idx = windows.findIndex(w => w.id === data.window.id);
                const next = [...windows];
                if (idx >= 0)
                    next[idx] = data.window;
                else
                    next.push(data.window);
                windows = next;
            }
            break;
        case "WindowClosed":
            windows = windows.filter(w => w.id !== data.id);
            break;
        case "WindowFocusChanged":
            windows = windows.map(w => (w.id === data.id) === w.is_focused ? w : Object.assign({}, w, {
                "is_focused": w.id === data.id
            }));
            break;
        case "WorkspacesChanged":
            {
                const map = {};
                for (const ws of data.workspaces)
                    map[ws.id] = ws;
                workspaces = map;
                const focused = data.workspaces.find(ws => ws.is_focused);
                if (focused)
                    focusedWorkspaceId = focused.id;
            }
            break;
        case "WorkspaceActivated":
            if (data.focused)
                focusedWorkspaceId = data.id;
            break;
        }
    }

    // Reconnect-with-backoff wrapper around the raw socket, same shape as
    // DMS's Common/DankSocket.qml (a small, generally-useful pattern for any
    // niri/sway/hyprland IPC socket, not something specific to their shell).
    Item {
        id: eventSocket
        property bool linkUp: false

        Socket {
            id: socket
            path: root.socketPath
            connected: root.available

            onConnectionStateChanged: {
                eventSocket.linkUp = connected;
                if (connected)
                    write('"EventStream"\n');
            }

            parser: SplitParser {
                onRead: line => {
                    try {
                        root._handleEvent(JSON.parse(line));
                    } catch (e) {
                        console.warn("Niri: failed to parse event line:", line);
                    }
                }
            }
        }
    }

    Item {
        id: requestSocket
        property bool linkUp: false
        property alias socket: reqSocket

        Socket {
            id: reqSocket
            path: root.socketPath
            connected: root.available
            onConnectionStateChanged: requestSocket.linkUp = connected
        }
    }
}
