pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// A dock app: its icon, and beside it a dash per open window (the focused
// one longer, in the accent).
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
    height: 64

    // Its icon: a tile in the theme's colours (AppIcon), stronger while
    // hovered; no scaling.
    // Every icon the same box, centred in the dock's height.
    AppIcon {
        id: icon

        anchors.centerIn: parent
        size: Dock.settings.v["dock.iconSize"]
        appId: root.modelData.appId
        hovered: hover.hovered || root.previewing
    }

    // Running: a dash per open window (up to four) stacked beside the
    // icon's left edge, centred on it; the focused window's is longer and in
    // the accent. Nothing sits under the icons, so the row stays even.
    Column {
        anchors.right: icon.left
        anchors.rightMargin: 3
        anchors.verticalCenter: icon.verticalCenter
        spacing: 3
        width: 8

        Repeater {
            model: Math.min(4, root.modelData.windows.length)

            StyledRect {
                required property int index
                readonly property bool current: root.modelData.windows[index]?.focused ?? false

                // Right-aligned in the column (its width is the longest dash).
                x: 8 - width
                width: current ? 8 : 5
                height: 3
                radius: 1.5
                color: current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

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

    // A command center opened by hovering the middle symbol folds back into
    // the dock for it; one opened by a click stays.
    readonly property bool hoverOpened: root.expanded && ShellState.pinned === "" && ShellState.previewed === "command"

    Timer {
        running: hover.hovered && (!root.expanded || root.hoverOpened)
        interval: Dock.settings.v["dock.windowsDelay"]
        onTriggered: {
            if (root.hoverOpened)
                ShellState.preview("dock", root.screenName);
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
