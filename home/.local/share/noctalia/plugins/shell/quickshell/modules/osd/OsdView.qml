import QtQuick
import qs.config
import qs.services
import qs.components

// The OSD's content, a pill out of the top bar: for a level (volume,
// microphone, brightness) the panels' M3 slider with the percentage on its icon
// button, or an icon and a label for a toggle.
Item {
    id: root

    readonly property bool level: Osd.kind !== "toggle"
    readonly property int pad: Tokens.spacing.large

    implicitWidth: level ? 40 + Tokens.spacing.small + 260 + pad * 2 : toggleRow.implicitWidth + pad * 2
    implicitHeight: 56

    // A level: the M3 slider (as in the panels), its icon button carrying the
    // percentage; drag it to change the level right there.
    Row {
        visible: root.level
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Osd.icon
            filled: true
            fillColour: Osd.kind === "mic" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
            inkColour: Osd.kind === "mic" ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSecondaryContainer
            caption: Math.round(Osd.value * 100)
            onClicked: {
                if (Osd.kind === "volume")
                    Audio.toggleMute();
            }
        }

        StyledSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: 260
            value: Osd.value
            to: Osd.kind === "brightness" ? 1 : Math.max(1, Osd.value)
            fill: Osd.value > 1 ? Colours.palette.m3error : Osd.kind === "mic" ? Colours.palette.m3tertiary : Colours.palette.m3primary
            ink: Osd.kind === "mic" ? Colours.palette.m3onTertiary : Colours.palette.m3onPrimary
            track: Osd.kind === "mic" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3secondaryContainer
            onMoved: v => {
                if (Osd.kind === "brightness")
                    Brightness.set(v);
                else if (Osd.kind === "volume")
                    Audio.setVolume(v);
            }
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
