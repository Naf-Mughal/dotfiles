pragma Singleton

// The wallpaper library (~/Pictures/Wallpapers, folders as collections) and
// setting one through Noctalia, which retints the palette from it.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    // [{ path, name, folder }]
    property var all: []
    readonly property var folders: [...new Set(all.map(w => w.folder))].sort()

    function inFolder(folder: string): var {
        return folder ? all.filter(w => w.folder === folder) : all;
    }

    function set(path: string): void {
        Quickshell.execDetached(["noctalia", "msg", "wallpaper-set", path]);
        Session.wallpaper = path;
    }

    function random(): void {
        Quickshell.execDetached(["noctalia", "msg", "wallpaper-random"]);
        refreshCurrent.restart();
    }

    function rescan(): void {
        scan.running = true;
    }

    Timer {
        id: refreshCurrent

        interval: 800
        onTriggered: Session.refreshWallpaper()
    }

    Process {
        id: scan

        running: true
        command: ["find", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.all = text.split("\n").filter(p => p).sort().map(p => {
                    const rel = p.slice(root.dir.length + 1);
                    const parts = rel.split("/");
                    return {
                        path: p,
                        name: parts[parts.length - 1],
                        folder: parts.length > 1 ? parts[0] : ""
                    };
                });
            }
        }
    }
}
