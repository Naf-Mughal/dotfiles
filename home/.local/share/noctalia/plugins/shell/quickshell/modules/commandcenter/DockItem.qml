pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// A dock app: its icon, a dot per window (a wide one while it has focus).
// Click focuses it (again cycles its windows) or starts it, middle-click
// starts another, right-click pins/unpins. Resting on a running one shows
// live previews of its windows above the dock.
Item {
    id: root

    required property var modelData
    property bool expanded
    property string screenName: ""

    readonly property bool running: modelData.windows.length > 0
    readonly property bool focused: modelData.windows.some(w => w.focused)
    readonly property var entry: Apps.forAppId(modelData.appId)

    width: 52
    height: 60

    // Its icon: a tile in the theme's colours (AppIcon), stronger while
    // hovered; no scaling.
    AppIcon {
        id: icon

        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        size: 44
        appId: root.modelData.appId
        hovered: hover.hovered || root.previewing
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

    // Resting on a running app previews its windows above the dock (part of
    // the dock's panel: CommandCenter / DockPreview), after the Dock page's
    // delay; resting on one without windows puts a preview away.
    readonly property bool previewing: ShellState.dockPreview === modelData.appId

    Timer {
        running: hover.hovered && !root.expanded
        interval: Dock.settings.v["dock.windowsDelay"]
        onTriggered: {
            ShellState.dockPreview = root.running ? root.modelData.appId : "";
            ShellState.dockPreviewScreen = root.screenName;
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
