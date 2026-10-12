pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// A fanned hand of cards (after Ryoku's HandView, MIT): cards splay from a
// shared pivot in a shallow arc, the selected one lifted to the centre. Only
// a window of cards around the selection exists, so a hand of a thousand
// costs the same as a hand of ten, and one sprung scroll value drives every
// card's slide, lift, turn and depth at once.
Item {
    id: root

    property var model: []
    property int currentIndex: 0
    readonly property int count: model.length

    signal picked(int index, bool close)

    // The fan.
    readonly property real cardHeight: (height - 22) * 0.80
    readonly property real cardWidth: cardHeight * 0.68
    readonly property real spread: cardWidth * 0.52
    readonly property real fanAngle: 6
    readonly property real arch: cardHeight * 0.035
    readonly property int window: 11

    // Follows currentIndex on a spring: what every card reads.
    property real scroll: currentIndex

    Behavior on scroll {
        SpringAnimation {
            spring: Tokens.springK(3.2)
            damping: Tokens.dampK(0.32)
            epsilon: 0.002
        }
    }

    function move(dx: int, dy: int): void {
        if (count > 0)
            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + dx + dy));
    }

    function centreOn(i: int): void {
        if (i >= 0 && i < count)
            currentIndex = i;
    }

    clip: false

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.move(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1, 0)
    }

    Repeater {
        model: root.window

        WallCard {
            id: card

            required property int index
            // The wallpaper this slot shows: slots follow the scroll.
            readonly property int wallIndex: Math.round(root.scroll) + index - Math.floor(root.window / 2)
            readonly property bool valid: wallIndex >= 0 && wallIndex < root.count
            readonly property real d: wallIndex - root.scroll
            readonly property real ad: Math.abs(d)
            readonly property real lift: Math.max(0, 1 - ad) // 1 at the centre

            visible: valid && ad < root.window / 2
            wall: valid ? root.model[wallIndex] : ({
                    path: "",
                    name: ""
                })
            width: root.cardWidth
            height: root.cardHeight
            radius: Tokens.rounding.large
            selected: wallIndex === root.currentIndex
            details: ad < 0.5

            x: root.width / 2 - width / 2 + d * root.spread
            // The centre card stands highest; the fan sinks a little each way
            // (capped, so the outer cards stay inside the panel).
            y: root.cardHeight * 0.10 + Math.min(ad * ad * root.arch, root.cardHeight * 0.12) - lift * root.cardHeight * 0.08
            z: 100 - ad
            rotation: d * root.fanAngle
            transformOrigin: Item.Bottom
            scale: (1 - Math.min(ad * 0.05, 0.35)) * (1 + lift * 0.06)
            opacity: Math.max(0, Math.min(1, (root.window / 2 - ad) / 1.5))

            onTapped: {
                if (wallIndex === root.currentIndex)
                    root.picked(wallIndex, false);
                else
                    root.currentIndex = wallIndex;
            }
            onDoubleTapped: {
                root.currentIndex = wallIndex;
                root.picked(wallIndex, true);
            }
        }
    }

    // The name under the hand.
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Tokens.spacing.small
        text: root.model[root.currentIndex]?.name ?? ""
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: Tokens.font.small
        font.family: Tokens.font.mono
        elide: Text.ElideMiddle
        width: Math.min(implicitWidth, root.width * 0.6)
    }
}
