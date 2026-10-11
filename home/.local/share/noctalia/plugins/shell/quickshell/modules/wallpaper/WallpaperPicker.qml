pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The wallpaper picker (Mod+W): a search, folder chips and a strip of the
// library, the current one marked; click to set it (the palette follows).
// Keys: type to search, arrows move the selection, Enter sets it, Esc closes.
// Thumbnails load only while on screen, so a large library stays cheap.
Item {
    id: root

    property string folder: ""
    property string query: ""
    readonly property var walls: {
        const q = query.trim().toLowerCase();
        const inFolder = Wallpapers.inFolder(folder);
        return q ? inFolder.filter(w => w.name.toLowerCase().includes(q) || w.folder.toLowerCase().includes(q)) : inFolder;
    }

    function move(by: int): void {
        if (strip.count > 0)
            strip.currentIndex = Math.max(0, Math.min(strip.count - 1, strip.currentIndex + by));
    }

    function apply(): void {
        const w = walls[strip.currentIndex];
        if (w)
            Wallpapers.set(w.path);
    }

    Component.onCompleted: Qt.callLater(() => search.focusInput())

    Item {
        id: head

        width: parent.width
        height: 40

        GlossTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wallpaper"
            gloss: "画卷"
            size: Tokens.font.value
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            MicroLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: `${strip.count} walls`
            }

            TextField {
                id: search

                anchors.verticalCenter: parent.verticalCenter
                width: 260
                implicitHeight: 36
                placeholder: "Search wallpapers"
                onTextChanged: {
                    root.query = text;
                    strip.currentIndex = 0;
                }
                onAccepted: root.apply()
                keyFilter: event => {
                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                        root.move(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        root.move(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        strip.currentIndex = 0;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_End) {
                        strip.currentIndex = strip.count - 1;
                        event.accepted = true;
                    }
                }
            }

            IconButton {
                icon: "shuffle"
                size: 36
                onClicked: Wallpapers.random()
            }
        }
    }

    // Folder chips: all, then each folder.
    ListView {
        id: chips

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        width: parent.width
        height: 32
        orientation: ListView.Horizontal
        spacing: Tokens.spacing.small
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: ["", ...Wallpapers.folders]

        delegate: StyledRect {
            id: chip

            required property string modelData
            readonly property bool on: root.folder === modelData

            width: label.implicitWidth + Tokens.spacing.large * 2
            height: 32
            radius: Tokens.rounding.small
            color: on ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

            StateLayer {
                hovered: chipHover.hovered
                pressed: chipTap.pressed
                ink: Colours.palette.m3onSurface
            }

            StyledText {
                id: label

                anchors.centerIn: parent
                text: chip.modelData || "All"
                color: chip.on ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.small
                font.weight: chip.on ? Font.DemiBold : Font.Normal
                font.capitalization: Font.Capitalize
            }

            HoverHandler {
                id: chipHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: chipTap

                onTapped: root.folder = chip.modelData
            }
        }

        WheelHandler {
            orientation: Qt.Vertical
            onWheel: event => chips.flick(event.angleDelta.y * 6, 0)
        }
    }

    // The strip.
    ListView {
        id: strip

        anchors.top: chips.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.bottom: parent.bottom
        width: parent.width
        orientation: ListView.Horizontal
        spacing: Tokens.spacing.normal
        clip: true
        cacheBuffer: 600
        boundsBehavior: Flickable.StopAtBounds
        model: root.walls
        highlightMoveDuration: Tokens.anim.normal
        highlightFollowsCurrentItem: true
        preferredHighlightBegin: width / 2 - height * 8 / 9
        preferredHighlightEnd: width / 2 + height * 8 / 9
        highlightRangeMode: ListView.ApplyRange

        WheelHandler {
            orientation: Qt.Vertical
            onWheel: event => strip.flick(event.angleDelta.y * 8, 0)
        }

        delegate: Item {
            id: wall

            required property var modelData
            required property int index
            readonly property bool current: modelData.path === Session.wallpaper
            readonly property bool selected: ListView.isCurrentItem

            width: Math.round(strip.height * 16 / 9)
            height: strip.height

            ClippingRectangle {
                id: thumb

                anchors.fill: parent
                anchors.margins: wall.current || wall.selected ? 0 : hover.hovered ? 2 : 4
                radius: Tokens.rounding.normal
                color: Colours.palette.m3surfaceContainerHigh

                Behavior on anchors.margins {
                    Anim {
                        duration: Tokens.anim.fast
                    }
                }

                Image {
                    anchors.fill: parent
                    source: "file://" + wall.modelData.path
                    sourceSize: Qt.size(Math.round(wall.width * 1.2), Math.round(wall.height * 1.2))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Tokens.anim.normal
                        }
                    }
                }

                // The selection: an ink frame; the current one: gold and a seal.
                Rectangle {
                    anchors.fill: parent
                    visible: wall.selected && !wall.current
                    color: "transparent"
                    radius: thumb.radius
                    border.width: 2
                    border.color: Colours.palette.m3onSurface
                }

                Rectangle {
                    anchors.fill: parent
                    visible: wall.current
                    color: "transparent"
                    radius: thumb.radius
                    border.width: 2
                    border.color: Colours.palette.m3primary
                }

                Seal {
                    visible: wall.current
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.small
                    glyph: "印"
                    size: 20
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    strip.currentIndex = wall.index;
                    Wallpapers.set(wall.modelData.path);
                }
            }
        }

        // Start at the current wallpaper (once laid out, and again if the
        // library or the folder changes under it).
        function centreOnCurrent(): void {
            if (root.query)
                return;
            const i = model.findIndex(w => w.path === Session.wallpaper);
            if (i >= 0) {
                currentIndex = i;
                positionViewAtIndex(i, ListView.Center);
            }
        }

        Component.onCompleted: Qt.callLater(centreOnCurrent)
        onCountChanged: Qt.callLater(centreOnCurrent)
        // The drawer is still growing when this loads: centre again as the
        // strip's size settles, and once the opening spring is done.
        onHeightChanged: Qt.callLater(centreOnCurrent)
        onWidthChanged: Qt.callLater(centreOnCurrent)

        Timer {
            running: true
            interval: 450
            onTriggered: strip.centreOnCurrent()
        }
    }
}
