pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import M3Shapes
import Nafeel
import qs.config
import qs.services
import qs.components

// Media (Caelestia's layout, on the shell's parts): Material shapes drifting
// behind; the cover cut to a nine-sided cookie with the music coming off its
// edge; the track's details, its position and the controls; the lyrics
// following the song, and which player to show. Nothing playing: a clamshell
// and a line saying so.
Item {
    id: root

    readonly property var player: Media.active
    readonly property real length: player?.length ?? 0

    function time(s: real): string {
        if (!(s >= 0))
            return "-:--";
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    Component.onCompleted: Lyrics.watchers++
    Component.onDestruction: Lyrics.watchers--

    // MPRIS only updates the position when asked.
    Timer {
        running: root.visible && Media.playing
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    // ── Shapes drifting behind, while it plays ──
    Item {
        id: drift

        readonly property var pool: [MaterialShape.Circle, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.SoftBurst, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Arch, MaterialShape.Pill, MaterialShape.Oval]
        readonly property var roles: ["primary", "secondary", "tertiary", "paper"]

        anchors.fill: parent
        clip: true

        Repeater {
            id: shapes

            model: 14

            MaterialShape {
                required property int index
                property real vx: (4 + Math.random() * 14) * (Math.random() < 0.5 ? -1 : 1)
                property real vy: (4 + Math.random() * 14) * (Math.random() < 0.5 ? -1 : 1)
                property real vr: -12 + Math.random() * 24
                readonly property string tone: drift.roles[Math.floor(Math.random() * 4)]

                implicitSize: 36 + index / 14 * 88
                shape: drift.pool[Math.floor(Math.random() * drift.pool.length)]
                color: Colours.roleFill(tone, "soft", 0)
                opacity: Colours.light ? 0.3 : 0.14
                rotation: Math.random() * 360
                Component.onCompleted: {
                    x = Math.random() * Math.max(1, drift.width - implicitSize);
                    y = Math.random() * Math.max(1, drift.height - implicitSize);
                }
            }
        }

        FrameAnimation {
            running: root.visible && Media.playing && !Tokens.reduceMotion
            onTriggered: {
                for (let i = 0; i < shapes.count; i++) {
                    const s = shapes.itemAt(i);
                    if (!s)
                        continue;
                    s.x += s.vx * frameTime;
                    s.y += s.vy * frameTime;
                    s.rotation += s.vr * frameTime;
                    if (s.x + s.width < 0)
                        s.x = drift.width;
                    else if (s.x > drift.width)
                        s.x = -s.width;
                    if (s.y + s.height < 0)
                        s.y = drift.height;
                    else if (s.y > drift.height)
                        s.y = -s.height;
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.large
        spacing: Tokens.spacing.huge

        // ── The cover and the music off its edge ──
        Item {
            id: visual

            Layout.preferredWidth: 300
            Layout.fillHeight: true

            readonly property real cx: width / 2
            readonly property real cy: height / 2
            readonly property real reach: (Math.min(width, height) - cover.width) / 2 - 8

            Loader {
                active: Media.playing
                sourceComponent: ServiceRef {
                    service: Visualiser.cava
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                data: bars.instances
            }

            Variants {
                id: bars

                model: Array.from({
                    length: Visualiser.bars
                }, (_, i) => i)

                ShapePath {
                    id: bar

                    required property int modelData
                    readonly property real value: Math.max(0.02, Math.min(1, Visualiser.cava.values[modelData] ?? 0))
                    readonly property real angle: modelData * 2 * Math.PI / Visualiser.bars
                    readonly property real edge: cover.shapeItem.distanceAtAngle(modelData * 360 / Visualiser.bars + 90) + 6
                    readonly property real dist: edge + visual.reach * value

                    strokeWidth: 360 / Visualiser.bars - 2
                    strokeColor: Colours.roleInk("primary", "ghost")
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: visual.cx + Math.cos(angle) * edge
                    startY: visual.cy + Math.sin(angle) * edge

                    PathLine {
                        x: visual.cx + Math.cos(bar.angle) * bar.dist
                        y: visual.cy + Math.sin(bar.angle) * bar.dist
                    }
                }
            }

            ShapeImage {
                id: cover

                anchors.centerIn: parent
                width: 210
                height: 210
                source: Media.art
                shape: MaterialShape.Cookie9Sided
                icon: "image"
            }
        }

        // ── Nothing playing ──
        Column {
            visible: !root.player
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.small

            ShapeBadge {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 110
                shape: MaterialShape.ClamShell
                role: "primary"
                icon: "queue_music"
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing playing"
                color: Colours.roleInk("paper", "soft")
                font.pixelSize: 26
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Play something for it to show up here."
                color: Colours.roleSubInk("paper", "soft")
                font.pixelSize: Tokens.font.row
            }
        }

        // ── The track ──
        ColumnLayout {
            visible: !!root.player
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Unknown title"
                color: Colours.roleInk("paper", "soft")
                font.pixelSize: 24
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || "Unknown artist"
                color: Colours.roleSubInk("paper", "soft")
                font.pixelSize: Tokens.font.title
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackAlbum || "Unknown album"
                color: Colours.roleInk("secondary", "ghost")
                font.pixelSize: Tokens.font.title
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.topMargin: Tokens.spacing.huge
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: root.time(root.player?.position ?? -1)
                    color: Colours.roleSubInk("paper", "soft")
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    to: Math.max(1, root.length)
                    value: root.player?.position ?? 0
                    onMoved: v => {
                        if (root.player?.canSeek)
                            root.player.position = v;
                    }
                }

                StyledText {
                    text: root.time(root.length)
                    color: Colours.roleSubInk("paper", "soft")
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.small
                }
            }

            // Shuffle · previous · play (wide) · next · repeat.
            RowLayout {
                Layout.topMargin: Tokens.spacing.large
                Layout.fillWidth: true
                spacing: 4

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "shuffle"
                    size: 44
                    filled: root.player?.shuffle ?? false
                    enabled: root.player?.shuffleSupported ?? false
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "skip_previous"
                    size: 52
                    onClicked: Media.previous()
                }

                Surface {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    role: Media.playing ? "primary" : "secondary"
                    emphasis: Media.playing ? "strong" : "soft"
                    shape: "full"
                    interactive: true
                    onClicked: Media.togglePlaying()

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Media.playing ? "pause" : "play_arrow"
                        fill: 1
                        size: 28
                        color: parent.ink
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "skip_next"
                    size: 52
                    onClicked: Media.next()
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    size: 44
                    filled: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                    enabled: root.player?.loopSupported ?? false
                    onClicked: {
                        const s = root.player.loopState;
                        root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Track : s === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None;
                    }
                }
            }
        }

        // ── Lyrics, and the player ──
        ColumnLayout {
            visible: !!root.player
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: Tokens.spacing.normal

            Row {
                spacing: Tokens.spacing.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lyrics"
                    size: 22
                    color: Colours.roleInk("paper", "soft")
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Lyrics"
                    color: Colours.roleInk("paper", "soft")
                    font.pixelSize: Tokens.font.title
                }

                MicroLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lyrics.state === "loading" ? "· finding them" : Lyrics.lines.length ? "· lrclib" : ""
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: lines

                    anchors.fill: parent
                    visible: Lyrics.lines.length > 0
                    clip: true
                    model: Lyrics.lines
                    spacing: 6
                    interactive: false
                    currentIndex: Math.max(0, Lyrics.current)
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 16
                    preferredHighlightEnd: height / 2 + 16
                    highlightMoveDuration: Tokens.dur(420)

                    delegate: StyledText {
                        required property var modelData
                        required property int index
                        readonly property bool now: index === Lyrics.current

                        width: lines.width
                        wrapMode: Text.WordWrap
                        text: modelData.text || "♪"
                        color: now ? Colours.roleInk("primary", "ghost") : Colours.roleSubInk("paper", "soft")
                        opacity: now ? 1 : Math.max(0.3, 0.8 - Math.abs(index - Lyrics.current) * 0.12)
                        font.pixelSize: now ? Tokens.font.title : Tokens.font.row
                        font.weight: now ? Font.DemiBold : Font.Normal
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: Lyrics.lines.length === 0 && Lyrics.plain !== ""
                    contentHeight: plainText.implicitHeight
                    clip: true

                    StyledText {
                        id: plainText

                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: Lyrics.plain
                        color: Colours.roleSubInk("paper", "soft")
                        font.pixelSize: Tokens.font.row
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: Lyrics.state === "none" || Lyrics.state === "idle"
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "sentiment_dissatisfied"
                        size: 44
                        color: Colours.roleSubInk("paper", "soft")
                    }

                    StyledText {
                        text: "No lyrics found"
                        color: Colours.roleSubInk("paper", "soft")
                        font.pixelSize: Tokens.font.row
                    }
                }
            }

            // Which player (when there are several): their names as chips.
            Flow {
                Layout.fillWidth: true
                spacing: 4

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
}
