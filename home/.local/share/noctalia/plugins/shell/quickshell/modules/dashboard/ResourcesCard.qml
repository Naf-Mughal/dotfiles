import QtQuick
import qs.config
import qs.services
import qs.components

// Resources (Caelestia's): the processor, memory and storage as rings with
// their icons, one above another.
Surface {
    id: root

    level: 2
    implicitWidth: 120

    Component.onCompleted: SystemStats.watchers++
    Component.onDestruction: SystemStats.watchers--

    Column {
        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        Repeater {
            model: [
                {
                    icon: "memory",
                    value: SystemStats.cpu,
                    role: "primary"
                },
                {
                    icon: "memory_alt",
                    value: SystemStats.mem,
                    role: "secondary"
                },
                {
                    icon: "hard_drive",
                    value: SystemStats.disk,
                    role: "tertiary"
                }
            ]

            CircularProgress {
                id: ring

                required property var modelData

                implicitSize: Math.min(92, (root.height - Tokens.spacing.normal * 4) / 3)
                strokeWidth: 6
                startAngle: -90
                sweepAngle: 360
                value: modelData.value
                fg: Colours.roleInk(modelData.role, "ghost")

                MaterialIcon {
                    anchors.centerIn: parent
                    text: ring.modelData.icon
                    size: ring.width * 0.34
                    color: Colours.roleInk(ring.modelData.role, "ghost")
                }
            }
        }
    }
}
