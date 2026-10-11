import QtQuick
import qs.config
import qs.services

// A list row: leading icon, title and subtitle, trailing items.
StyledRect {
    id: root

    property string icon
    property real iconFill: 0
    property string title
    property string subtitle
    property bool highlighted
    default property alias trailing: end.data

    signal clicked

    implicitHeight: 52
    radius: Tokens.rounding.normal
    color: highlighted ? Colours.palette.m3secondaryContainer : "transparent"

    StateLayer {
        hovered: hover.hovered
        pressed: tap.pressed
        ink: root.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
    }

    MaterialIcon {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        fill: root.iconFill
        color: root.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: end.left
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
            color: root.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: root.highlighted ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.8) : Colours.palette.m3onSurfaceVariant
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Row {
        id: end

        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small
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
