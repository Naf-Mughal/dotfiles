pragma Singleton

// The theme step, run by the shell: whenever the wallpaper or a setting the
// theme carries (paper opacity, radius) changes, `nafeel-theme update` takes
// the palette from the wallpaper (only when it changed), writes theme.json
// (Colours follows it) and renders every app template from it.
//
// IPC: qs -p <shell> ipc call theme update | force

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string bin: Quickshell.shellDir + "/../bin/nafeel-theme"
    property bool running: false
    property bool again: false
    property bool forceNext: false
    // The last run's output (one line per template), for a settings page.
    property string report: ""

    function update(force: bool): void {
        forceNext = forceNext || force;
        if (running) {
            again = true;
            return;
        }
        debounce.restart();
    }

    IpcHandler {
        target: "theme"

        function update(): void {
            root.update(false);
        }
        function force(): void {
            root.update(true);
        }
    }

    // Several changes at once (the wallpaper and its palette settle together)
    // make one run.
    Timer {
        id: debounce

        interval: 250
        onTriggered: {
            proc.command = [root.bin, "update", ...(root.forceNext ? ["--force"] : []), ...(Wallpapers.current ? ["--wallpaper", Wallpapers.current] : [])];
            root.forceNext = false;
            root.running = true;
            proc.running = true;
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: root.report = text
        }
        stderr: SplitParser {
            onRead: line => console.log("theme:", line)
        }
        onExited: code => {
            root.running = false;
            if (code !== 0)
                console.warn("theme: nafeel-theme update exited with", code);
            if (root.again) {
                root.again = false;
                root.update(false);
            }
        }
    }

    Connections {
        target: Wallpapers

        function onCurrentChanged(): void {
            root.update(false);
        }
    }

    Connections {
        target: Settings

        function onPaperChanged(): void {
            root.update(false);
        }
        function onRadiusChanged(): void {
            root.update(false);
        }
    }

    Component.onCompleted: if (Wallpapers.current)
        update(false)
}
