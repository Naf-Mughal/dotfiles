pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// A drawer, drawn as part of the frame's shape (FrameWindow feeds `rect` to
// shaders/frame.frag). The frame is four bars and four corners, and a drawer
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
    // Drifting mist and spirit motes behind the content (fully immersive).
    property bool atmosphere: false

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
    // The shape for the frame shader: runs a corner radius past the screen
    // edge, so only the drawer's outer corners are round and its sides melt
    // into the frame.
    readonly property vector4d rect: {
        if (!active)
            return Qt.vector4d(0, 0, 0, 0);
        const r = Tokens.rounding.large;
        switch (edge) {
        case "corner":
            // Past both screen edges, so only the inner corner is round and
            // both sides merge into their bars.
            return Qt.vector4d(cornerRight ? shape.x : shape.x - r, cornerBottom ? shape.y : shape.y - r, shape.width + r, shape.height + r);
        case "top":
            return Qt.vector4d(shape.x, shape.y - r, shape.width, shape.height + r);
        case "left":
            return Qt.vector4d(shape.x - r, shape.y, shape.width + r, shape.height);
        case "right":
            return Qt.vector4d(shape.x, shape.y, shape.width + r, shape.height);
        default:
            return Qt.vector4d(shape.x, shape.y, shape.width, shape.height + r);
        }
    }

    // ── Goo ───────────────────────────────────────────────────────────────
    // A symmetric 2x2 deformation (g00 g01 / g01 g11) that stretches the
    // drawer along its direction of travel and squashes it across, solved as
    // an underdamped spring toward a target set by its velocity: Ryoku and
    // Caelestia's BlobRect, in QML. The frame shader deforms the shape by it
    // (`deform`) and the content gets the same transform.
    property real g00: 1
    property real g01: 0
    property real g11: 1
    property real v00: 0
    property real v01: 0
    property real v11: 0
    property real lastX: NaN
    property real lastY: NaN
    readonly property vector4d deform: Qt.vector4d(g00, g01, g11, 0)
    readonly property bool resting: Math.abs(g00 - 1) + Math.abs(g01) + Math.abs(g11 - 1) < 0.004 && Math.abs(v00) + Math.abs(v01) + Math.abs(v11) < 0.05

    function stepGoo(dt: real): void {
        const cx = shape.x + shape.width / 2, cy = shape.y + shape.height / 2;
        if (dt > 0.1 || dt <= 0 || isNaN(lastX)) {
            lastX = cx;
            lastY = cy;
            return;
        }
        const vx = (cx - lastX) / dt, vy = (cy - lastY) / dt;
        lastX = cx;
        lastY = cy;
        const speed = Math.hypot(vx, vy);
        let t00 = 1, t01 = 0, t11 = 1;
        if (isCorner) {
            // Each axis bulges with its own speed and nothing shears: a corner
            // bounces outward rather than tilting.
            t00 = 1 + Math.min(Math.abs(vx) * Tokens.goo.scale, Tokens.goo.maxStretch);
            t11 = 1 + Math.min(Math.abs(vy) * Tokens.goo.scale, Tokens.goo.maxStretch);
        } else if (speed > 5) {
            const stretch = 1 + Math.min(speed * Tokens.goo.scale, Tokens.goo.maxStretch);
            const squash = 1 / stretch, c = vx / speed, s = vy / speed;
            t00 = stretch * c * c + squash * s * s;
            t01 = (stretch - squash) * c * s;
            t11 = stretch * s * s + squash * c * c;
        }
        const k = Tokens.goo.stiffness, steps = Math.max(1, Math.ceil(dt / 0.008)), h = dt / steps;
        const friction = 1 / (1 + Tokens.goo.damping * h);
        let a = g00, b = g01, d = g11, va = v00, vb = v01, vd = v11;
        for (let i = 0; i < steps; i++) {
            va = (va - k * (a - t00) * h) * friction;
            a += va * h;
            vb = (vb - k * (b - t01) * h) * friction;
            b += vb * h;
            vd = (vd - k * (d - t11) * h) * friction;
            d += vd * h;
        }
        if (!isFinite(a + b + d) || Math.abs(a - 1) > 1 || Math.abs(b) > 1 || Math.abs(d - 1) > 1) {
            a = 1, b = 0, d = 1, va = 0, vb = 0, vd = 0;
        }
        g00 = a, g01 = b, g11 = d, v00 = va, v01 = vb, v11 = vd;
    }

    // A size grown by spring progress `p` from a `seed` (which itself scales
    // in over the first fifth, so the drawer still starts from nothing).
    function grow(full: real, p: real, seed: real): real {
        const q = Math.max(0, p);
        return seed * Math.min(1, q * 5) + (full - seed) * q;
    }

    function resetGoo(): void {
        g00 = 1, g01 = 0, g11 = 1, v00 = 0, v01 = 0, v11 = 0;
        lastX = NaN;
    }

    FrameAnimation {
        running: Tokens.goo.enabled && root.active
        onTriggered: root.stepGoo(frameTime)
        onRunningChanged: {
            if (!running)
                root.resetGoo();
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
    // The command center's spring (soft overshoot, no wobble), the width a
    // touch brisker than the height so the corner blooms rather than scales.
    Behavior on progX {
        enabled: root.isCorner
        SpringAnimation {
            spring: Tokens.spring.spatial.spring * 1.12
            damping: Tokens.spring.spatial.damping
            epsilon: 0.002
        }
    }
    Behavior on progY {
        enabled: root.isCorner
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
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
        // A corner drawer grows in both directions with `prog`; closed, it's
        // its hot square.
        // Open, it grows from a small seed in the corner (as the command center
        // grows from the dock) instead of from nothing.
        readonly property real seed: 36
        readonly property real cornerW: root.thickness + (root.active ? root.grow(root.panelWidth, root.progX, seed) : root.zoneLength || 40)
        readonly property real cornerH: root.thicknessY + (root.active ? root.grow(root.panelHeight, root.progY, seed) : root.zoneLength || 40)

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

        Mist {
            anchors.fill: parent
            visible: root.atmosphere && Tokens.immersive && root.active
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Tokens.anim.slow
                }
            }
        }

        Item {
            id: body

            // The goo, about the same centre the frame shader uses.
            readonly property real gx: root.rect.x + root.rect.z / 2 - shape.x - x
            readonly property real gy: root.rect.y + root.rect.w / 2 - shape.y - y

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
            // The content on its own curve: it fades in and settles up from a
            // touch smaller, from the anchor (corner, or the bar it comes out
            // of), a beat after the drawer starts; it leaves faster.
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
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

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.open ? Tokens.dur(60) : 0
                    }
                    Anim {
                        duration: root.open ? Tokens.anim.normal : Tokens.anim.fast
                        easing.bezierCurve: root.open ? Tokens.anim.emphasizedDecel : Tokens.anim.emphasizedAccel
                    }
                }
            }
            Behavior on scale {
                Anim {
                    duration: Tokens.anim.slow
                    easing.bezierCurve: Tokens.anim.expressiveSpatial
                }
            }
        }
    }
}
