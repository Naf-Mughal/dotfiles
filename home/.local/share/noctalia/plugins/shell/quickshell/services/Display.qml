pragma Singleton

// Night light and caffeine, through Noctalia. Noctalia doesn't report either
// state, so the shell remembers what was last set here
// (~/.local/state/nafeel-shell/display.json). Dark mode is read from the
// palette (Colours.light).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool nightLight: false
    property bool caffeine: false

    function save(): void {
        file.setText(JSON.stringify({
            nightLight: nightLight,
            caffeine: caffeine
        }));
    }

    function toggleNightLight(): void {
        Quickshell.execDetached(["noctalia", "msg", "nightlight-force-toggle"]);
        nightLight = !nightLight;
        save();
    }

    function toggleCaffeine(): void {
        Quickshell.execDetached(["noctalia", "msg", "caffeine-toggle"]);
        caffeine = !caffeine;
        save();
    }

    function toggleDarkMode(): void {
        Quickshell.execDetached(["noctalia", "msg", "theme-mode-toggle"]);
    }

    // For keybinds: qs -p <shell> ipc call display caffeine | nightLight
    IpcHandler {
        target: "display"

        function caffeine(): void {
            root.toggleCaffeine();
        }

        function nightLight(): void {
            root.toggleNightLight();
        }
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/display.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.nightLight = !!d.nightLight;
                root.caffeine = !!d.caffeine;
            } catch (e) {}
        }
    }
}
