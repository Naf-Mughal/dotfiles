import QtQuick
import qs.config
import qs.services
import qs.components

// Media (Caelestia's): the record large, the music radiating out of it, its
// controls; beside it the players (when there are several) and the lyrics,
// following the song line by line (lrclib).
Item {
    id: root

    Component.onCompleted: Lyrics.watchers++
    Component.onDestruction: Lyrics.watchers--

    MediaCard {
        id: card

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 380
        big: true
    }

    Column {
        anchors.left: card.right
        anchors.leftMargin: Tokens.spacing.normal
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: Tokens.spacing.normal

        Surface {
            id: players

            visible: Media.players.length > 1
            width: parent.width
            height: visible ? 84 : 0
            level: 2

            Sheet {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.normal
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
            }
        }

        Surface {
            id: lyricsCard

            width: parent.width
            height: parent.height - (players.visible ? players.height + Tokens.spacing.normal : 0)
            level: 2

            Sheet {
                id: lyricsSheet

                anchors.fill: parent
                anchors.margins: Tokens.spacing.large
                title: "Lyrics"
                gloss: "歌词"
                eyebrow: Lyrics.state === "loading" ? "finding them" : Lyrics.lines.length ? "synced · lrclib" : ""
            }

            ListView {
                id: lines

                anchors.fill: parent
                anchors.topMargin: 64
                anchors.margins: Tokens.spacing.large
                visible: Lyrics.lines.length > 0
                clip: true
                model: Lyrics.lines
                spacing: 6
                interactive: false
                currentIndex: Math.max(0, Lyrics.current)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 18
                preferredHighlightEnd: height / 2 + 18
                highlightMoveDuration: Tokens.dur(420)

                delegate: StyledText {
                    required property var modelData
                    required property int index
                    readonly property bool now: index === Lyrics.current

                    width: lines.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: modelData.text || "♪"
                    color: now ? lyricsCard.ink : lyricsCard.subInk
                    opacity: now ? 1 : Math.max(0.25, 0.75 - Math.abs(index - Lyrics.current) * 0.12)
                    font.family: Tokens.font.serif
                    font.pixelSize: now ? Tokens.font.title : Tokens.font.row

                    Behavior on font.pixelSize {
                        Anim {}
                    }
                }
            }

            // Unsynced lyrics, as text.
            Flickable {
                anchors.fill: parent
                anchors.topMargin: 64
                anchors.margins: Tokens.spacing.large
                visible: Lyrics.lines.length === 0 && Lyrics.plain !== ""
                contentHeight: plainText.implicitHeight
                clip: true

                StyledText {
                    id: plainText

                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Lyrics.plain
                    color: lyricsCard.subInk
                    font.pixelSize: Tokens.font.row
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: Lyrics.state !== "ready" && Lyrics.state !== "loading"
                icon: Media.players.length ? "lyrics" : "music_off"
                title: Media.players.length ? "No lyrics for this one" : "Nothing is playing"
            }
        }
    }
}
