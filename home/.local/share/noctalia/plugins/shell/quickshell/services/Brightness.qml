pragma Singleton

// The laptop panel's backlight, read from sysfs whenever udev reports a
// change; changed through Noctalia so its night light stays in charge.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int raw: 0
    readonly property bool available: device !== "" && max > 0
    readonly property real level: available ? raw / max : 0

    // (Kept for callers; the level is always live now.)
    property int watchers: 0

    function set(v: real): void {
        Quickshell.execDetached(["noctalia", "msg", "brightness-set", String(Math.round(Math.max(0.01, Math.min(1, v)) * 100))]);
        raw = Math.round(Math.max(0.01, Math.min(1, v)) * max);
    }

    function step(up: bool): void {
        Quickshell.execDetached(["noctalia", "msg", up ? "brightness-up" : "brightness-down"]);
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -r "$d/max_brightness" ] && { echo "${d##*/} $(cat "$d/max_brightness")"; exit; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const [dev, max] = text.trim().split(" ");
                root.device = dev ?? "";
                root.max = parseInt(max) || 0;
            }
        }
    }

    FileView {
        id: file

        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: root.raw = parseInt(text()) || 0
    }

    // Every backlight change, from any source (keys, Noctalia, brightnessctl).
    Process {
        running: root.available
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change"))
                    file.reload();
            }
        }
    }

    Component.onCompleted: Qt.callLater(() => file.reload())
}
