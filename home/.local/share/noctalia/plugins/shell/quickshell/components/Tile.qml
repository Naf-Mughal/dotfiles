import QtQuick
import qs.config
import qs.services

// An M3 Expressive toggle tile: icon, label and state line. On, it fills
// with primary and its corners round out further (a shape change, not just
// a colour one).
StyledRect {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool checked
    // Icon above the label, centred: for tiles three or more across.
    property bool stacked: false

    signal clicked

    implicitHeight: 64
    radius: checked ? Tokens.rounding.large : tap.pressed ? Tokens.rounding.small : Tokens.rounding.normal
    color: checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

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
        ink: root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
    }

    PressBounce {
        pressed: tap.pressed
        depth: 0.97
    }

    Behavior on radius {
        Anim {
            easing.bezierCurve: Tokens.anim.expressiveFastSpatial
        }
    }

    Column {
        visible: root.stacked
        anchors.centerIn: parent
        spacing: 2

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            size: 22
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font.pixelSize: Tokens.font.small
            font.weight: Font.DemiBold
        }
    }

    Row {
        visible: !root.stacked
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.large
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.normal

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.checked ? 1 : 0
            color: root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            size: 22
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - Tokens.spacing.normal

            StyledText {
                width: parent.width
                text: root.label
                color: root.checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.sublabel
                color: root.checked ? Qt.alpha(Colours.palette.m3onPrimary, 0.8) : Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
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
