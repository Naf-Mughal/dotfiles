import QtQuick
import M3Shapes
import qs.config
import qs.services
import qs.components

// You (Caelestia's user card): a gem with the system's mark, your face in a
// pill (~/.face; a person when there's none), a thought bubble with the
// compositor, and the uptime beside a clamshell.
Surface {
    id: root

    level: 2

    // The face, in a pill.
    ShapeImage {
        id: face

        anchors.left: gem.right
        anchors.leftMargin: -12
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.normal
        width: height
        source: "file://" + Session.home + "/.face"
        shape: MaterialShape.Pill
        icon: "person"
        fill: Colours.roleFill("paper", "soft", 4)
    }

    // The mark, on a gem, overlapping the face.
    ShapeBadge {
        id: gem

        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 58
        shape: MaterialShape.Gem
        role: "primary"
        icon: "terminal"
        z: 1
    }

    // The thought bubble: two dots up to the compositor's name.
    Rectangle {
        id: dot1

        anchors.left: face.right
        anchors.leftMargin: 2
        anchors.verticalCenter: face.verticalCenter
        anchors.verticalCenterOffset: -6
        width: 10
        height: 10
        radius: 5
        color: Colours.roleFill("secondary", "soft", 0)
    }

    Rectangle {
        id: dot2

        anchors.left: dot1.right
        anchors.leftMargin: 3
        anchors.bottom: dot1.top
        width: 15
        height: 15
        radius: 8
        color: Colours.roleFill("secondary", "soft", 0)
    }

    Surface {
        id: wm

        anchors.left: dot2.right
        anchors.bottom: dot2.top
        anchors.bottomMargin: -4
        width: wmRow.implicitWidth + 24
        height: 34
        role: "secondary"
        emphasis: "soft"
        shape: "full"

        Row {
            id: wmRow

            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "select_window"
                size: 16
                color: wm.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: `umbriel · ${Session.realName || Session.user}`
                color: wm.ink
                font.pixelSize: Tokens.font.small
            }
        }
    }

    // Uptime, on a clamshell.
    ShapeBadge {
        id: clam

        anchors.left: face.right
        anchors.leftMargin: -18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        implicitSize: 42
        shape: MaterialShape.ClamShell
        role: "tertiary"
        icon: "schedule"
        z: 1
    }

    StyledText {
        anchors.left: clam.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.verticalCenter: clam.verticalCenter
        text: `up ${Session.formatUptime()}`
        color: root.ink
        font.pixelSize: Tokens.font.row
    }
}
