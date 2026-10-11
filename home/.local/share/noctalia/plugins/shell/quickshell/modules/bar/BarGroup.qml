pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// A capsule of bar controls in one colour pair. An active pill (in the
// group's inverse colours) springs to whichever control is active: hovered,
// or showing its popout. Controls take their ink from the group.
Item {
    id: root

    property color fill
    property color ink
    property color pillFill
    property color pillInk
    property real padding: 4
    property real radius: Tokens.rounding.normal

    default property alias controls: column.data

    // The active control: a hovered one wins over one whose popout is open.
    readonly property Item activeControl: {
        const items = column.children;
        let open = null;
        for (let i = 0; i < items.length; i++) {
            const c = items[i];
            if (!c.visible || c.active === undefined)
                continue;
            if (c.hovered)
                return c;
            if (c.active)
                open = c;
        }
        return open;
    }

    implicitWidth: Tokens.barWidth - Tokens.spacing.large
    implicitHeight: column.implicitHeight + padding * 2
    // No self-hiding from its children's visibility: an item counts as
    // invisible while its parent is hidden, so a group that hid itself while
    // the bar was hidden (fullscreen, lock) would never come back. Hide a
    // group explicitly where it can really be empty.

    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: root.fill
    }

    StyledRect {
        id: pill

        property real targetY: root.activeControl ? root.activeControl.y + column.y : height
        property real targetHeight: root.activeControl?.height ?? 0

        x: root.padding
        width: root.width - root.padding * 2
        y: targetY
        height: targetHeight
        radius: Math.min(width / 2, Tokens.rounding.small)
        color: root.pillFill
        opacity: root.activeControl ? 1 : 0

        Behavior on y {
            enabled: pill.opacity > 0
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on height {
            SpringAnimation {
                spring: Tokens.springK(4)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }
    }

    Column {
        id: column

        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: 2

        // Controls take the group's ink (and the pill's while active).
        onChildrenChanged: {
            for (const c of children) {
                if ("groupInk" in c) {
                    c.groupInk = Qt.binding(() => root.ink);
                    c.groupActiveInk = Qt.binding(() => root.pillInk);
                }
            }
        }
    }
}
