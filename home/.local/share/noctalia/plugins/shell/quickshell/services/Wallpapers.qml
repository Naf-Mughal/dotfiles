pragma Singleton

// The wallpaper: which one is set (drawn by modules/background), and the
// library (~/Pictures/Wallpapers, folders as collections) it's picked from.
//
// An ActionService: the picker stages a wallpaper as you choose (its palette
// is made meanwhile), and closing the picker sets it, so the theme changes at
// once, under the shell's ink transition (Theme.go). IPC and keybinds set at
// once (run). `current` follows "wallpaper.current" on the Bus, so it changes
// when the ink lands, with everything else.
//
// The path lives in ~/.local/state/nafeel-shell/wallpaper.json (the first run
// took Noctalia's).
//
// IPC: qs -p <shell> ipc call wallpaper set <path> | random | get

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"
    // The wallpaper as it is now ("" until known).
    property string current: ""
    // What the picker has chosen and will set on close ("" = nothing).
    readonly property string chosen: act.staged?.action === "set" ? act.staged.args : ""
    // [{ path, name, folder }]
    property var all: []
    readonly property var folders: [...new Set(all.map(w => w.folder))].sort()

    // The picker's choices: staged, set on close.
    readonly property ActionService act: ActionService {
        name: "wallpaper"
        drawer: "wallpapers"
        actions: ({
                set: path => {
                    if (path && path !== root.current)
                        Theme.go(path);
                }
            })
        prepare: ({
                set: path => Theme.prepare(path)
            })
    }

    function stage(action: string, args: var): void {
        act.stage(action, args);
    }

    function inFolder(folder: string): var {
        return folder ? all.filter(w => w.folder === folder) : all;
    }

    // Set at once (IPC, keybinds, a click outside the picker).
    function set(path: string): void {
        act.run("set", path);
    }

    // Any other wallpaper, from the whole library, at once.
    function random(): void {
        const others = all.filter(w => w.path !== current);
        if (others.length > 0)
            set(others[Math.floor(Math.random() * others.length)].path);
    }

    function rescan(): void {
        scan.running = true;
    }

    function _remember(path: string): void {
        current = path;
        stateFile.setText(JSON.stringify({
            path
        }, null, 2) + "\n");
    }

    // The ink landed (Theme): it's the wallpaper now.
    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic === "wallpaper.current" && payload.path && payload.path !== root.current)
                root._remember(payload.path);
        }
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
                // Others (Background) start from the remembered one.
                if (p)
                    Bus.retain("wallpaper.current", {
                        path: p
                    });
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
                if (p && !p.startsWith("error")) {
                    root._remember(p);
                    Bus.retain("wallpaper.current", {
                        path: p
                    });
                }
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
