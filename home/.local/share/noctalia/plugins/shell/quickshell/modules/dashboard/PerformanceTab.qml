import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components

// Performance (Caelestia's): the processor as the hero (load, its history,
// temperature, the GPU), then memory, storage, network and the battery.
GridLayout {
    id: root

    columns: 3
    rowSpacing: Tokens.spacing.normal
    columnSpacing: Tokens.spacing.normal

    Component.onCompleted: SystemStats.watchers++
    Component.onDestruction: SystemStats.watchers--

    // ── CPU, the hero ──
    Surface {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        level: 2

        Row {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.large

            Gauge {
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                height: 140
                value: SystemStats.cpu
                text: `${Math.round(SystemStats.cpu * 100)}%`
                label: "CPU"
                warn: SystemStats.cpu > 0.9
            }

            Column {
                width: parent.width - 140 - Tokens.spacing.large
                height: parent.height
                spacing: Tokens.spacing.small

                Row {
                    spacing: Tokens.spacing.large

                    Stat {
                        icon: "device_thermostat"
                        value: `${Math.round(SystemStats.temp)}°C`
                        label: "temperature"
                        warn: SystemStats.temp >= 85
                    }

                    Stat {
                        visible: SystemStats.gpu >= 0
                        icon: "developer_board"
                        value: `${Math.round(SystemStats.gpu * 100)}%`
                        label: "GPU"
                    }
                }

                Sparkline {
                    width: parent.width
                    height: parent.height - 60
                    values: SystemStats.cpuHistory
                    max: 1
                }
            }
        }
    }

    // ── Memory ──
    Surface {
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        level: 2

        Column {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            Gauge {
                anchors.horizontalCenter: parent.horizontalCenter
                value: SystemStats.mem
                text: SystemStats.bytes(SystemStats.memUsed)
                label: `of ${SystemStats.bytes(SystemStats.memTotal)}`
                warn: SystemStats.mem > 0.9
            }

            MicroLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: SystemStats.swapTotal > 0
                text: `swap ${SystemStats.bytes(SystemStats.swapUsed)} / ${SystemStats.bytes(SystemStats.swapTotal)}`
            }
        }
    }

    // ── Storage ──
    Surface {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        level: 2

        Column {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.small

            Stat {
                icon: "hard_drive"
                value: `${SystemStats.bytes(SystemStats.diskUsed)}`
                label: `used of ${SystemStats.bytes(SystemStats.diskTotal)} on /`
            }

            Bar {
                width: parent.width
                value: SystemStats.disk
            }
        }
    }

    // ── Network ──
    Surface {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        level: 2

        Column {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            spacing: Tokens.spacing.small

            Row {
                spacing: Tokens.spacing.large

                Stat {
                    icon: "south"
                    value: `${SystemStats.bytes(SystemStats.rx)}/s`
                    label: "down"
                }

                Stat {
                    icon: "north"
                    value: `${SystemStats.bytes(SystemStats.tx)}/s`
                    label: "up"
                }
            }

            Item {
                width: parent.width
                height: parent.height - 50

                Sparkline {
                    anchors.fill: parent
                    values: SystemStats.rxHistory
                }

                Sparkline {
                    anchors.fill: parent
                    values: SystemStats.txHistory
                    max: Math.max(1, ...SystemStats.rxHistory, ...SystemStats.txHistory)
                    colour: Colours.roleInk("tertiary", "ghost")
                }
            }
        }
    }

    // ── Battery, as a tank ──
    Surface {
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        level: 2

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.large

            Rectangle {
                id: tank

                width: 46
                height: 100
                radius: 10
                color: Colours.roleFill("secondary", "soft", 0)
                border.width: 2
                border.color: Colours.palette.m3outlineVariant

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 4
                    height: (parent.height - 8) * Power.level
                    radius: 6
                    color: Colours.roleFill(Power.low ? "error" : Power.charging ? "tertiary" : "primary", "strong", 0)

                    Behavior on height {
                        Anim {}
                    }
                }

                MaterialIcon {
                    visible: Power.charging
                    anchors.centerIn: parent
                    text: "bolt"
                    fill: 1
                    size: 22
                    color: Colours.roleInk(Power.low ? "error" : Power.charging ? "tertiary" : "primary", "strong")
                }
            }

            Stat {
                anchors.verticalCenter: parent.verticalCenter
                icon: "battery_full"
                value: Power.hasBattery ? `${Math.round(Power.level * 100)}%` : "AC"
                label: !Power.hasBattery ? "no battery" : Power.charging ? (Power.timeToFull > 0 ? `full in ${Math.round(Power.timeToFull / 60)} min` : "charging") : (Power.timeToEmpty > 0 ? `${Math.floor(Power.timeToEmpty / 3600)} h ${Math.round(Power.timeToEmpty % 3600 / 60)} min left` : "on battery")
            }
        }
    }

    // A reading: a list row (icon, the value as its title, what it is).
    component Stat: ListRow {
        property string value
        property string label
        property bool warn

        width: 210
        title: value
        subtitle: label
        iconFill: warn ? 1 : 0
    }

    // A level, in the primary role over its soft track (error when high).
    component Bar: Rectangle {
        property real value

        height: 10
        radius: 5
        color: Colours.roleFill("secondary", "soft", 0)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            height: parent.height
            radius: 5
            color: Colours.roleFill(parent.value > 0.9 ? "error" : "primary", "strong", 0)
        }
    }
}
