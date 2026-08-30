pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU/RAM polling — no event source exists for these (documented exception
// in docs/00-overview.md's "no polling" rule). 1s interval, 60-sample
// rolling history per docs/02-bar.md's sparkline spec.
//
// ponytail: CPU + RAM only. GPU/disk/network/temp/fan from the full spec's
// metric table need hwmon/lm_sensors/nvidia-smi parsing each with their own
// quirks — add as separate polling blocks here, same pattern, when the Bar
// actually grows a slot for them.
Singleton {
    id: root

    readonly property int historyLength: 60
    property var cpuHistory: []
    property var ramHistory: []
    property real cpuPercent: 0
    property real ramPercent: 0
    property bool hasBattery: false
    property real batteryPercent: 0
    property bool batteryCharging: false

    property var _prevCpu: null

    function _pushHistory(arr, value) {
        const next = arr.length >= historyLength ? arr.slice(1) : arr.slice();
        next.push(value);
        return next;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    Process {
        id: poll
        command: ["sh", "-c", "cat /proc/stat; echo '---MEM---'; cat /proc/meminfo; echo '---BAT---'; cat /sys/class/power_supply/BAT0/capacity 2>/dev/null; cat /sys/class/power_supply/BAT0/status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root._handlePoll(text)
        }
    }

    function _handlePoll(text) {
        const sections = text.split("---MEM---");
        const cpuLine = sections[0].split("\n")[0];
        const rest = (sections[1] || "").split("---BAT---");
        const memText = rest[0] || "";
        const batText = (rest[1] || "").trim().split("\n").map(s => s.trim()).filter(s => s.length);

        // CPU: "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
        const parts = cpuLine.trim().split(/\s+/).slice(1).map(Number);
        const idle = parts[3] + (parts[4] || 0);
        const total = parts.reduce((a, b) => a + b, 0);
        if (root._prevCpu) {
            const dTotal = total - root._prevCpu.total;
            const dIdle = idle - root._prevCpu.idle;
            if (dTotal > 0)
                root.cpuPercent = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
        }
        root._prevCpu = {
            "total": total,
            "idle": idle
        };
        root.cpuHistory = root._pushHistory(root.cpuHistory, root.cpuPercent);

        // RAM: MemTotal / MemAvailable, both in kB
        const memTotalMatch = memText.match(/MemTotal:\s*(\d+)/);
        const memAvailMatch = memText.match(/MemAvailable:\s*(\d+)/);
        if (memTotalMatch && memAvailMatch) {
            const memTotal = Number(memTotalMatch[1]);
            const memAvail = Number(memAvailMatch[1]);
            if (memTotal > 0)
                root.ramPercent = Math.max(0, Math.min(1, 1 - memAvail / memTotal));
        }
        root.ramHistory = root._pushHistory(root.ramHistory, root.ramPercent);

        // Battery: capacity int, status string — absent entirely on desktops
        if (batText.length >= 1 && /^\d+$/.test(batText[0])) {
            root.hasBattery = true;
            root.batteryPercent = Number(batText[0]) / 100;
            root.batteryCharging = (batText[1] || "") === "Charging";
        } else {
            root.hasBattery = false;
        }
    }
}
