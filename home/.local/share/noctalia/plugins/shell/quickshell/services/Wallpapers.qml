pragma Singleton

// The wallpaper: which one is set (the shell's own state, drawn by
// modules/background), and the library (~/Pictures/Wallpapers, folders as
// collections) it's picked from.
//
// The path lives in ~/.local/state/nafeel-shell/wallpaper.json. The first run
// takes Noctalia's. Until the shell does the palette and the app templates
// itself (N5), every change is also handed to Noctalia (it no longer draws
// it), so the wallpaper-palette plugin sees it and retints from it.
//
// IPC: qs -p <shell> ipc call wallpaper set <path> | random | get

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"
    // The current wallpaper's path ("" until it's known).
    property string current: ""
    // [{ path, name, folder }]
    property var all: []
    readonly property var folders: [...new Set(all.map(w => w.folder))].sort()

    function inFolder(folder: string): var {
        return folder ? all.filter(w => w.folder === folder) : all;
    }

    function set(path: string): void {
        if (!path || path === current)
            return;
        current = path;
        stateFile.setText(JSON.stringify({
            path
        }, null, 2) + "\n");
        Quickshell.execDetached(["noctalia", "msg", "wallpaper-set", path]);
    }

    // Any other wallpaper, from the whole library.
    function random(): void {
        const others = all.filter(w => w.path !== current);
        if (others.length > 0)
            set(others[Math.floor(Math.random() * others.length)].path);
    }

    function rescan(): void {
        scan.running = true;
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.set(path);
        }
        function random(): void {
            root.random();
        }
        function get(): string {
            return root.current;
        }
    }

    FileView {
        id: stateFile

        path: root.stateDir + "/wallpaper.json"
        printErrors: false
        onLoaded: {
            try {
                const p = JSON.parse(text()).path ?? "";
                if (p)
                    root.current = p;
                else
                    adopt.running = true;
            } catch (e) {
                adopt.running = true;
            }
        }
        onLoadFailed: adopt.running = true
    }

    // First run: carry over Noctalia's wallpaper.
    Process {
        id: adopt

        command: ["sh", "-c", 'mkdir -p "$1"; noctalia msg wallpaper-get', "sh", root.stateDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p && !p.startsWith("error"))
                    root.set(p);
            }
        }
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
