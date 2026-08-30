import Quickshell
import Quickshell.Io
import qs.Bar
import qs.Spotlight
import qs.QuickNotes
import qs.WallpaperPicker
import qs.NetworkCenter

// Entrypoint. Bar is always on; the four overlays are toggled over IPC
// (`qs -c desktopdesigner ipc call <target> toggle`) per KEYBINDINGS.md's
// binding table. Per docs/00-overview.md, opening any one of them closes
// the others first — closeOthers() below is the mutual-exclusion point.
ShellRoot {
    id: root

    Bar {
        id: bar
        onNetworkIconClicked: {
            if (!networkCenter.active)
                root.closeOthers(networkCenter);
            networkCenter.toggle();
        }
    }

    Spotlight {
        id: spotlight
    }

    QuickNotes {
        id: quickNotes
    }

    WallpaperPicker {
        id: wallpaperPicker
    }

    NetworkCenter {
        id: networkCenter
    }

    function closeOthers(keep) {
        if (keep !== spotlight)
            spotlight.close();
        if (keep !== quickNotes)
            quickNotes.close();
        if (keep !== wallpaperPicker)
            wallpaperPicker.close();
        if (keep !== networkCenter)
            networkCenter.close();
    }

    IpcHandler {
        target: "spotlight"
        function toggle() {
            if (!spotlight.active)
                root.closeOthers(spotlight);
            spotlight.toggle();
        }
    }

    IpcHandler {
        target: "quickNotes"
        function toggle() {
            if (!quickNotes.active)
                root.closeOthers(quickNotes);
            quickNotes.toggle();
        }
    }

    IpcHandler {
        target: "wallpaperPicker"
        function toggle() {
            if (!wallpaperPicker.active)
                root.closeOthers(wallpaperPicker);
            wallpaperPicker.toggle();
        }
    }

    IpcHandler {
        target: "networkCenter"
        function toggle() {
            if (!networkCenter.active)
                root.closeOthers(networkCenter);
            networkCenter.toggle();
        }
    }
}
