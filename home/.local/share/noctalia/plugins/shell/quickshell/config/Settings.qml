pragma Singleton

// The shell's settings, from the nafeel/shell plugin's settings in Noctalia
// (the plugin service writes them to ~/.local/state/nafeel-shell/settings.json;
// changes apply live).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // tight | compact | restrained | relaxed | generous
    property string radius: "restrained"
    // immersive | ornament
    property string immersion: "immersive"
    // normal | brisk | reduced
    property string motion: "normal"
    // Frosted paper opacity: "90" | "85" | "80", or "solid"
    property string paper: "85"
    // A place name for the weather.
    property string location: ""
    // Live wallpapers: "original" | "screen" (a screen-sized copy), and
    // whether they keep playing on battery.
    // Live wallpaper resolution: "original" | "1080" | "720" (a copy).
    property string liveQuality: "original"
    property bool liveOnBattery: false
    // Wallhaven API key (optional: sketchy/NSFW results and your settings).
    property string wallhavenKey: ""

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.radius = s.radius ?? root.radius;
                root.immersion = s.immersion ?? root.immersion;
                root.motion = s.motion ?? root.motion;
                root.paper = s.paper ?? root.paper;
                root.location = s.location ?? root.location;
                root.wallhavenKey = s.wallhavenKey ?? root.wallhavenKey;
                root.liveQuality = s.liveQuality ?? root.liveQuality;
                root.liveOnBattery = s.liveOnBattery ?? root.liveOnBattery;
            } catch (e) {}
        }
    }
}
