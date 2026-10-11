import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Icon badge, the title with its Chinese gloss, and a subtitle, with an
// optional trailing item.
RowLayout {
    id: root

    property string icon
    property string title
    property string gloss
    property string subtitle
    default property alias trailing: end.data

    spacing: Tokens.spacing.normal

    StyledRect {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: Tokens.rounding.normal
        color: Colours.palette.m3secondaryContainer

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            fill: 1
            color: Colours.palette.m3onSecondaryContainer
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        GlossTitle {
            Layout.fillWidth: true
            text: root.title
            gloss: root.gloss
            size: Tokens.font.value
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            color: Colours.palette.m3onSurfaceVariant
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Item {
        id: end

        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
    }
}
