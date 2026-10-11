pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// This screen's umbriel workspaces as Chinese numerals (一 二 三 …): the
// active one on a gold plate that springs between them, occupied ones in full
// ink, empty ones faint. Click to switch, scroll to step through them, and
// rest on it (or click empty space) for the workspace previews in the
// top-left corner.
Item {
    id: root

    property ShellScreen shellScreen
    readonly property string output: shellScreen?.name ?? ""
    readonly property var spaces: Umbriel.workspacesOn(output)
    readonly property int activeIndex: spaces.findIndex(w => w.active)
    readonly property int cell: 30
    readonly property string key: "bar:workspaces"

    readonly property int gap: 2

    width: parent?.width ?? 28
    implicitWidth: 28
    implicitHeight: spaces.length * cell + Math.max(0, spaces.length - 1) * gap

    Timer {
        id: hoverDelay

        interval: 260
        onTriggered: ShellState.preview(root.key, root.output)
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                ShellState.barHover = root.key;
                hoverDelay.restart();
            } else {
                if (ShellState.barHover === root.key)
                    ShellState.barHover = "";
                hoverDelay.stop();
                ShellState.unpreviewLater(root.key);
            }
        }
        onPointChanged: {
            if (hovered)
                ShellState.keep(root.key);
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Umbriel.dispatch(event.angleDelta.y > 0 ? "workspace-previous" : "workspace-next")
    }

    // The gold plate under the active numeral.
    StyledRect {
        id: plate

        y: Math.max(0, root.activeIndex) * (root.cell + root.gap)
        width: root.width
        height: root.cell
        radius: Tokens.rounding.small
        color: Colours.palette.m3primary
        opacity: root.activeIndex >= 0 ? 1 : 0

        Behavior on y {
            SpringAnimation {
                spring: Tokens.spring.bouncy.spring
                damping: Tokens.spring.spatial.damping
                epsilon: 0.25
            }
        }
    }

    Column {
        width: root.width
        spacing: root.gap

        Repeater {
            model: root.spaces

            Item {
                id: ws

                required property var modelData

                width: root.width
                height: root.cell

                StyledText {
                    anchors.centerIn: parent
                    text: Xian.numeral(ws.modelData.index)
                    color: ws.modelData.active ? Colours.palette.m3onPrimary : ws.modelData.occupied ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    opacity: ws.modelData.active || ws.modelData.occupied ? 1 : 0.55
                    font.family: Tokens.font.cjk
                    font.pixelSize: 16
                    font.weight: ws.modelData.active ? Font.Bold : Font.Medium
                    scale: tap.pressed ? 0.85 : hover.hovered && !ws.modelData.active ? 1.15 : 1

                    Behavior on scale {
                        SpringAnimation {
                            spring: Tokens.spring.bouncy.spring
                            damping: Tokens.spring.bouncy.damping
                            epsilon: 0.002
                        }
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: tap

                    onTapped: Umbriel.dispatch(`workspace-switch:${ws.modelData.name}/${root.output}`)
                }
            }
        }
    }
}
