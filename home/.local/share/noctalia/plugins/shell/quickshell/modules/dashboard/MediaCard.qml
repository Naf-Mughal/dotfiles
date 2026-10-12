import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import qs.config
import qs.services
import qs.components

// What's playing (Caelestia's dashboard media): the cover cut to a cookie
// under an arc of how far into the track you are, the title, album and
// artist, the controls, and bongocat drumming along while it plays.
Surface {
    id: root

    readonly property var player: Media.active
    readonly property real progress: player?.length ? (player.position % player.length) / player.length : 0

    level: 2
    implicitWidth: 230

    // MPRIS only updates the position when asked.
    Timer {
        running: root.visible && Media.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.normal
        spacing: 4

        // The cover under its arc.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: width

            CircularProgress {
                anchors.fill: parent
                startAngle: -90 - 105
                sweepAngle: 210
                strokeWidth: 5
                value: root.progress
            }

            ShapeImage {
                anchors.fill: parent
                anchors.margins: 18
                source: Media.art
                shape: MaterialShape.Cookie12Sided
                icon: "image"
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.player ? root.player.trackTitle || "Unknown title" : "No media"
            color: Colours.roleInk("primary", "ghost")
            font.pixelSize: Tokens.font.row
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.player ? root.player.trackAlbum || "Unknown album" : "No media"
            color: root.subInk
            font.pixelSize: Tokens.font.small
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.player ? root.player.trackArtist || "Unknown artist" : "No media"
            color: Colours.roleInk("secondary", "ghost")
            font.pixelSize: Tokens.font.small
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            spacing: 4

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "skip_previous"
                size: 38
                onClicked: Media.previous()
            }

            Surface {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                role: Media.playing ? "primary" : "secondary"
                emphasis: Media.playing ? "strong" : "soft"
                shape: "full"
                interactive: true
                onClicked: Media.togglePlaying()

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Media.playing ? "pause" : "play_arrow"
                    fill: 1
                    size: 22
                    color: parent.ink
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "skip_next"
                size: 38
                onClicked: Media.next()
            }
        }

        // Bongocat, drumming while it plays.
        AnimatedImage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Tokens.spacing.small
            source: Qt.resolvedUrl("../../assets/bongocat.gif")
            fillMode: AnimatedImage.PreserveAspectFit
            playing: Media.playing
            asynchronous: true
        }
    }
}
