pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The dock: pinned apps, then other running ones. Icons near the pointer
// magnify (up to 1.4x, a smooth fisheye falloff) and their neighbours make
// room, so the dock's base widens with them.
Row {
    id: root

    property bool expanded: false // the command center is open above it
    // The pointer's x over the dock, or NaN when it's elsewhere.
    readonly property real pointerX: hover.hovered ? hover.point.position.x : NaN

    // How much an icon centred at `cx` magnifies.
    function magnify(cx: real): real {
        if (isNaN(pointerX) || Tokens.reduceMotion)
            return 1;
        const t = Math.max(0, 1 - Math.abs(cx - pointerX) / 110);
        return 1 + 0.4 * t * t * (3 - 2 * t);
    }

    spacing: Tokens.spacing.small

    HoverHandler {
        id: hover
    }

    Repeater {
        model: Dock.items

        DockItem {
            id: item

            expanded: root.expanded
            // From its resting centre, so magnifying doesn't chase itself.
            magnify: root.magnify(index * (52 + root.spacing) + 26)

            required property int index
        }
    }
}
