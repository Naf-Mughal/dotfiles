pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// Capture, baked into the shell (the capture plugin's Snipping-Tool dialog):
// Screenshot or Record, the area, a delay or the audio, and the big button.
// A screenshot keeps the popout when it's pinned (clicked open), so it can be
// in the picture; a hover preview, or a recording, closes it first. While
// recording: the time, Stop, Pause and live mic mute. It drives the capture
// service over its IPC; the choices persist in its prefs.json.
Column {
    id: root

    readonly property var p: Capture.prefs
    readonly property bool shot: p.kind !== "record"

    function take(): void {
        if (root.shot && ShellState.pinned === "bar:capture") {
            Capture.go(80);
            return;
        }
        ShellState.close();
        Capture.go(Tokens.dur(260) + 120);
    }

    spacing: Tokens.spacing.normal

    // ── Recording ──────────────────────────────────────────────────────────
    Column {
        visible: Capture.recording
        width: parent.width
        spacing: Tokens.spacing.normal

        PopoutHeader {
            width: parent.width
            icon: "radio_button_checked"
            title: Capture.paused ? "Paused" : "Recording"
            gloss: Xian.gloss.capture
            subtitle: (Capture.state.mode ?? "") === "screen" ? "Whole screen" : "Region"
        }

        StyledRect {
            width: parent.width
            height: 96
            radius: Tokens.rounding.large
            color: Capture.paused ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3errorContainer

            StyledText {
                id: timer

                anchors.centerIn: parent
                color: Capture.paused ? Colours.palette.m3onSurface : Colours.palette.m3onErrorContainer
                font.family: Tokens.font.serif
                font.pixelSize: 44
                font.weight: Font.DemiBold

                Timer {
                    running: Capture.recording
                    repeat: true
                    interval: 500
                    triggeredOnStart: true
                    onTriggered: {
                        const s = Math.floor(Capture.elapsed(Date.now()));
                        timer.text = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Tokens.spacing.small

            Tile {
                width: (parent.width - Tokens.spacing.small) / 2
                icon: Capture.paused ? "play_arrow" : "pause"
                label: Capture.paused ? "Resume" : "Pause"
                onClicked: Capture.request("pause")
            }

            Tile {
                width: (parent.width - Tokens.spacing.small) / 2
                icon: Capture.state.micMuted ? "mic_off" : "mic"
                label: "Microphone"
                sublabel: !root.p.mic ? "Not recorded" : Capture.state.micMuted ? "Muted" : "Live"
                checked: root.p.mic && !Capture.state.micMuted
                enabled: root.p.mic
                opacity: root.p.mic ? 1 : 0.5
                onClicked: Capture.request("mic")
            }
        }

        BigAction {
            icon: "stop"
            label: "Stop recording"
            fill: Colours.palette.m3error
            ink: Colours.palette.m3onError
            onClicked: Capture.request("stop")
        }
    }

    // ── Idle ───────────────────────────────────────────────────────────────
    Column {
        visible: !Capture.recording
        width: parent.width
        spacing: Tokens.spacing.normal

        PopoutHeader {
            width: parent.width
            icon: root.shot ? "photo_camera" : "videocam"
            title: "Capture"
            gloss: Xian.gloss.capture
            subtitle: root.shot ? "Screenshot" : "Screen recording"
        }

        ButtonGroup {
            width: parent.width
            current: root.p.kind
            model: [
                {
                    value: "screenshot",
                    icon: "photo_camera",
                    label: "Screenshot"
                },
                {
                    value: "record",
                    icon: "videocam",
                    label: "Record"
                }
            ]
            onSelected: v => Capture.setPref("kind", v)
        }

        MicroLabel {
            text: "Area"
            topPadding: 4
        }

        Row {
            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: root.shot ? [
                    {
                        value: "region",
                        icon: "crop",
                        label: "Region"
                    },
                    {
                        value: "screen",
                        icon: "desktop_windows",
                        label: "Screen"
                    },
                    {
                        value: "edit",
                        icon: "draw",
                        label: "Annotate"
                    }
                ] : [
                    {
                        value: "region",
                        icon: "crop",
                        label: "Region"
                    },
                    {
                        value: "screen",
                        icon: "desktop_windows",
                        label: "Screen"
                    }
                ]

                Tile {
                    required property var modelData
                    readonly property string current: root.shot ? root.p.shot : root.p.area

                    width: (root.width - Tokens.spacing.small * (root.shot ? 2 : 1)) / (root.shot ? 3 : 2)
                    icon: modelData.icon
                    label: modelData.label
                    stacked: root.shot
                    checked: current === modelData.value
                    onClicked: Capture.setPref(root.shot ? "shot" : "area", modelData.value)
                }
            }
        }

        // Screenshot: the delay.
        Column {
            visible: root.shot
            width: parent.width
            spacing: Tokens.spacing.small

            MicroLabel {
                text: "Delay"
                topPadding: 4
            }

            ButtonGroup {
                width: parent.width
                current: root.p.delay
                model: [0, 3, 5, 10].map(d => ({
                            value: d,
                            icon: d === 0 ? "bolt" : "timer",
                            label: d === 0 ? "Now" : `${d} s`
                        }))
                onSelected: v => Capture.setPref("delay", v)
            }
        }

        // Record: the audio.
        Column {
            visible: !root.shot
            width: parent.width
            spacing: Tokens.spacing.small

            MicroLabel {
                text: "Audio"
                topPadding: 4
            }

            ListRow {
                width: parent.width
                icon: root.p.mic ? "mic" : "mic_off"
                title: "Microphone"
                subtitle: root.p.mic ? "Recorded, mutable while recording" : "Off"
                onClicked: Capture.setPref("mic", !root.p.mic)

                StyledSwitch {
                    checked: root.p.mic
                    onToggled: Capture.setPref("mic", !root.p.mic)
                }
            }

            ListRow {
                width: parent.width
                icon: root.p.system ? "volume_up" : "volume_off"
                title: "System audio"
                subtitle: root.p.system ? "Recorded" : "Off"
                onClicked: Capture.setPref("system", !root.p.system)

                StyledSwitch {
                    checked: root.p.system
                    onToggled: Capture.setPref("system", !root.p.system)
                }
            }
        }

        BigAction {
            icon: root.shot ? "photo_camera" : "radio_button_checked"
            label: root.shot ? (root.p.delay > 0 ? `Take screenshot in ${root.p.delay} s` : "Take screenshot") : "Start recording"
            fill: root.shot ? Colours.palette.m3primary : Colours.palette.m3error
            ink: root.shot ? Colours.palette.m3onPrimary : Colours.palette.m3onError
            onClicked: root.take()
        }

        MicroLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Mod+Shift+S snip · Mod+Shift+R record"
        }
    }

    // The big filled action button, morphing on press.
    component BigAction: StyledRect {
        id: big

        property string icon
        property string label
        property color fill
        property color ink

        signal clicked

        width: root.width
        height: 52
        radius: bigTap.pressed ? Tokens.rounding.small : Tokens.rounding.morph
        color: fill

        Behavior on radius {
            Anim {
                duration: Tokens.anim.fast
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }
        Behavior on scale {
            SpringAnimation {
                spring: Tokens.spring.bouncy.spring
                damping: Tokens.spring.bouncy.damping
                epsilon: 0.002
            }
        }

        StateLayer {
            hovered: bigHover.hovered
            pressed: bigTap.pressed
            ink: big.ink
        }

        PressBounce {
            pressed: bigTap.pressed
            depth: 0.97
        }

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: big.icon
                fill: 1
                color: big.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: big.label
                color: big.ink
                font.pixelSize: Tokens.font.row
                font.weight: Font.DemiBold
            }
        }

        HoverHandler {
            id: bigHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: bigTap

            onTapped: big.clicked()
        }
    }
}
