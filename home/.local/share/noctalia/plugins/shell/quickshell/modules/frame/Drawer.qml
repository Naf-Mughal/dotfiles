pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// A drawer, drawn as part of the frame's shape (FrameWindow draws each one as
// a BlobRect merged into the frame's BlobGroup). The frame is four bars and four corners, and a drawer
// anchors to either:
//   a bar     (edge "left" | "top" | "right" | "bottom") slides out of it at
//             `along` (0..1)
//   a corner  (edge "corner", `corner` "topLeft" | "topRight" | "bottomLeft" |
//             "bottomRight") grows out of the corner point in both directions
//             at once, merged into both bars it touches (`thickness` is the
//             vertical bar's, `thicknessY` the horizontal one's), so the
//             session corner reads as part of the left bar
// Fill it with content as children; they're laid out at the open size and
// come out with the drawer (from the corner, for a corner).
//
// It opens by hover (ShellState.preview) from its own hot zone (the bar strip
// under it, or a square in its corner) when `hoverZone` is set, or from any
// trigger that calls ShellState.preview(name, screen); a press inside pins it.
Item {
    id: root

    required property string name
    required property string edge // "bottom" | "top" | "left" | "right" | "corner"
    // Frame thickness on that edge (the bar's width for "left"); for a corner,
    // the vertical bar's.
    required property real thickness
    // For a corner: which one, and the horizontal bar's thickness.
    property string corner: "bottomRight"
    property real thicknessY: thickness
    required property ShellScreen shellScreen

    // Size when open, and where its centre sits along the edge (0..1).
    property int panelWidth: 400
    property int panelHeight: 300
    property real along: 0.5
    property bool hoverZone: true
    property bool wantsKeyboard: false
    // The ShellState name hovering or pressing inside keeps open; a drawer
    // shared by several triggers (the bar popout) points it at the current one.
    property string key: name
    // Whether a press inside pins it.
    property bool pinOnPress: true
    // The hover strip's length while closed (0 = the drawer's own span); for
    // a corner, the side of its hot square.

    property real zoneLength: 0
    // Off for drawers that open by themselves (toasts): no hover/pin through
    // ShellState.
    property bool managed: true

    default property alias content: body.data

    readonly property string screenName: shellScreen?.name ?? ""
    property bool open: enabled && ShellState.isOpen(name, screenName)
    readonly property bool pinned: open && ShellState.pinned === key
    readonly property bool isCorner: edge === "corner"
    readonly property bool cornerRight: corner.endsWith("Right")
    readonly property bool cornerBottom: corner.startsWith("bottom")
    readonly property bool vertical: edge === "bottom" || edge === "top"
    readonly property real depth: vertical ? panelHeight : panelWidth
    property real prog: open ? 1 : 0
    // A corner springs in two directions: its width and height each have a
    // spring (width a touch brisker), so it blooms out of the corner and
    // bounces on both axes instead of growing as one.
    property real progX: open ? 1 : 0
    property real progY: open ? 1 : 0
    readonly property real shown: depth * Math.max(0, prog)
    readonly property bool active: prog > 0.002 || (isCorner && (progX > 0.002 || progY > 0.002))

    // Input/hover area: the border strip plus the part that's out.
    readonly property rect region: Qt.rect(shape.x, shape.y, shape.width, shape.height)
    // The blob that draws this drawer (FrameWindow's BlobRect for it sets
    // itself here) and its squash-and-stretch: Ryoku's BlobRect spring, in
    // C++, from the blob's own velocity. The content gets the same transform.
    property Item blob: null
    // How wet the ink is (0..1): fresh as the drawer starts to open (and as
    // it nears closed), dry once it has settled. The blob bleeds at the edge
    // and joins the frame with a fatter neck while wet (and adds its own
    // speed to this).
    readonly property real wet: active && Tokens.goo.enabled ? 1 - emerge : 0
    // How far out of its bar it is (0..1): the bar's edge first bulges (a
    // fully round swell), then squares up into the panel as it comes out.
    readonly property real emerge: Math.max(0, Math.min(1, isCorner ? progX : prog))
    // The content inks in once the paper is mostly out (and leaves first),
    // so nothing seems to slide out from under the bar.
    readonly property real inked: Math.max(0, Math.min(1, (emerge - 0.5) / 0.35))
    readonly property real g00: blob ? blob.rawDeformMatrix.m11 : 1
    readonly property real g01: blob ? blob.rawDeformMatrix.m12 : 0
    readonly property real g11: blob ? blob.rawDeformMatrix.m22 : 1
    // Which corners are round (top-left, top-right, bottom-right,
    // bottom-left): only those facing the desktop; the sides it grows out of
    // are square so they melt into the frame.
    readonly property vector4d radii: {
        // While it's still a swell of the bar, the desktop-facing corners are
        // as round as the shape allows (the blob clamps to half its size).
        const r = Tokens.rounding.large + Math.pow(1 - emerge, 1.5) * 600;
        if (isCorner)
            return Qt.vector4d(corner === "bottomRight" ? r : 0, corner === "bottomLeft" ? r : 0, corner === "topLeft" ? r : 0, corner === "topRight" ? r : 0);
        switch (edge) {
        case "left":
            return Qt.vector4d(0, r, r, 0);
        case "right":
            return Qt.vector4d(r, 0, 0, r);
        case "top":
            return Qt.vector4d(0, 0, r, r);
        default:
            return Qt.vector4d(r, r, 0, 0);
        }
    }

    anchors.fill: parent

    Behavior on prog {
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }
    // A corner extends out of its bar: opening, it first runs along the bar
    // (progY: the bar seems to swell) and then comes out of it (progX);
    // closing, it pulls back into the bar first and then shrinks along it,
    // melting back in. (Along the vertical bar is Y for every corner.)
    Behavior on progX {
        enabled: root.isCorner
        SpringAnimation {
            spring: Tokens.spring.spatial.spring * (root.open ? 0.85 : 1.6)
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }
    Behavior on progY {
        enabled: root.isCorner
        SpringAnimation {
            spring: Tokens.spring.spatial.spring * (root.open ? 1.6 : 0.85)
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }

    Item {
        id: shape

        // A bar drawer's length along its bar, and where it starts.
        readonly property real span: !root.active && root.zoneLength > 0 ? root.zoneLength : root.vertical ? root.panelWidth : root.panelHeight
        readonly property real start: {
            const total = root.vertical ? root.width : root.height;
            return Math.max(0, Math.min(total - span, total * root.along - span / 2));
        }
        // A corner drawer grows with progX/progY straight out of the bar and
        // border it's part of (no separate seed: it starts flush with them);
        // closed, it's its hot square.
        readonly property real cornerW: root.thickness + (root.active ? root.panelWidth * Math.max(0, root.progX) : root.zoneLength || 40)
        readonly property real cornerH: root.thicknessY + (root.active ? root.panelHeight * Math.max(0, root.progY) : root.zoneLength || 40)

        x: root.isCorner ? (root.cornerRight ? root.width - cornerW : 0) : root.vertical ? start : root.edge === "left" ? 0 : root.width - root.thickness - root.shown
        y: root.isCorner ? (root.cornerBottom ? root.height - cornerH : 0) : !root.vertical ? start : root.edge === "top" ? 0 : root.height - root.thickness - root.shown
        width: root.isCorner ? cornerW : root.vertical ? span : root.thickness + root.shown
        height: root.isCorner ? cornerH : root.vertical ? root.thickness + root.shown : span
        clip: true

        HoverHandler {
            enabled: root.managed && root.enabled && (root.hoverZone || root.active)
            onHoveredChanged: {
                if (hovered)
                    ShellState.preview(root.key, root.screenName);
                else
                    ShellState.unpreviewLater(root.key);
            }
            onPointChanged: {
                if (hovered && root.open)
                    ShellState.keep(root.key);
            }
        }

        // A press inside pins it (passive: children still get it). Not on the
        // bar or frame strip it grows out of: a click on a bar icon there
        // pins or unpins through the icon itself, and pinning here first made
        // that click toggle the panel closed.
        PointHandler {
            id: pressInside

            enabled: root.managed && root.open && root.pinOnPress
            onActiveChanged: {
                if (!active)
                    return;
                const p = point.pressPosition;
                const onStrip = root.isCorner ? (root.cornerRight ? p.x > shape.width - root.thickness : p.x < root.thickness) || (root.cornerBottom ? p.y > shape.height - root.thicknessY : p.y < root.thicknessY) : root.edge === "left" ? p.x < root.thickness : root.edge === "right" ? p.x > shape.width - root.thickness : root.edge === "top" ? p.y < root.thickness : p.y > shape.height - root.thickness;
                if (!onStrip)
                    ShellState.pin(root.key, root.screenName);
            }
        }

        Item {
            id: body

            // The goo, about the blob's centre.
            readonly property real gx: shape.width / 2 - x
            readonly property real gy: shape.height / 2 - y

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(root.g00, root.g01, 0, body.gx - root.g00 * body.gx - root.g01 * body.gy, root.g01, root.g11, 0, body.gy - root.g01 * body.gx - root.g11 * body.gy, 0, 0, 1, 0, 0, 0, 0, 1)
            }

            // Content comes out with the drawer: a bar drawer's slides out of
            // its bar, a corner drawer's hangs from the corner (inside both
            // bars), so it unfolds from there.
            x: {
                if (root.isCorner)
                    return root.cornerRight ? shape.width - root.thickness - root.panelWidth : root.thickness;
                return root.edge === "left" ? root.thickness + root.shown - root.panelWidth : 0;
            }
            y: {
                if (root.isCorner)
                    return root.cornerBottom ? shape.height - root.thicknessY - root.panelHeight : root.thicknessY;
                return root.edge === "top" ? root.thickness + root.shown - root.panelHeight : 0;
            }
            width: root.panelWidth
            height: root.panelHeight
            // The content follows the paper: it inks in (fading and settling
            // up from a touch smaller, from the anchor) once the paper is
            // mostly out of the bar, and leaves first.
            opacity: root.inked
            scale: 0.95 + 0.05 * root.inked
            visible: opacity > 0 && root.active
            transformOrigin: {
                if (root.isCorner)
                    return root.cornerBottom ? (root.cornerRight ? Item.BottomRight : Item.BottomLeft) : (root.cornerRight ? Item.TopRight : Item.TopLeft);
                switch (root.edge) {
                case "left":
                    return Item.Left;
                case "right":
                    return Item.Right;
                case "top":
                    return Item.Top;
                default:
                    return Item.Bottom;
                }
            }
        }
    }
}
