pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The left edge of the frame, top to bottom:
//   [ workspaces ]                       primary          (extensions: bar.top)
//   [ notifications · clipboard · capture ]  secondary container
//   … bar.middle extensions …
//   [ tray ]                             surface container
//   [ sound · connections · battery ]    primary (each opens the bottom-left
//                                        corner: sound has brightness and now
//                                        playing, connections Wi-Fi and Bluetooth)
//   ( power )
// and the clock in the vertical middle.                            error container
// Every control previews its popout on hover; see BarControl.
Item {
    id: root

    property ShellScreen shellScreen

    Column {
        anchors.top: parent.top
        // The same inset as the sides, so the bar's ends match its edges.
        anchors.topMargin: (Tokens.barWidth - (Tokens.barWidth - Tokens.spacing.large)) / 2
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.normal

        BarGroup {
            fill: Colours.palette.m3surfaceContainerHigh
            ink: Colours.palette.m3onSurface
            padding: 4

            ExtensionSlot {
                width: parent.width
                spacing: Tokens.spacing.small
                slot: "bar.top"
                shellScreen: root.shellScreen
            }
        }

        BarGroup {
            fill: Colours.palette.m3secondaryContainer
            ink: Colours.palette.m3onSecondaryContainer
            // The pill in the group's inverse (as the sound group's), so it
            // stands out on the capsule.
            pillFill: Colours.palette.m3onSecondaryContainer
            pillInk: Colours.palette.m3secondaryContainer

            BarControl {
                shellScreen: root.shellScreen
                popout: "notifications"
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                dot: Notifs.unread > 0
                onRightClicked: Notifs.toggleDnd()
            }

            BarControl {
                shellScreen: root.shellScreen
                popout: "clipboard"
                icon: "content_paste"
            }

            BarControl {
                id: capture

                shellScreen: root.shellScreen
                popout: "capture"
                icon: Capture.recording ? "" : "photo_camera"
                onRightClicked: Capture.recording ? Capture.request("stop") : Capture.request("screenshot", "region")
                onMiddleClicked: Capture.recording ? Capture.request("pause") : Capture.request("set", "kind record")

                // Recording: a red dot and the time recorded.
                Column {
                    visible: Capture.recording
                    spacing: 2

                    StyledRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Capture.paused ? Colours.palette.m3outline : Colours.palette.m3error
                    }

                    StyledText {
                        id: recorded

                        anchors.horizontalCenter: parent.horizontalCenter
                        color: capture.ink
                        font.pixelSize: 10
                        font.weight: Font.Bold

                        Timer {
                            running: Capture.recording
                            repeat: true
                            interval: 1000
                            triggeredOnStart: true
                            onTriggered: {
                                const s = Math.floor(Capture.elapsed(Date.now()));
                                recorded.text = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
                            }
                        }
                    }
                }
            }
        }

        ExtensionSlot {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.normal
            slot: "bar.middle"
            shellScreen: root.shellScreen
        }
    }

    Clock {
        anchors.centerIn: parent
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (Tokens.barWidth - (Tokens.barWidth - Tokens.spacing.large)) / 2
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tokens.spacing.normal

        ExtensionSlot {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.normal
            slot: "bar.bottom"
            shellScreen: root.shellScreen
        }

        BarGroup {
            visible: tray.children.length > 1
            fill: Colours.palette.m3surfaceContainerHigh
            ink: Colours.palette.m3onSurface
            padding: 6

            Tray {
                id: tray

                width: parent.width
                shellScreen: root.shellScreen
            }
        }

        // Sound (with brightness and now playing), connections (Wi-Fi and
        // Bluetooth) and battery; each opens the bottom-left corner.
        BarGroup {
            fill: Colours.palette.m3primary
            ink: Colours.palette.m3onPrimary
            pillFill: Colours.palette.m3onPrimary
            pillInk: Colours.palette.m3primary

            BarControl {
                id: sound

                shellScreen: root.shellScreen
                popout: "sound"
                // The album art while something plays, else the speaker.
                icon: Media.playing && Media.art ? "" : Audio.muted ? "volume_off" : Audio.volume === 0 ? "volume_mute" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
                alert: Audio.muted ? Colours.palette.m3error : "transparent"
                onRightClicked: Audio.toggleMute()
                onMiddleClicked: Media.togglePlaying()
                onScrolled: up => Audio.setVolume(Audio.volume + (up ? 0.05 : -0.05))

                ClippingRectangle {
                    visible: Media.playing && Media.art !== ""
                    width: 24
                    height: 24
                    radius: Tokens.rounding.small
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: Media.art
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            BarControl {
                shellScreen: root.shellScreen
                popout: "connect"
                icon: Network.icon
                // A dot while a Bluetooth device is connected.
                dot: BluetoothState.connected.length > 0
                onRightClicked: Network.toggleWifi()
            }

            BarControl {
                id: battery

                shellScreen: root.shellScreen
                visible: Power.hasBattery
                popout: "battery"
                alert: Power.low ? Colours.palette.m3error : "transparent"

                BatteryIcon {
                    ink: battery.ink
                    hole: battery.active ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                }
            }
        }

        BarGroup {
            fill: Colours.palette.m3errorContainer
            ink: Colours.palette.m3onErrorContainer
            pillFill: Colours.palette.m3error
            pillInk: Colours.palette.m3onError
            radius: Tokens.rounding.small
            padding: 3

            BarControl {
                shellScreen: root.shellScreen
                popout: "session"
                icon: "power_settings_new"
            }
        }
    }
}
