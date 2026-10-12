pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

// The wallpaper, on every screen, under everything. It takes part in the
// shell's ink transition: a new wallpaper is decoded ahead ("wallpaper.preload"
// on the Bus; "wallpaper.loaded" once it's ready), swapped in under the
// window's InkStill when the change lands ("wallpaper.current"), and soaks
// through together with the new colours. Images are decoded at the screen's
// size, so a 6K wallpaper costs no more than the screen.
//
// The namespace stays clear of the frost rule (^nafeel-shell): the wallpaper
// is what the panels blur, it isn't blurred itself.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData
        readonly property size decode: Qt.size(Math.round(width * (modelData.devicePixelRatio || 1)), Math.round(height * (modelData.devicePixelRatio || 1)))
        // Which slot is on screen; the other one decodes the next wallpaper.
        property int front: 0
        readonly property Image shown: front === 0 ? a : b
        readonly property Image spare: front === 0 ? b : a

        function url(path: string): string {
            return path ? "file://" + path : "";
        }

        screen: modelData
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        color: Colours.palette.m3surface
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "nafeel-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        component Slot: Image {
            anchors.fill: parent
            sourceSize: win.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
        }

        Slot {
            id: a

            visible: win.front === 0
            onStatusChanged: win.loaded(a)
        }

        Slot {
            id: b

            visible: win.front === 1
            onStatusChanged: win.loaded(b)
        }

        // The spare slot finished decoding: say so (the transition waits).
        function loaded(slot: Image): void {
            if (slot === spare && slot.status !== Image.Loading && slot.status !== Image.Null)
                Bus.publish("wallpaper.loaded", {
                    path: decodeURIComponent(slot.source.toString().replace("file://", ""))
                });
        }

        Subscribe {
            topic: "wallpaper.preload"
            onReceived: p => {
                const u = win.url(p.path);
                if (win.spare.source.toString() === u && win.spare.status === Image.Ready)
                    win.loaded(win.spare);
                else
                    win.spare.source = u;
            }
        }

        Subscribe {
            topic: "wallpaper.current"
            onReceived: p => {
                const u = win.url(p.path);
                if (win.shown.source.toString() === u)
                    return;
                if (win.spare.source.toString() === u) {
                    // Decoded ahead: swap (under the ink, if it's running).
                    win.front = 1 - win.front;
                } else {
                    // The first one, or one nobody preloaded.
                    win.shown.source = u;
                }
            }
        }

        InkStill {}
    }
}
