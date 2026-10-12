pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components

// The wallpaper picker (Mod+W): a search, folder chips and a strip of the
// library, the current one marked. Click one to choose it (its palette is
// made meanwhile); it's set when the picker closes, under the shell's ink
// transition, with the theme. Double click or Enter: choose and close.
// Keys: type to search, arrows move the selection, Esc closes.
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

    // Choose the selected one; `close`: and set it now.
    function choose(close: bool): void {
        const w = walls[strip.currentIndex];
        if (!w)
            return;
        Wallpapers.stage("set", w.path);
        if (close)
            ShellState.close();
    }

    function apply(): void {
        choose(true);
    }

    Component.onCompleted: Qt.callLater(() => search.focusInput())

    // The keyboard goes to the search when the picker is pinned.
    Connections {
        target: ShellState

        function onKeyboardGranted(req: var): void {
            if (ShellState.pinned === "wallpapers") {
                search.focusInput();
                req.taken = true;
            }
        }
    }

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
                onClicked: {
                    // A random one, chosen (and shown) like a click.
                    const others = root.walls.filter(w => w.path !== Wallpapers.current);
                    if (others.length === 0)
                        return;
                    const pick = others[Math.floor(Math.random() * others.length)];
                    strip.currentIndex = root.walls.indexOf(pick);
                    strip.positionViewAtIndex(strip.currentIndex, ListView.Center);
                    Wallpapers.stage("set", pick.path);
                }
            }
        }
    }

    // Folder chips: all, then each folder.
    Strip {
        id: chips

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        width: parent.width
        height: 32
        spacing: Tokens.spacing.small
        wheelStep: 6
        model: ["", ...Wallpapers.folders]

        delegate: Chip {
            required property string modelData

            text: modelData ? modelData.charAt(0).toUpperCase() + modelData.slice(1) : "All"
            selected: root.folder === modelData
            onClicked: root.folder = modelData
        }
    }

    // The strip.
    Strip {
        id: strip

        anchors.top: chips.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.bottom: parent.bottom
        width: parent.width
        cacheBuffer: 600
        model: root.walls
        centred: true

        delegate: Item {
            id: wall

            required property var modelData
            required property int index
            readonly property bool current: modelData.path === Session.wallpaper
            // Chosen: set when the picker closes.
            readonly property bool chosen: modelData.path === Wallpapers.chosen
            readonly property bool selected: ListView.isCurrentItem

            width: Math.round(strip.height * 16 / 9)
            height: strip.height

            ClippingRectangle {
                id: thumb

                anchors.fill: parent
                anchors.margins: wall.current || wall.selected || wall.chosen ? 0 : hover.hovered ? 2 : 4
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
                // Chosen: a wet ink frame and its seal, waiting for the close.
                Rectangle {
                    anchors.fill: parent
                    visible: wall.chosen
                    color: "transparent"
                    radius: thumb.radius
                    border.width: 3
                    border.color: Colours.palette.m3tertiary
                }

                Seal {
                    visible: wall.chosen
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.small
                    glyph: "選"
                    size: 20
                }

                Rectangle {
                    anchors.fill: parent
                    visible: wall.selected && !wall.current && !wall.chosen
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
                    root.choose(false);
                }
                onDoubleTapped: {
                    strip.currentIndex = wall.index;
                    root.choose(true);
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
