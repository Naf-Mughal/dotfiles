pragma Singleton

// Who and where: display name, user@host, uptime and the current wallpaper
// (from Noctalia, refreshed whenever the palette changes).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER")
    property string realName: ""
    property string host: ""
    property string wallpaper: ""
    property real uptime: 0 // seconds

    function refreshWallpaper(): void {
        wallpaperQuery.running = true;
    }

    Connections {
        target: Colours

        function onNoctaliaSchemeChanged(): void {
            root.refreshWallpaper();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; cat /etc/hostname']
        stdout: StdioCollector {
            onStreamFinished: {
                const [name, host] = text.split("\n");
                root.realName = name || root.user;
                root.host = host ?? "";
            }
        }
    }

    Process {
        id: wallpaperQuery

        running: true
        command: ["noctalia", "msg", "wallpaper-get"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpaper = text.trim()
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        onLoaded: root.uptime = parseFloat(text()) || 0
    }

    Timer {
        running: true
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    function formatUptime(): string {
        const s = uptime, d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return `${d > 0 ? d + " d " : ""}${h > 0 ? h + " h " : ""}${m} min`;
    }
}
