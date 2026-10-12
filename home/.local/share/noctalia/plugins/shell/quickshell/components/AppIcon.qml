import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services

// An app's icon in the shell's look, every one the same size on the shell's
// rounding and coloured from the palette, so it changes with the theme:
//   "themed"   a tile in the app kind's colour role with its symbol (a
//              browser's globe, a terminal's prompt, a folder for the file
//              manager: from the desktop entry's categories, Apps.kind);
//              an app of no known kind gets its own icon, tinted, on the tile
//   "tinted"   every app's own icon, tinted to the tile's ink
//   "original" the app's own icon as it is
// The style is the Dock page's icon style unless set.
Item {
    id: root

    required property string appId
    property int size: 44
    property string style: Dock.settings.v["dock.iconStyle"]
    property bool hovered: false

    readonly property var kind: Apps.kind(appId)
    readonly property bool tile: style !== "original"
    readonly property bool glyph: style === "themed" && kind !== null

    implicitWidth: size
    implicitHeight: size

    Surface {
        id: sheet

        anchors.fill: parent
        visible: root.tile
        role: root.kind?.role ?? "secondary"
        emphasis: root.hovered ? "strong" : "soft"

        MaterialIcon {
            anchors.centerIn: parent
            visible: root.glyph
            text: root.kind?.glyph ?? ""
            size: Math.round(root.size * 0.5)
            fill: 1
            color: sheet.ink
        }
    }

    IconImage {
        id: own

        anchors.centerIn: parent
        implicitSize: root.tile ? Math.round(root.size * 0.6) : root.size
        source: Apps.icon(root.appId)
        visible: !root.glyph && !root.tile
    }

    // On a tile, the app's own icon in the tile's ink.
    MultiEffect {
        anchors.fill: own
        visible: root.tile && !root.glyph
        source: own
        colorization: 1
        colorizationColor: sheet.ink
        brightness: 0.1
    }
}
