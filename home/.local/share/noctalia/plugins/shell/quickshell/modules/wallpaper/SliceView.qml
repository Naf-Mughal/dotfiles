pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// The slice carousel (after Ryoku's SliceDelegate and its slice list, MIT):
// the library as slanted strips leaning against each other, the selected one
// opened wide in the middle. Moving the selection slides the band and the
// strips open and close around it. Each slice is one shader (shaders/
// slice.frag: the slanted rounded cut, dimming, rim, shadow) rather than
// Ryoku's shape-mask layers.
//
// Ryoku's proportions: expanded 924 : slice 135, overlap -30, lean 35.
ListView {
    id: root

    signal picked(int index, bool close)

    readonly property real expandedWidth: Math.min(width * 0.62, height * 16 / 9)
    readonly property real sliceWidth: Math.round(expandedWidth * 0.146)
    readonly property real skew: Math.round(sliceWidth * 0.26)
    readonly property real pad: 16

    function move(dx: int, dy: int): void {
        const by = dx + dy;
        if (count > 0)
            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + by));
    }

    function centreOn(i: int): void {
        if (i < 0 || i >= count)
            return;
        currentIndex = i;
        travel.stop();
        pos = i;
        follow();
    }

    // One value drives the band (Ryoku's single scroll): `pos`, the open
    // slice as a fractional index. Each slice's width comes from how near
    // it is to pos, and the band is scrolled so pos sits in the middle,
    // every frame, so the opening, closing and sliding can't drift apart
    // (going forward, the slice that closes moves everything after it).
    property real pos: 0

    function weight(i: int): real {
        return Math.max(0, 1 - Math.abs(i - pos));
    }

    // Scroll so pos is in the middle: between the centres of the two slices
    // either side of it, as they're laid out now.
    function follow(): void {
        if (count === 0 || moving)
            return;
        const a = Math.max(0, Math.min(count - 1, Math.floor(pos)));
        const b = Math.min(count - 1, a + 1);
        let ia = itemAtIndex(a);
        if (!ia) {
            positionViewAtIndex(a, ListView.Center);
            ia = itemAtIndex(a);
        }
        if (!ia)
            return;
        // Slices before a are all closed, so a's left edge is settled; the
        // two open-ish widths come from pos itself (not from the layout,
        // which catches up a frame later).
        const f = b === a ? 0 : pos - a;
        const grow = expandedWidth - sliceWidth;
        const wa = sliceWidth + grow * (1 - f);
        const wb = sliceWidth + grow * f;
        const centre = ia.x + (1 - f) * (wa / 2) + f * (wa + spacing + wb / 2);
        contentX = centre - width / 2;
    }

    onPosChanged: follow()
    onPitchChanged: Qt.callLater(follow)
    onWidthChanged: Qt.callLater(follow)

    onCurrentIndexChanged: {
        if (moving)
            return;
        travel.to = currentIndex;
        travel.restart();
    }

    // A flick settles on the slice nearest the middle, from where it is.
    onMovementEnded: {
        const mid = contentX + width / 2;
        const i = Math.max(0, Math.min(count - 1, indexAt(mid, height / 2)));
        const it = itemAtIndex(i);
        pos = it ? i + (mid - (it.x + it.width / 2)) / pitch : i;
        if (i !== currentIndex)
            currentIndex = i;
        else {
            travel.to = i;
            travel.restart();
        }
    }

    readonly property real pitch: sliceWidth + spacing

    NumberAnimation {
        id: travel

        target: root
        property: "pos"
        duration: Tokens.dur(420)
        easing.type: Easing.OutCubic
    }

    header: Item {
        width: root.width / 2 - root.expandedWidth / 2
        height: 1
    }
    footer: Item {
        width: root.width / 2 - root.expandedWidth / 2
        height: 1
    }

    orientation: ListView.Horizontal
    spacing: -Math.round(sliceWidth * 0.22)
    clip: false
    cacheBuffer: Math.round(sliceWidth * 6)
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 1500
    highlightFollowsCurrentItem: false
    keyNavigationEnabled: false

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.move(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1, 0)
    }

    delegate: Item {
        id: slice

        required property var modelData
        required property int index

        readonly property bool isCurrent: ListView.isCurrentItem
        readonly property bool current: modelData.path === Wallpapers.current
        readonly property bool chosen: (modelData.path ?? "") !== "" && modelData.path === Wallpapers.chosen
        readonly property bool hovered: hover.hovered
        // Fade the far ends of the band (Ryoku's viewport falloff).
        readonly property real dist: Math.abs(x + width / 2 - (root.contentX + root.width / 2)) / (root.width / 2)

        width: root.sliceWidth + (root.expandedWidth - root.sliceWidth) * root.weight(index)
        height: root.height
        z: isCurrent ? 100 : hovered ? 90 : 50 - Math.min(Math.abs(index - root.currentIndex), 50)
        opacity: dist <= 0.7 ? 1 : Math.max(0, 1 - (dist - 0.7) / 0.45)

        // The picture at the slice's size (cropped), as the shader's texture:
        // the thumbnail, and in the open slice the file itself decoded at the
        // slice's real size on top (a 480 px thumbnail or the store's 300 px
        // preview stretched across ~900 px looked grainy).
        Item {
            id: pic

            width: slice.width
            height: slice.height
            visible: false

            Image {
                id: img

                anchors.fill: parent
                source: Wallpapers.picture(slice.modelData)
                sourceSize: Qt.size(Math.round(root.expandedWidth), Math.round(root.height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Loader {
                anchors.fill: parent
                // Open (or opening) only: one full image at a time.
                active: slice.isCurrent
                sourceComponent: Image {
                    readonly property real dpr: root.Window.window?.devicePixelRatio ?? 1

                    source: slice.modelData.remote ? (slice.modelData.full ?? "") : slice.modelData.path ? "file://" + slice.modelData.path : ""
                    sourceSize: Qt.size(Math.round(root.expandedWidth * dpr), Math.round(root.height * dpr))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.anim.normal
                        }
                    }
                }
            }
        }

        ShaderEffectSource {
            id: tex

            sourceItem: pic
            hideSource: true
            visible: false
            smooth: true
        }

        ShaderEffect {
            x: -root.pad
            y: -root.pad
            width: slice.width + 2 * root.pad
            height: slice.height + 2 * root.pad
            visible: img.status === Image.Ready && slice.opacity > 0.01

            property var source: tex
            property size size: Qt.size(width, height)
            property real pad: root.pad
            property real skew: root.skew
            property real radius: Tokens.rounding.normal
            property real dim: slice.isCurrent ? 0 : slice.hovered ? 0.15 : 0.42
            property color rim: slice.current ? Colours.palette.m3primary : slice.chosen ? Colours.palette.m3tertiary : slice.isCurrent ? Qt.alpha(Colours.palette.m3onSurface, 0.85) : "transparent"
            property real rimWidth: slice.isCurrent || slice.chosen ? 2.5 : 2
            property real shadow: slice.isCurrent ? 0.5 : 0.28

            Behavior on dim {
                NumberAnimation {
                    duration: Tokens.anim.normal
                }
            }

            fragmentShader: Qt.resolvedUrl("../../shaders/slice.frag.qsb")
        }

        // While the thumbnail loads: the slice's shape in paper.
        Rectangle {
            visible: img.status !== Image.Ready
            anchors.fill: parent
            radius: Tokens.rounding.normal
            color: Colours.palette.m3surfaceContainerHigh
            opacity: 0.6
        }

        // Seals in the open slice: 選 chosen (top left, past the lean), 印
        // current (bottom right, before it).
        Seal {
            visible: slice.chosen && slice.width > root.sliceWidth * 2
            x: root.skew + Tokens.spacing.normal
            y: Tokens.spacing.normal
            glyph: "選"
            size: 22
        }

        Seal {
            visible: slice.current && slice.width > root.sliceWidth * 2
            x: slice.width - root.skew - width - Tokens.spacing.normal
            y: slice.height - height - Tokens.spacing.normal
            glyph: "印"
            size: 22
        }

        // The open slice's pigments and its favourite star.
        Row {
            visible: slice.isCurrent && slice.width > root.sliceWidth * 2 && (slice.modelData.colours?.length ?? 0) > 0
            x: Tokens.spacing.normal + 4
            y: slice.height - height - Tokens.spacing.normal - 2
            spacing: 4

            Repeater {
                model: slice.modelData.colours ?? []

                Rectangle {
                    required property string modelData

                    width: 11
                    height: 11
                    radius: 6
                    color: modelData
                    border.width: 1
                    border.color: Qt.alpha("black", 0.5)
                }
            }
        }

        MaterialIcon {
            readonly property bool fav: Wallpapers.favourites[slice.modelData.path] ?? false

            visible: slice.width > root.sliceWidth * 2 && (fav || slice.hovered)
            x: slice.width - width - Tokens.spacing.normal - 2
            y: Tokens.spacing.normal
            text: "star"
            fill: fav ? 1 : 0
            size: 20
            color: fav ? Colours.palette.m3primary : "white"
            style: Text.Outline
            styleColor: Qt.alpha("black", 0.5)

            TapHandler {
                onTapped: Wallpapers.toggleFavourite(slice.modelData.path)
            }
        }

        // A store result: resolution and download state, in the open slice.
        StoreBadge {
            visible: (slice.modelData.remote ?? false) && slice.width > root.sliceWidth * 2
            x: root.skew
            width: slice.width - 2 * root.skew
            height: slice.height
            wall: slice.modelData
        }

        // Hits only inside the slant.
        containmentMask: QtObject {
            function contains(point: point): bool {
                const t = 1 - point.y / slice.height;
                const left = root.skew * t;
                const right = slice.width - root.skew + root.skew * t;
                return point.y >= 0 && point.y <= slice.height && point.x >= left && point.x <= right;
            }
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                root.currentIndex = slice.index;
                root.picked(slice.index, false);
            }
            onDoubleTapped: {
                root.currentIndex = slice.index;
                root.picked(slice.index, true);
            }
        }
    }
}
