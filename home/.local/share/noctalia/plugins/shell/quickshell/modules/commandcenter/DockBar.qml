pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The dock: its apps split evenly either side of the command center's icon,
// pinned ones first, then other running ones. Resting on an
// app lists its windows (DockItem); resting on the middle icon opens the
// command center, a click opens or closes it. Nothing else on the dock
// opens anything by hover.
Row {
    id: root

    property bool expanded: false // the command center is open above it
    property string screenName: ""
    readonly property var items: Dock.items
    readonly property int half: Math.ceil(items.length / 2)

    spacing: Tokens.spacing.small

    Repeater {
        model: root.items.slice(0, root.half)

        DockItem {
            expanded: root.expanded
        }
    }

    // The command center's icon.
    Item {
        id: centre

        width: 52
        height: 60

        IconButton {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            size: 44
            icon: root.expanded ? "keyboard_arrow_down" : "apps"
            filled: true
            fillColour: root.expanded ? Colours.palette.m3primary : Colours.palette.m3primaryContainer
            inkColour: root.expanded ? Colours.palette.m3onPrimary : Colours.palette.m3onPrimaryContainer
            onClicked: {
                rest.stop();
                if (root.expanded)
                    ShellState.close();
                else
                    ShellState.pin("command", root.screenName);
            }
        }

        HoverHandler {
            id: centreHover

            cursorShape: Qt.PointingHandCursor
        }

        Timer {
            id: rest

            running: centreHover.hovered && !root.expanded
            interval: Dock.settings.v["dock.centerDelay"]
            onTriggered: ShellState.preview("command", root.screenName)
        }
    }

    Repeater {
        model: root.items.slice(root.half)

        DockItem {
            expanded: root.expanded
        }
    }
}
