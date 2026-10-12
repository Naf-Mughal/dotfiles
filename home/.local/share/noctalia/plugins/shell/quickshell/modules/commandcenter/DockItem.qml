pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// A dock app: its icon, a dot per window (a wide one while it has focus).
// Click focuses it (again cycles its windows) or starts it, middle-click
// starts another, right-click pins/unpins. Resting on a running one lists
// its windows to jump to.
Item {
    id: root

    required property var modelData
    property bool expanded
    // The drawer it sits in, for keeping a hover-shown dock open.
    readonly property string drawerKey: expanded ? "command" : "dock"

    readonly property bool running: modelData.windows.length > 0
    readonly property bool focused: modelData.windows.some(w => w.focused)
    readonly property var entry: Apps.forAppId(modelData.appId)

    width: 52
    height: 60

    // Hovered: a soft sheet behind the icon (the shell's Surface), no
    // scaling.
    Surface {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 2
        width: 48
        height: 48
        role: "paper"
        emphasis: hover.hovered || root.listShown ? "soft" : "ghost"
        level: 4
    }

    IconImage {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        implicitSize: 40
        source: Apps.icon(root.modelData.appId)
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

    // Its windows, in a popup over the icon (its own surface, so it takes
    // clicks above the dock): after resting on a running app for the Dock
    // page's delay; it stays while the pointer is on the icon or the list,
    // and a moment longer so the gap between them can be crossed.
    readonly property bool wantList: running && (hover.hovered || listHover.hovered)
    property bool listShown: false

    onWantListChanged: {
        if (wantList) {
            hideTimer.stop();
            showTimer.restart();
        } else {
            showTimer.stop();
            hideTimer.restart();
        }
    }

    Timer {
        id: showTimer

        interval: Dock.settings.v["dock.windowsDelay"]
        onTriggered: root.listShown = true
    }

    Timer {
        id: hideTimer

        interval: 220
        onTriggered: root.listShown = false
    }

    PopupWindow {
        id: popup

        anchor.item: icon
        anchor.rect.x: icon.width / 2
        anchor.rect.y: -Tokens.spacing.normal
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        visible: root.listShown && root.running
        color: "transparent"
        implicitWidth: 300
        implicitHeight: list.implicitHeight + Tokens.spacing.small * 2

        Surface {
            anchors.fill: parent
            role: "paper"
            level: 2
            shape: "large"
            outlined: true

            // The dock (or the command center) shown by hovering stays while
            // the pointer is on its popup, and closes as usual after.
            HoverHandler {
                id: listHover

                onHoveredChanged: {
                    if (hovered)
                        ShellState.keep(root.drawerKey);
                    else
                        ShellState.unpreviewLater(root.drawerKey);
                }
            }

            Column {
                id: list

                x: Tokens.spacing.small
                y: Tokens.spacing.small
                width: parent.width - Tokens.spacing.small * 2
                spacing: 2

                MicroLabel {
                    text: root.entry?.name ?? root.modelData.appId
                    leftPadding: Tokens.spacing.small
                    topPadding: Tokens.spacing.tiny
                    bottomPadding: Tokens.spacing.tiny
                }

                Repeater {
                    model: root.modelData.windows

                    ListRow {
                        required property var modelData

                        width: list.width
                        implicitHeight: 44
                        icon: modelData.focused ? "radio_button_checked" : "web_asset"
                        iconFill: modelData.focused ? 1 : 0
                        title: modelData.title || (root.entry?.name ?? root.modelData.appId)
                        subtitle: `Workspace ${Umbriel.workspaces.find(w => w.id === modelData.workspace)?.name ?? ""}`
                        highlighted: modelData.focused
                        onClicked: {
                            Umbriel.dispatch("window-focus:" + modelData.id);
                            root.listShown = false;
                        }
                    }
                }
            }
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
