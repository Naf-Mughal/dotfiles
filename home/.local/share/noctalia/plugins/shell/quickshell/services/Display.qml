pragma Singleton

// Night light and caffeine, run by the shell itself: the night light through
// the native NightLight (gamma control, Noctalia's maths), caffeine as a
// Wayland idle inhibitor held by each screen's frame (FrameWindow), which
// anything watching for idle respects. Both are remembered in
// ~/.local/state/nafeel-shell/display.json. Dark mode still goes through
// Noctalia (it owns the palette until the theme engine moves).

import QtQuick
import Quickshell
import Quickshell.Io
import Nafeel

Singleton {
    id: root

    property bool nightLight: false
    property bool caffeine: false
    // The night temperature (Kelvin).
    property int nightTemperature: 4000

    NightLight {
        active: root.nightLight
        temperature: root.nightTemperature
    }

    function save(): void {
        file.setText(JSON.stringify({
            nightLight: nightLight,
            caffeine: caffeine
        }));
    }

    function toggleNightLight(): void {
        nightLight = !nightLight;
        save();
    }

    function toggleCaffeine(): void {
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
