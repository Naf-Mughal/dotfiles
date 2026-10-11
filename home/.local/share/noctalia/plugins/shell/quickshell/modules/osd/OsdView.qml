import QtQuick
import qs.config
import qs.services
import qs.components

// The OSD's content, a pill out of the top bar: the icon, a level bar and its
// percentage (volume, microphone, brightness), or an icon and a label for a
// toggle.
Item {
    id: root

    readonly property bool level: Osd.kind !== "toggle"
    readonly property int pad: Tokens.spacing.large

    implicitWidth: level ? 340 : toggleRow.implicitWidth + pad * 2
    implicitHeight: 56

    Row {
        visible: root.level
        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.icon
            fill: 1
            size: 22
            color: Osd.kind === "mic" ? Colours.palette.m3tertiary : Colours.palette.m3primary
        }

        StyledRect {
            anchors.verticalCenter: parent.verticalCenter
            width: 220
            height: 8
            radius: 4
            color: Osd.kind === "mic" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer

            StyledRect {
                width: Math.max(height, parent.width * Math.min(1, Osd.value))
                height: parent.height
                radius: 4
                color: Osd.value > 1 ? Colours.palette.m3error : Osd.kind === "mic" ? Colours.palette.m3tertiary : Colours.palette.m3primary

                Behavior on width {
                    Anim {
                        duration: Tokens.anim.fast
                    }
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            horizontalAlignment: Text.AlignRight
            text: Math.round(Osd.value * 100)
            font.family: Tokens.font.serif
            font.pixelSize: Tokens.font.row
            font.weight: Font.DemiBold
        }
    }

    Row {
        id: toggleRow

        visible: !root.level
        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.icon
            fill: 1
            size: 22
            color: Colours.palette.m3primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.label
            font.pixelSize: Tokens.font.row
            font.weight: Font.DemiBold
        }
    }
}
