pragma Singleton

// Who and where: display name, user@host, uptime and the current wallpaper
// (Wallpapers.current). And the session
// actions, run by the shell itself: lock (the shell's lock), suspend (lock,
// then sleep), and log out / restart / shut down through graceful-power
// (every app is asked to close first, holdouts reported).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string user: Quickshell.env("USER")
    readonly property string home: Quickshell.env("HOME")
    property string realName: ""
    property string host: ""
    // A picture of it (a live wallpaper's frame), for the home tab and the
    // workspaces.
    readonly property string wallpaper: Wallpapers.stillOf(Wallpapers.current)
    property real uptime: 0 // seconds

    readonly property string gracefulPower: Quickshell.env("HOME") + "/.local/share/noctalia/plugins/graceful-power/bin/graceful-power"

    // The shell's lock listens for this (Lock.qml).
    signal lockRequested

    // For keybinds: qs -p <shell> ipc call session run <action>
    IpcHandler {
        target: "session"

        function run(action: string): void {
            root.run(action);
        }
    }

    // lock | suspend | logout | reboot | shutdown
    function run(action: string): void {
        switch (action) {
        case "lock":
            lockRequested();
            break;
        case "suspend":
            lockRequested();
            Quickshell.execDetached(["sh", "-c", "sleep 0.6; systemctl suspend"]);
            break;
        case "logout":
        case "reboot":
        case "shutdown":
            Quickshell.execDetached([gracefulPower, action]);
            break;
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
