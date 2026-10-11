pragma Singleton

// CPU, memory and temperature, read from /proc and sysfs every 2 s while
// anything shows them (`watchers`).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int watchers: 0
    property real cpu: 0
    property real memUsed: 0 // bytes
    property real memTotal: 0
    property real temp: 0 // °C
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0

    property var lastCpu: null

    Timer {
        running: root.watchers > 0
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            thermal.running = true;
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] ?? 0), total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? 1 - (idle - root.lastCpu.idle) / dt : 0;
            }
            root.lastCpu = {
                idle: idle,
                total: total
            };
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const get = k => Number((text().match(new RegExp(`^${k}:\\s+(\\d+)`, "m")) ?? [0, 0])[1]) * 1024;
            root.memTotal = get("MemTotal");
            root.memUsed = root.memTotal - get("MemAvailable");
        }
    }

    // The CPU's own sensor (k10temp on AMD, coretemp on Intel), else the
    // hottest thermal zone.
    Process {
        id: thermal

        command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do case "$(cat "$h/name")" in k10temp|coretemp|zenpower) cat "$h/temp1_input"; exit;; esac; done; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1']
        stdout: StdioCollector {
            onStreamFinished: root.temp = (parseInt(text) || 0) / 1000
        }
    }
}
