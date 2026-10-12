import QtQuick
import qs.config
import qs.services
import qs.components

// Now: the icon, the temperature, what it's like and where.
Surface {
    id: root

    level: 2
    implicitHeight: 96

    Row {
        anchors.centerIn: parent
        spacing: Tokens.spacing.large

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.icon
            size: 44
            color: Colours.roleInk("primary", "ghost")
            fill: 1
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: Weather.current ? `${Math.round(Weather.temp)}°` : "—"
                color: root.ink
                font.family: Tokens.font.serif
                font.pixelSize: 32
            }

            MicroLabel {
                text: Weather.current ? `${Weather.description} · ${Weather.place}` : "no weather yet"
            }
        }
    }
}
