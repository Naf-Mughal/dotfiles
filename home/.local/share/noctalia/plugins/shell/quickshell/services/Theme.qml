pragma Singleton

// The theme, conducted: the palette is made ahead (while the wallpaper picker
// is still open, `nafeel-theme update --stage`), the wallpaper is decoded
// ahead, and then one shell-wide ink transition (Ink) changes it all
// at once: the shell's colours and the wallpaper under the ink, the apps
// (`nafeel-theme commit`: templates, open terminals) as it soaks through.
//
//   Theme.prepare(path)        get ready for a wallpaper (staged in the picker)
//   Theme.go(path)             change to it (the picker closed, IPC, random)
//   Theme.refresh()            settings changed (paper, radius): rebuild, no ink
//
// Bus: "theme.ready" { path } (staged), "theme.changed" { doc } (retained:
// the current theme document), "wallpaper.preload" { path } (Background
// decodes it, answers "wallpaper.loaded"), "wallpaper.current" { path }.
//
// IPC: qs -p <shell> ipc call theme update | force

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string bin: Quickshell.shellDir + "/../bin/nafeel-theme"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"

    // The wallpaper whose theme is staged (theme-next.json), and the one
    // being staged now.
    property string stagedPath: ""
    property string stagingPath: ""
    // The staged document, as the stage printed it (its .wallpaper says
    // which wallpaper it is for).
    property var stagedDoc: null
    // A change waiting on staging / decoding: { path, staged, loaded }.
    property var pending: null
    // The last apply's report (one line per template).
    property string report: ""

    function prepare(path: string): void {
        if (!path || path === stagedPath || path === stagingPath)
            return;
        if (stage.running) {
            // The latest pick wins; it's staged once this run ends.
            nextStage = path;
            return;
        }
        stagingPath = path;
        stage.command = [bin, "update", "--stage", "--wallpaper", path];
        stage.running = true;
    }

    property string nextStage: ""

    function go(path: string): void {
        if (!path)
            return;
        pending = {
            path,
            staged: path === stagedPath,
            loaded: false
        };
        if (!pending.staged)
            prepare(path);
        Bus.publish("wallpaper.preload", {
            path
        });
        giveUp.restart();
    }

    function refresh(): void {
        if (!apply.running) {
            apply.command = [bin, "update"];
            apply.running = true;
        } else {
            refreshAgain = true;
        }
    }

    property bool refreshAgain: false
    // A staged theme whose apps still wait for the ink to get far enough.
    property bool appsOwed: false

    Connections {
        target: Ink

        function onProgressChanged(): void {
            if (root.appsOwed && Ink.frozen && Ink.progress >= 0.55)
                root._commitApps();
        }
        function onFrozenChanged(): void {
            // No ink (reduced motion) or it ended early: don't leave them.
            if (root.appsOwed && !Ink.frozen)
                root._commitApps();
        }
    }

    function _commitApps(): void {
        appsOwed = false;
        commit.running = true;
    }

    function _maybeGo(): void {
        const p = pending;
        if (!p || !p.staged || !p.loaded)
            return;
        pending = null;
        giveUp.stop();
        // Only this wallpaper's document; anything else waits for the commit
        // (which reloads theme.json) rather than showing the wrong colours.
        const doc = stagedDoc && stagedDoc.wallpaper === p.path ? stagedDoc : null;
        Ink.ink(() => {
            if (doc)
                Colours.load(doc);
            Bus.retain("wallpaper.current", {
                path: p.path
            });
        }, Qt.point(0.5, 0.5));
        // The apps follow the ink: their templates start rendering halfway
        // through (about as long as the rest of the soak), so terminals,
        // GTK, Qt and the compositor land as the shell does.
        appsOwed = true;
        // Reduced motion: no ink ran, the change already happened.
        if (!Ink.frozen && !Ink.capturing)
            _commitApps();
    }

    function _parse(text: string): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    IpcHandler {
        target: "theme"

        function update(): void {
            root.refresh();
        }
        // What the shell is showing: "<primary> <surface> <mode> <wallpaper>".
        function state(): string {
            return `${Colours.palette.m3primary} ${Colours.palette.m3surface} ${Colours.theme?.mode} ${Colours.theme?.wallpaper}`;
        }
        function force(): void {
            apply.command = [root.bin, "update", "--force"];
            apply.running = true;
        }
    }

    // Staged and decoded never both arrive (a broken file, a failed palette):
    // change anyway, with what there is.
    Timer {
        id: giveUp

        interval: 8000
        onTriggered: {
            if (!root.pending)
                return;
            console.warn("theme: change to", root.pending.path, "went ahead without", root.pending.staged ? "the decoded wallpaper" : "its palette");
            root.pending = Object.assign({}, root.pending, {
                staged: true,
                loaded: true
            });
            root._maybeGo();
        }
    }

    Connections {
        target: Bus

        function onPublished(topic: string, payload: var): void {
            if (topic === "wallpaper.loaded" && root.pending && payload.path === root.pending.path) {
                root.pending = Object.assign({}, root.pending, {
                    loaded: true
                });
                root._maybeGo();
            }
        }
    }

    Process {
        id: stage

        stdout: StdioCollector {
            onStreamFinished: {
                const doc = root._parse(text.trim());
                if (doc?.wallpaper)
                    root.stagedDoc = doc;
            }
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: code => {
            const path = root.stagingPath;
            root.stagingPath = "";
            if (code === 0 && root.stagedDoc?.wallpaper === path) {
                root.stagedPath = path;
                Bus.publish("theme.ready", {
                    path
                });
                if (root.pending && root.pending.path === path) {
                    root.pending = Object.assign({}, root.pending, {
                        staged: true
                    });
                    root._maybeGo();
                }
            }
            if (root.nextStage) {
                const n = root.nextStage;
                root.nextStage = "";
                root.prepare(n);
            }
        }
    }

    Process {
        id: commit

        command: [root.bin, "commit"]
        stdout: StdioCollector {
            onStreamFinished: root.report = text
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: {
            root.stagedPath = "";
            root.stagedDoc = null;
            // Whatever happened on the way, end on the theme the apps got.
            current.reload();
        }
    }

    // A rebuild without a change of wallpaper (settings), or the first run.
    Process {
        id: apply

        stdout: StdioCollector {
            onStreamFinished: root.report = text
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: {
            current.reload();
            if (root.refreshAgain) {
                root.refreshAgain = false;
                root.refresh();
            }
        }
    }

    // The current theme document, published for whoever follows it.
    FileView {
        id: current

        path: `${root.stateDir}/theme.json`
        printErrors: false
        onLoaded: {
            const doc = root._parse(text());
            if (!doc)
                return;
            Colours.load(doc);
            Bus.retain("theme.changed", {
                doc
            });
        }
    }

    Connections {
        target: Settings

        function onPaperChanged(): void {
            root.refresh();
        }
        function onRadiusChanged(): void {
            root.refresh();
        }
    }
}
