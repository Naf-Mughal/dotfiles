import QtQuick
import qs.config
import qs.services

// A round Material icon button. `filled` uses the colour pair as a solid
// fill; otherwise it's a tonal button that fills while hovered.
StyledRect {
    id: root

    property string icon
    property bool filled: false
    property color fillColour: Colours.palette.m3secondaryContainer
    property color inkColour: Colours.palette.m3onSecondaryContainer
    property int size: 40

    signal clicked

    implicitWidth: size
    implicitHeight: size
    // M3 Expressive shape morph: rounder at rest, squarer while pressed.
    radius: tap.pressed ? Tokens.rounding.small : Math.min(size / 2, Tokens.rounding.morph)
    color: filled ? fillColour : Colours.palette.m3surfaceContainerHigh

    Behavior on scale {
        SpringAnimation {
            spring: Tokens.spring.bouncy.spring
            damping: Tokens.spring.bouncy.damping
            epsilon: 0.002
        }
    }

    StateLayer {
        hovered: hover.hovered
        pressed: tap.pressed
        ink: root.filled ? root.inkColour : Colours.palette.m3onSurface
    }

    PressBounce {
        pressed: tap.pressed
        depth: 0.9
    }

    Behavior on radius {
        Anim {
            duration: Tokens.anim.fast
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        fill: root.filled ? 1 : 0
        color: root.filled ? root.inkColour : Colours.palette.m3onSurface
        size: Math.round(root.size * 0.5)
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: root.clicked()
    }
}
