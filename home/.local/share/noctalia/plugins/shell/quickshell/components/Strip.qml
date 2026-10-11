import QtQuick
import qs.config

// A scrolling row (or column) of things: chips, cards, wallpapers, windows.
// The wheel scrolls it either way, it clips to itself, and with `centred`
// the current item is kept in the middle (a carousel).
ListView {
    id: root

    property bool centred: false
    // Pixels per wheel notch; `wheelScrolls: false` leaves the wheel to the
    // owner (a carousel that steps its selection instead).
    property real wheelStep: 8
    property bool wheelScrolls: true

    orientation: ListView.Horizontal
    spacing: Tokens.spacing.normal
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: centred
    highlightMoveDuration: Tokens.anim.normal
    highlightRangeMode: centred ? ListView.ApplyRange : ListView.NoHighlightRange
    preferredHighlightBegin: centred ? (orientation === ListView.Horizontal ? width : height) / 2 - (currentItem ? (orientation === ListView.Horizontal ? currentItem.width : currentItem.height) / 2 : 0) : 0
    preferredHighlightEnd: centred ? (orientation === ListView.Horizontal ? width : height) / 2 + (currentItem ? (orientation === ListView.Horizontal ? currentItem.width : currentItem.height) / 2 : 0) : 0

    WheelHandler {
        enabled: root.wheelScrolls
        orientation: Qt.Vertical
        onWheel: event => {
            const d = event.angleDelta.y * root.wheelStep;
            if (root.orientation === ListView.Horizontal)
                root.flick(d, 0);
            else
                root.flick(0, d);
        }
    }
}
