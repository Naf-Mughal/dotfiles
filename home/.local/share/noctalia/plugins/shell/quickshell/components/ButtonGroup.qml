pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// An M3 Expressive connected button group: segments with small inner and
// round outer corners; the selected one fills and rounds fully.
//   model: [{ value, icon, label }]
Row {
    id: root

    property var model: []
    property var current
    signal selected(var value)

    spacing: 2

    Repeater {
        model: root.model

        StyledRect {
            id: seg

            required property var modelData
            required property int index
            readonly property bool on: modelData.value === root.current
            readonly property bool first: index === 0
            readonly property bool last: index === root.model.length - 1

            width: (root.width - root.spacing * (root.model.length - 1)) / root.model.length
            height: 52
            topLeftRadius: on || first ? Tokens.rounding.morph : Math.max(2, Tokens.rounding.small / 2)
            bottomLeftRadius: topLeftRadius
            topRightRadius: on || last ? Tokens.rounding.morph : Math.max(2, Tokens.rounding.small / 2)
            bottomRightRadius: topRightRadius
            color: on ? Colours.palette.m3secondary : Colours.palette.m3surfaceContainerHigh

            Behavior on scale {
                SpringAnimation {
                    spring: Tokens.spring.bouncy.spring
                    damping: Tokens.spring.bouncy.damping
                    epsilon: 0.002
                }
            }

            StateLayer {
                hovered: hover.hovered
                pressed: segTap.pressed
                ink: seg.on ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface
            }

            PressBounce {
                pressed: segTap.pressed
                depth: 0.95
            }

            Behavior on topLeftRadius {
                Anim {}
            }
            Behavior on topRightRadius {
                Anim {}
            }

            Column {
                anchors.centerIn: parent
                spacing: 0

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seg.modelData.icon
                    fill: seg.on ? 1 : 0
                    color: seg.on ? Colours.palette.m3onSecondary : Colours.palette.m3onSurface
                    size: 18
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: seg.modelData.label
                    color: seg.on ? Colours.palette.m3onSecondary : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: segTap

                onTapped: root.selected(seg.modelData.value)
            }
        }
    }
}
