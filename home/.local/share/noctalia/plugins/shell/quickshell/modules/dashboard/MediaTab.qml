import QtQuick
import qs.config
import qs.services
import qs.components

// Media (Caelestia's): the record large with its controls, and beside it
// the player to show (when there are several) and the visualiser.
Item {
    id: root

    MediaCard {
        id: card

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 340
        big: true
    }

    Surface {
        anchors.left: card.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        level: 2

        Sheet {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            title: "Players"
            gloss: "播放"

            Flow {
                width: parent.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: Media.players

                    Chip {
                        required property var modelData

                        icon: modelData.isPlaying ? "graphic_eq" : "music_note"
                        text: modelData.identity || modelData.desktopEntry || "Player"
                        selected: modelData === Media.active
                        onClicked: Media.choose(modelData)
                    }
                }
            }

            EmptyState {
                visible: Media.players.length === 0
                icon: "music_off"
                title: "Nothing is playing"
            }
        }
    }
}
