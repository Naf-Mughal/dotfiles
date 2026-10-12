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
        // The picker's view: strip | hand | mosaic.
        function view(name: string): void {
            root.view = name;
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

    // ── The library ─────────────────────────────────────────────────────
    // The index (bin/nafeel-theme index -> theme/palette/library.py, after
    // Ryoku's indexing daemon): every wallpaper with a thumbnail and its
    // colour. A quick `find` fills `all` first so the picker never waits; the
    // index then adds thumbnails and colours, and new files get indexed in
    // the background (progress: Bus "library.progress" { done, total }).

    readonly property string indexPath: Quickshell.env("HOME") + "/.cache/nafeel-shell/library.json"
    readonly property string bin: Quickshell.shellDir + "/../bin/nafeel-theme"
    property bool indexing: indexer.running
    property real indexProgress: 1

    // Filters for the picker (all optional): folder, colour bucket (0..11 hue
    // in 30° steps from red, 99 black and white, -1 any), tone ("dark" |
    // "light" | ""), favourites only, and a search.
    property string filterFolder: ""
    property int filterColour: -1
    property string filterTone: ""
    property bool filterFavourites: false
    property string query: ""
    // "name" | "colour" | "recent" | "used"
    property string sortMode: "name"
    // The picker's view: "strip" | "hand" | "mosaic".
    property string view: "strip"
    onSortModeChanged: _saveMeta()
    onViewChanged: _saveMeta()
    property var favourites: ({})
    property var useCount: ({})

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        let list = all.filter(w => (!filterFolder || w.folder === filterFolder) && (filterColour < 0 || w.bucket === filterColour) && (!filterTone || (filterTone === "dark" ? (w.lightness ?? 0.5) < 0.42 : (w.lightness ?? 0.5) >= 0.55)) && (!filterFavourites || favourites[w.path]) && (!q || w.name.toLowerCase().includes(q) || w.folder.toLowerCase().includes(q)));
        const byName = (a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0;
        switch (sortMode) {
        case "colour":
            // Round the colour wheel, vivid first in each hue; black and white last.
            list = list.slice().sort((a, b) => ((a.bucket ?? 99) - (b.bucket ?? 99)) || ((b.chroma ?? 0) - (a.chroma ?? 0)) || byName(a, b));
            break;
        case "recent":
            list = list.slice().sort((a, b) => (b.mtime ?? 0) - (a.mtime ?? 0));
            break;
        case "used":
            list = list.slice().sort((a, b) => (useCount[b.path] ?? 0) - (useCount[a.path] ?? 0) || byName(a, b));
            break;
        }
        return list;
    }

    function toggleFavourite(path: string): void {
        const f = Object.assign({}, favourites);
        if (f[path])
            delete f[path];
        else
            f[path] = true;
        favourites = f;
        _saveMeta();
    }

    function clearFilters(): void {
        filterFolder = "";
        filterColour = -1;
        filterTone = "";
        filterFavourites = false;
        query = "";
    }

    function _saveMeta(): void {
        if (!metaLoaded)
            return;
        metaFile.setText(JSON.stringify({
            favourites,
            useCount,
            view,
            sortMode
        }, null, 2) + "\n");
    }

    function _index(): void {
        if (!indexer.running)
            indexer.running = true;
    }

    property bool metaLoaded: false

    // Favourites, how often each was set (Ryoku's "apply count"), the view.
    FileView {
        id: metaFile

        path: root.stateDir + "/wallpaper-library.json"
        printErrors: false
        onLoaded: {
            try {
                const m = JSON.parse(text());
                root.favourites = m.favourites ?? {};
                root.useCount = m.useCount ?? {};
                root.view = m.view ?? root.view;
                root.sortMode = m.sortMode ?? root.sortMode;
            } catch (e) {}
            root.metaLoaded = true;
        }
        onLoadFailed: root.metaLoaded = true
    }

    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic !== "wallpaper.current" || !payload.path)
                return;
            const u = Object.assign({}, root.useCount);
            u[payload.path] = (u[payload.path] ?? 0) + 1;
            root.useCount = u;
            root._saveMeta();
        }
    }

    FileView {
        id: indexFile

        path: root.indexPath
        printErrors: false
        onLoaded: {
            try {
                const idx = JSON.parse(text());
                const byPath = {};
                for (const w of idx.wallpapers ?? [])
                    byPath[w.path] = w;
                // Keep files the index hasn't reached yet (new ones).
                const merged = root.all.map(w => byPath[w.path] ?? w);
                const have = new Set(merged.map(w => w.path));
                for (const w of idx.wallpapers ?? [])
                    if (!have.has(w.path))
                        merged.push(w);
                root.all = merged.sort((a, b) => a.path < b.path ? -1 : 1);
            } catch (e) {
                console.warn("wallpapers: bad library index:", e);
            }
        }
    }

    Process {
        id: indexer

        command: [root.bin, "index"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const p = JSON.parse(line);
                    if (p.total) {
                        root.indexProgress = p.done / p.total;
                        Bus.publish("library.progress", p);
                    }
                } catch (e) {}
            }
        }
        onExited: {
            root.indexProgress = 1;
            indexFile.reload();
            Bus.publish("library.updated", {
                count: root.all.length
            });
        }
    }

    Process {
        id: scan

        running: true
        command: ["find", root.dir, "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const known = {};
                for (const w of root.all)
                    known[w.path] = w;
                root.all = text.split("\n").filter(p => p && !p.includes("/.")).sort().map(p => {
                    if (known[p])
                        return known[p];
                    const rel = p.slice(root.dir.length + 1);
                    const parts = rel.split("/");
                    return {
                        path: p,
                        name: parts[parts.length - 1],
                        folder: parts.length > 1 ? parts[0] : ""
                    };
                });
                indexFile.reload();
                // New or changed files get thumbnails and colours.
                root._index();
            }
        }
    }
}
