import QtQuick
import qs.config
import qs.services
import qs.components

// Now (Caelestia's small weather): the icon large in secondary, the
// temperature large in primary, what it's like under it.
Surface {
    id: root

    level: 2
    implicitHeight: 110

    Row {
        anchors.centerIn: parent
        spacing: Tokens.spacing.huge

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon
            size: 64
            color: Colours.roleInk("secondary", "ghost")
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.current ? `${Math.round(Weather.temp)}°C` : "—"
                color: Colours.roleInk("primary", "ghost")
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Weather.current ? Weather.description : "No weather yet"
                color: root.ink
                font.pixelSize: Tokens.font.small
            }
        }
    }
}
