pragma ComponentBehavior: Bound

import QtQuick
import Nafeel
import qs.config
import qs.components

// A capsule of bar controls in one colour pair. An active pill (in the
// group's inverse colours, a goo blob) springs to whichever control is
// active: hovered, or showing its popout. Controls take their ink from the group.
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

    // The active pill: a goo blob (the frame's engine) that springs to the
    // active control, stretching along its travel and settling with a little
    // squash. Moving on, it splits: a tail stays behind and shrinks away while
    // the pill leaves, the two joined by a neck that thins and snaps.
    Item {
        anchors.fill: parent
        opacity: root.activeControl ? 1 : 0

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        BlobGroup {
            id: pillInk

            color: root.pillFill
            smoothing: 8
        }

        // The tail left behind where the pill was.
        BlobRect {
            id: tail

            group: pillInk
            x: pill.x + (pill.width - width) / 2
            width: 0
            height: 0
            radius: Math.min(width / 2, Tokens.rounding.small)
            deformScale: 0

            function leave(fromY: real, fromHeight: real): void {
                shrink.stop();
                y = fromY;
                height = fromHeight;
                width = pill.width;
                shrink.start();
            }

            ParallelAnimation {
                id: shrink

                NumberAnimation {
                    target: tail
                    property: "width"
                    to: 0
                    duration: Tokens.anim.normal
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
                NumberAnimation {
                    target: tail
                    property: "height"
                    to: 0
                    duration: Tokens.anim.normal
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
                NumberAnimation {
                    target: tail
                    property: "y"
                    to: tail.y + tail.height / 2
                    duration: Tokens.anim.normal
                    easing.bezierCurve: Tokens.anim.emphasizedAccel
                    easing.type: Easing.BezierSpline
                }
            }
        }

        BlobRect {
            id: pill

            property real targetY: root.activeControl ? root.activeControl.y + column.y : root.height
            property real targetHeight: root.activeControl?.height ?? 0

            // Moving from one control to another: leave a tail behind.
            onTargetYChanged: {
                if (root.activeControl && height > 1 && Tokens.goo.enabled && Math.abs(targetY - y) > 2)
                    tail.leave(y, height);
            }

            group: pillInk
            x: root.padding
            width: root.width - root.padding * 2
            y: targetY
            height: targetHeight
            radius: Math.min(width / 2, Tokens.rounding.small)
            stiffness: Tokens.goo.stiffness
            damping: Tokens.goo.damping
            deformScale: Tokens.goo.enabled ? Tokens.goo.scale * 2.2 : 0
            maxStretch: 0.3

            Behavior on y {
                enabled: root.activeControl !== null
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
