pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// A dock app: its icon, a dot per window (a wide one while it has focus).
// Click focuses it (again cycles its windows) or starts it, middle-click
// starts another, right-click pins/unpins. Resting on it, with the command
// center open, lists its windows to jump to.
Item {
    id: root

    required property var modelData
    property bool expanded
    property real magnify: 1

    readonly property bool running: modelData.windows.length > 0
    readonly property bool focused: modelData.windows.some(w => w.focused)
    readonly property var entry: Apps.forAppId(modelData.appId)

    width: 52 + 26 * (magnify - 1) / 0.4 * 0.6
    height: 60

    Behavior on magnify {
        SpringAnimation {
            spring: Tokens.spring.bouncy.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }

    IconImage {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        implicitSize: 40
        source: Apps.icon(root.modelData.appId)
        scale: tap.pressed ? root.magnify * 0.88 : root.magnify
        transformOrigin: Item.Bottom

        Behavior on scale {
            Anim {
                duration: Tokens.anim.fast
                easing.bezierCurve: Tokens.anim.expressiveFastSpatial
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        spacing: 3

        Repeater {
            model: Math.min(3, root.modelData.windows.length)

            StyledRect {
                width: root.focused ? 14 : 5
                height: 5
                radius: 3
                color: root.focused ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                Behavior on width {
                    Anim {
                        duration: Tokens.anim.fast
                    }
                }
            }
        }
    }

    // Its windows, above the icon.
    Surface {
        id: windows

        visible: opacity > 0
        opacity: root.expanded && root.running && showTimer.shown ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.spacing.small
        width: 280
        height: list.implicitHeight + Tokens.spacing.small * 2
        level: 4
        z: 10

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        Column {
            id: list

            x: Tokens.spacing.small
            y: Tokens.spacing.small
            width: parent.width - Tokens.spacing.small * 2

            StyledText {
                text: root.entry?.name ?? root.modelData.appId
                color: Colours.palette.m3primary
                font.pixelSize: 12
                font.weight: Font.DemiBold
                leftPadding: Tokens.spacing.small
                bottomPadding: 2
            }

            Repeater {
                model: root.modelData.windows

                StyledRect {
                    id: win

                    required property var modelData

                    width: list.width
                    height: 32
                    radius: Tokens.rounding.small
                    color: winHover.hovered ? Colours.palette.m3secondaryContainer : "transparent"

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Tokens.spacing.small
                        width: parent.width - Tokens.spacing.small * 2
                        text: win.modelData.title
                        color: win.modelData.focused ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    HoverHandler {
                        id: winHover
                    }

                    TapHandler {
                        onTapped: Umbriel.dispatch("window-focus:" + win.modelData.id)
                    }
                }
            }
        }

        HoverHandler {
            id: listHover
        }
    }

    Timer {
        id: showTimer

        property bool shown: false

        interval: 350
        running: hover.hovered || listHover.hovered
        onTriggered: shown = true
        onRunningChanged: {
            if (!running)
                shown = false;
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (point, button) => {
            if (button === Qt.RightButton)
                Dock.togglePin(root.modelData.appId);
            else if (button === Qt.MiddleButton)
                root.entry?.execute();
            else
                Dock.activate(root.modelData);
        }
    }
}
