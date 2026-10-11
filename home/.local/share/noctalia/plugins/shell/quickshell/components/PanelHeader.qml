import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// A panel's heading: an icon badge (a Surface in the secondary role), the
// title with its Chinese gloss, a subtitle, and trailing actions.
RowLayout {
    id: root

    property string icon
    property string title
    property string gloss
    property string subtitle
    default property alias trailing: end.data

    spacing: Tokens.spacing.normal

    Surface {
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        role: "secondary"

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icon
            fill: 1
            color: parent.ink
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
            font.pixelSize: Tokens.font.small
            elide: Text.ElideRight
        }
    }

    Item {
        id: end

        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
    }
}
