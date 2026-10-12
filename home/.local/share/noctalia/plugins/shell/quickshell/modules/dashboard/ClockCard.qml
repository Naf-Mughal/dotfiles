import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The time, Caelestia's way: the hour, three dots, the minute, and AM/PM
// under them in the twelve-hour clock.
Surface {
    id: root

    level: 2
    implicitWidth: 112

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        spacing: -10

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "hh AP").split(" ")[0]
            color: Colours.roleInk("secondary", "ghost")
            font.pixelSize: 40
            font.weight: Font.DemiBold
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "•••"
            color: Colours.roleInk("primary", "ghost")
            font.pixelSize: 34
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "mm")
            color: Colours.roleInk("secondary", "ghost")
            font.pixelSize: 40
            font.weight: Font.DemiBold
        }

        Item {
            width: 1
            height: 14
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "AP")
            color: Colours.roleInk("primary", "ghost")
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
    }
}
