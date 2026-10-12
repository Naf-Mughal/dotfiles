pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Quickshell
import qs.config
import qs.services
import qs.components

// A month at a time, Monday first, today highlighted.
Item {
    id: root

    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    readonly property date today: clock.date

    // The 42 days shown (six weeks from the Monday on or before the 1st).
    readonly property var days: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - ((first.getDay() + 6) % 7));
        return Array.from({
            length: 42
        }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
    }

    function shift(by: int): void {
        month = new Date(month.getFullYear(), month.getMonth() + by, 1);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Row {
        id: header

        width: parent.width
        spacing: Tokens.spacing.small

        StyledText {
            width: parent.width - 3 * (40 + Tokens.spacing.small)
            anchors.verticalCenter: parent.verticalCenter
            text: `${Qt.formatDate(root.month, "MMMM yyyy")}  ${Xian.numeral(root.month.getMonth() + 1)}月`
            font.family: Tokens.font.serif
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }

        IconButton {
            icon: "chevron_left"
            onClicked: root.shift(-1)
        }
        IconButton {
            icon: "today"
            onClicked: root.month = new Date(root.today.getFullYear(), root.today.getMonth(), 1)
        }
        IconButton {
            icon: "chevron_right"
            onClicked: root.shift(1)
        }
    }

    Grid {
        id: grid

        anchors.top: header.bottom
        anchors.topMargin: Tokens.spacing.large
        width: parent.width
        columns: 7

        readonly property real cell: width / 7
        readonly property real cellHeight: (root.height - header.height - Tokens.spacing.large - 28) / 6

        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

            StyledText {
                required property string modelData

                width: grid.cell
                height: 28
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                // The weekend in tertiary (Caelestia's calendar).
                color: modelData === "Sat" || modelData === "Sun" ? Colours.roleInk("tertiary", "ghost") : Colours.roleInk("primary", "ghost")
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        Repeater {
            model: root.days

            Item {
                id: day

                required property date modelData
                readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                readonly property bool isToday: modelData.toDateString() === root.today.toDateString()
                readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6

                width: grid.cell
                height: grid.cellHeight

                // Today on a sunny shape (Caelestia's calendar).
                MaterialShape {
                    visible: day.isToday
                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width, parent.height) - 2
                    shape: MaterialShape.Sunny
                    color: Colours.roleFill("primary", "strong", 0)
                }

                StyledText {
                    anchors.centerIn: parent
                    text: day.modelData.getDate()
                    color: day.isToday ? Colours.roleInk("primary", "strong") : !day.inMonth ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5) : day.weekend ? Colours.roleInk("tertiary", "ghost") : Colours.palette.m3onSurface
                    font.pixelSize: 14
                    font.weight: day.isToday ? Font.Bold : Font.Normal
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }
}
