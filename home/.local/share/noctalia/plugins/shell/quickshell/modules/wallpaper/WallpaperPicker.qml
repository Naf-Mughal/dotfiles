pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components

// The wallpaper picker (Mod+W), after Ryoku's (ryogami wall-ui, MIT) in the
// shell's own hand: views (Ryoku's slice carousel, the strip, a mosaic),
// filters (folder, the wallpaper's colour as the palette reads it, dark or
// light, favourites, a search), sorts (name, colour wheel, recent, most
// used) over the library index (Wallpapers).
//
// The store (Wallhaven, the storefront button) shows in the same views with
// its own filters; choosing a result downloads it into ~/Pictures/Wallpapers/
// wallhaven and chooses it. Scrolling near the end fetches the next page.
//
// Click one to choose it (its palette is made meanwhile); it's set when the
// picker closes, under the shell's ink transition, with the theme. Double
// click or Enter: choose and close. Keys: type to search, arrows move, Esc
// closes, Ctrl+F favourite, Ctrl+1/2/3 the views.
Item {
    id: root

    readonly property bool store: Wallpapers.source === "store"
    readonly property var walls: store ? Wallhaven.results : Wallpapers.shown
    readonly property Item view: viewLoader.item
    readonly property int index: view?.currentIndex ?? 0

    // Ryoku's twelve hue swatches, in the palette's (Oklab) hues so a swatch
    // finds what the theme would call that colour; then black and white.
    readonly property var swatches: ["#e680a1", "#eb8373", "#df8f48", "#c4a032", "#9ab04b", "#62bb78", "#06bfa8", "#00b9cf", "#4baeed", "#859ff6", "#b191ea", "#d285cb"]

    function move(dx: int, dy: int): void {
        view?.move(dx, dy);
    }

    // Choose the selected one; `close`: and set it now.
    function choose(close: bool): void {
        const w = walls[index];
        if (!w)
            return;
        if (w.remote)
            // Downloaded first; chosen (or set, if the picker has closed) then.
            Wallpapers.fetch(w);
        else
            Wallpapers.stage("set", w.path);
        if (close)
            ShellState.close();
    }

    function apply(): void {
        choose(true);
    }

    function centreOnCurrent(): void {
        if (store) {
            if (Wallhaven.page <= 1)
                view?.centreOn(0);
            return;
        }
        if (Wallpapers.query)
            return;
        const i = walls.findIndex(w => w.path === (Wallpapers.chosen || Wallpapers.current));
        if (i >= 0)
            view?.centreOn(i);
    }

    Component.onCompleted: Qt.callLater(() => search.focusInput())

    Subscribe {
        topic: "picker.step"
        onReceived: p => root.move(p.n ?? 1, 0)
    }
    onWallsChanged: {
        // The store's next page only adds to the end: stay where you are.
        if (!store || Wallhaven.page <= 1)
            Qt.callLater(centreOnCurrent);
    }

    function toggleStore(): void {
        Wallpapers.source = store ? "library" : "store";
        if (Wallpapers.source === "store" && !Wallhaven.started)
            Wallhaven.search();
    }

    // Near the end of the store's results: the next page.
    Connections {
        target: root.view
        ignoreUnknownSignals: true

        function onCurrentIndexChanged(): void {
            if (root.store && root.view.currentIndex >= root.walls.length - 6)
                Wallhaven.more();
        }
        function onAtYEndChanged(): void {
            if (root.store && root.view.atYEnd)
                Wallhaven.more();
        }
        function onAtXEndChanged(): void {
            if (root.store && root.view.atXEnd)
                Wallhaven.more();
        }
    }

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

    // ── Heading: title, count, search, sort, views, shuffle ──
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
                text: root.store ? (Wallhaven.error ? Wallhaven.error : Wallhaven.loading ? "searching…" : `${root.walls.length} results · page ${Wallhaven.page}/${Wallhaven.lastPage}`) : Wallpapers.indexing ? `indexing ${Math.round(Wallpapers.indexProgress * 100)}%` : `${root.walls.length} / ${Wallpapers.all.length}`
                color: root.store && Wallhaven.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }

            TextField {
                id: search

                anchors.verticalCenter: parent.verticalCenter
                width: 240
                implicitHeight: 36
                placeholder: root.store ? "Search Wallhaven" : "Search wallpapers"
                text: root.store ? Wallhaven.query : Wallpapers.query
                onTextChanged: {
                    if (root.store)
                        Wallhaven.query = text;
                    else
                        Wallpapers.query = text;
                }
                onAccepted: root.apply()
                keyFilter: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    if (event.key === Qt.Key_Left) {
                        root.move(-1, 0);
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.move(1, 0);
                    } else if (event.key === Qt.Key_Up) {
                        root.move(0, -1);
                    } else if (event.key === Qt.Key_Down) {
                        root.move(0, 1);
                    } else if (event.key === Qt.Key_Home) {
                        root.view?.centreOn(0);
                    } else if (event.key === Qt.Key_End) {
                        root.view?.centreOn(root.walls.length - 1);
                    } else if (ctrl && event.key === Qt.Key_F) {
                        const w = root.walls[root.index];
                        if (w)
                            Wallpapers.toggleFavourite(w.path);
                    } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                        Wallpapers.view = ["slice", "strip", "mosaic"][event.key - Qt.Key_1];
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            // Sort: name, colour wheel, recent, most used (click cycles).
            IconButton {
                readonly property var modes: root.store ? ["toplist", "hot", "date_added", "random", "views", "favorites"] : ["name", "colour", "recent", "used"]
                readonly property var icons: ({
                        name: "sort_by_alpha",
                        colour: "palette",
                        recent: "schedule",
                        used: "trending_up",
                        toplist: "military_tech",
                        hot: "local_fire_department",
                        date_added: "schedule",
                        random: "casino",
                        views: "visibility",
                        favorites: "favorite"
                    })
                readonly property string mode: root.store ? Wallhaven.sorting : Wallpapers.sortMode

                icon: icons[mode] ?? "sort"
                size: 36
                caption: mode === "date_added" ? "latest" : mode === "toplist" ? "top" : mode
                onClicked: {
                    const next = modes[(modes.indexOf(mode) + 1) % modes.length];
                    if (root.store)
                        Wallhaven.sorting = next;
                    else
                        Wallpapers.sortMode = next;
                }
            }

            // The store: your library <-> Wallhaven.
            IconButton {
                icon: "storefront"
                size: 36
                filled: root.store
                caption: root.store ? "store" : ""
                onClicked: root.toggleStore()
            }

            Repeater {
                model: [["slice", "view_week"], ["strip", "view_carousel"], ["mosaic", "grid_view"]]

                IconButton {
                    required property var modelData

                    icon: modelData[1]
                    size: 36
                    filled: Wallpapers.view === modelData[0]
                    onClicked: Wallpapers.view = modelData[0]
                }
            }

            IconButton {
                visible: !root.store
                icon: "shuffle"
                size: 36
                onClicked: {
                    // A random one of those shown, chosen (and shown) like a click.
                    const others = root.walls.filter(w => w.path !== Wallpapers.current);
                    if (others.length === 0)
                        return;
                    const pick = others[Math.floor(Math.random() * others.length)];
                    root.view?.centreOn(root.walls.indexOf(pick));
                    Wallpapers.stage("set", pick.path);
                }
            }
        }
    }

    readonly property var ranges: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]
    readonly property var ratioCycle: [["landscape", "Landscape"], ["16x9", "16:9"], ["21x9", "21:9"], ["portrait", "Portrait"], ["", "Any ratio"]]
    readonly property var storeChips: {
        const key = Settings.wallhavenKey !== "";
        const ri = ratioCycle.findIndex(r => r[0] === Wallhaven.ratios);
        const chips = [
            {
                text: "General",
                on: Wallhaven.general,
                act: () => Wallhaven.general = !Wallhaven.general
            },
            {
                text: "Anime",
                on: Wallhaven.anime,
                act: () => Wallhaven.anime = !Wallhaven.anime
            },
            {
                text: "People",
                on: Wallhaven.people,
                act: () => Wallhaven.people = !Wallhaven.people
            },
            {
                text: "Sketchy",
                on: Wallhaven.sketchy && key,
                disabled: !key,
                act: () => Wallhaven.sketchy = !Wallhaven.sketchy
            },
            {
                text: "NSFW",
                on: Wallhaven.nsfw && key,
                disabled: !key,
                act: () => Wallhaven.nsfw = !Wallhaven.nsfw
            },
            {
                text: ratioCycle[Math.max(0, ri)][1],
                on: Wallhaven.ratios !== "",
                act: () => Wallhaven.ratios = ratioCycle[(Math.max(0, ri) + 1) % ratioCycle.length][0]
            },
            {
                text: Wallhaven.atleast ? `≥ ${Wallhaven.atleast}` : "Any size",
                on: Wallhaven.atleast !== "",
                act: () => Wallhaven.atleast = Wallhaven.atleast ? "" : (Quickshell.screens.length ? `${Quickshell.screens[0].width}x${Quickshell.screens[0].height}` : "1920x1080")
            }
        ];
        if (Wallhaven.sorting === "toplist")
            chips.push({
                text: `Top ${Wallhaven.topRange}`,
                on: true,
                act: () => Wallhaven.topRange = ranges[(ranges.indexOf(Wallhaven.topRange) + 1) % ranges.length]
            });
        return chips;
    }

    // ── Filters: folders, colour, tone, favourites ──
    Item {
        id: filters

        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        width: parent.width
        height: 32

        Strip {
            id: chips

            anchors.left: parent.left
            anchors.right: colourRow.left
            anchors.rightMargin: Tokens.spacing.normal
            height: parent.height
            spacing: Tokens.spacing.small
            wheelStep: 6
            // Library: folders. Store: Wallhaven's filters, each a toggle or a
            // cycle ({ text, on, act }).
            model: root.store ? root.storeChips : ["", ...Wallpapers.folders].map(f => ({
                        text: f ? f.charAt(0).toUpperCase() + f.slice(1) : "All",
                        on: Wallpapers.filterFolder === f,
                        act: () => Wallpapers.filterFolder = f
                    }))

            delegate: Chip {
                required property var modelData

                text: modelData.text
                selected: modelData.on
                opacity: modelData.disabled ? 0.4 : 1
                onClicked: {
                    if (!modelData.disabled)
                        modelData.act();
                }
            }
        }

        Row {
            id: colourRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            // Colour: twelve hues, then black and white. Selecting rings it in
            // ink and quiets the rest (Ryoku's "colour as data").
            Repeater {
                model: 13

                Rectangle {
                    id: sw

                    required property int index
                    readonly property int bucket: index < 12 ? index : 99
                    readonly property int selectedColour: root.store ? Wallhaven.colour : Wallpapers.filterColour
                    readonly property bool on: selectedColour === bucket

                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 22
                    radius: Tokens.rounding.small / 2
                    color: index < 12 ? root.swatches[index] : "transparent"
                    border.width: on ? 2 : index === 12 ? 1 : 0
                    border.color: Colours.palette.m3onSurface
                    opacity: on || swMouse.containsMouse || selectedColour === -1 ? 1 : 0.4
                    scale: on ? 1.15 : 1

                    // Black and white: half and half.
                    Rectangle {
                        visible: sw.index === 12
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.49
                                color: "#111111"
                            }
                            GradientStop {
                                position: 0.51
                                color: "#eeeeee"
                            }
                        }
                    }

                    Behavior on scale {
                        Anim {
                            duration: Tokens.anim.fast
                        }
                    }

                    MouseArea {
                        id: swMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.store)
                                Wallhaven.colour = sw.on ? -1 : sw.bucket;
                            else
                                Wallpapers.filterColour = sw.on ? -1 : sw.bucket;
                        }
                    }
                }
            }

            Item {
                width: Tokens.spacing.small
                height: 1
            }

            IconButton {
                visible: !root.store
                anchors.verticalCenter: parent.verticalCenter
                icon: Wallpapers.filterTone === "light" ? "light_mode" : Wallpapers.filterTone === "dark" ? "dark_mode" : "contrast"
                size: 30
                filled: Wallpapers.filterTone !== ""
                onClicked: Wallpapers.filterTone = Wallpapers.filterTone === "" ? "dark" : Wallpapers.filterTone === "dark" ? "light" : ""
            }

            IconButton {
                visible: !root.store
                anchors.verticalCenter: parent.verticalCenter
                icon: "star"
                size: 30
                filled: Wallpapers.filterFavourites
                onClicked: Wallpapers.filterFavourites = !Wallpapers.filterFavourites
            }
        }
    }

    // ── The view ──
    Loader {
        id: viewLoader

        anchors.top: filters.bottom
        anchors.topMargin: Tokens.spacing.normal
        anchors.bottom: parent.bottom
        width: parent.width
        sourceComponent: Wallpapers.view === "slice" ? slices : Wallpapers.view === "mosaic" ? mosaic : strip
        onLoaded: Qt.callLater(root.centreOnCurrent)
    }

    EmptyState {
        anchors.centerIn: viewLoader
        visible: root.walls.length === 0
        icon: "image_search"
        title: root.store ? (Wallhaven.loading ? "Searching Wallhaven…" : Wallhaven.error || "Nothing on Wallhaven matches") : Wallpapers.all.length === 0 ? "No wallpapers in ~/Pictures/Wallpapers" : "Nothing matches"
    }

    Component {
        id: strip

        StripView {
            model: root.walls
            onPicked: (i, close) => root.choose(close)
        }
    }

    Component {
        id: slices

        SliceView {
            model: root.walls
            onPicked: (i, close) => root.choose(close)
        }
    }

    Component {
        id: mosaic

        MosaicView {
            model: root.walls
            onPicked: (i, close) => root.choose(close)
        }
    }

    // The drawer is still growing when this loads: centre again once the
    // opening spring is done.
    Timer {
        running: true
        interval: 450
        onTriggered: root.centreOnCurrent()
    }
}
