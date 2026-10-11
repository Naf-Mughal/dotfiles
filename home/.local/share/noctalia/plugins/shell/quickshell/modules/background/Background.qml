pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The wallpaper (Wallpapers.current), on every screen, under everything. A new
// one soaks in over the old like ink into paper (the panels' soak front, from
// the middle out), then takes its place. Images are decoded at the screen's
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

        // What's set now; and the next one, soaking in over it.
        Image {
            id: shown

            anchors.fill: parent
            sourceSize: win.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            // Only the very first one appears without the soak.
            Component.onCompleted: if (Wallpapers.current)
                source = "file://" + Wallpapers.current
            onStatusChanged: {
                // The next one has landed here: it can go.
                if (status === Image.Ready && next.source.toString() === source.toString()) {
                    next.source = "";
                    soak.progress = 0;
                }
            }
        }

        Image {
            id: next

            anchors.fill: parent
            sourceSize: win.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            visible: source.toString() !== ""
            layer.enabled: visible && soak.progress < 1
            layer.effect: ShaderEffect {
                property real progress: soak.progress
                property point origin: Qt.point(0.5, 0.5)
                property size size: Qt.size(next.width, next.height)

                fragmentShader: Qt.resolvedUrl("../../shaders/soak.frag.qsb")
            }
            onStatusChanged: {
                if (status === Image.Ready && source.toString() !== shown.source.toString())
                    soak.restart();
                else if (status === Image.Error)
                    source = "";
            }
        }

        NumberAnimation {
            id: soak

            property real progress: 0

            target: soak
            property: "progress"
            from: 0
            to: 1
            duration: Tokens.dur(1600)
            easing.type: Easing.InOutQuad
            onFinished: shown.source = next.source
        }

        Connections {
            target: Wallpapers

            function onCurrentChanged(): void {
                const url = Wallpapers.current ? "file://" + Wallpapers.current : "";
                if (!shown.source.toString()) {
                    // Nothing yet (the state was still loading): no soak.
                    shown.source = url;
                    return;
                }
                if (url === shown.source.toString() || url === next.source.toString())
                    return;
                // One mid-soak: it's set at once, and this one soaks over it.
                if (soak.running) {
                    soak.stop();
                    shown.source = next.source;
                }
                next.source = url;
            }
        }
    }
}
