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
        slide.stop();
        contentX = target(i);
    }

    // Where the band sits with slice i open in the middle: from where the
    // list has actually laid it out (originX is only an estimate with
    // slices of two widths). The ends are padded (header, footer) so the
    // first and last can come to the middle too.
    readonly property real pitch: sliceWidth + spacing
    function target(i: int): real {
        let it = itemAtIndex(i);
        if (!it) {
            positionViewAtIndex(i, ListView.Center);
            it = itemAtIndex(i);
        }
        return it ? it.x + expandedWidth / 2 - width / 2 : contentX;
    }

    onCurrentIndexChanged: {
        if (moving)
            return;
        slide.to = target(currentIndex);
        slide.restart();
    }
    // The band's size settles as the drawer opens (the slices scale with
    // it): keep the selected one in the middle meanwhile.
    onPitchChanged: _recentre()
    onWidthChanged: _recentre()
    function _recentre(): void {
        if (moving || slide.running)
            return;
        contentX = target(currentIndex);
    }

    // A flick settles on the slice nearest the middle.
    onMovementEnded: {
        const i = Math.max(0, Math.min(count - 1, indexAt(contentX + width / 2, height / 2)));
        if (i !== currentIndex)
            currentIndex = i;
        else {
            slide.to = target(i);
            slide.restart();
        }
    }

    NumberAnimation {
        id: slide

        target: root
        property: "contentX"
        duration: Tokens.dur(420)
        easing.type: Easing.OutCubic
        onFinished: root._recentre()
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
        readonly property bool chosen: modelData.path === Wallpapers.chosen
        readonly property bool hovered: hover.hovered
        // Fade the far ends of the band (Ryoku's viewport falloff).
        readonly property real dist: Math.abs(x + width / 2 - (root.contentX + root.width / 2)) / (root.width / 2)

        width: isCurrent ? root.expandedWidth : root.sliceWidth
        height: root.height
        z: isCurrent ? 100 : hovered ? 90 : 50 - Math.min(Math.abs(index - root.currentIndex), 50)
        opacity: dist <= 0.7 ? 1 : Math.max(0, 1 - (dist - 0.7) / 0.45)

        Behavior on width {
            NumberAnimation {
                duration: Tokens.dur(420)
                easing.type: Easing.OutCubic
            }
        }

        // The picture at the slice's size (cropped), as the shader's texture.
        Image {
            id: img

            width: slice.width
            height: slice.height
            source: slice.modelData.thumb ? "file://" + slice.modelData.thumb : "file://" + slice.modelData.path
            sourceSize: Qt.size(Math.round(root.expandedWidth), Math.round(root.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        ShaderEffectSource {
            id: tex

            sourceItem: img
            hideSource: true
            visible: false
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
