import QtQuick
import Quickshell
import qs.services

// Lays out every extension registered for `slot`, top to bottom.
Column {
    id: root

    required property string slot
    property ShellScreen shellScreen

    Repeater {
        model: Extensions.forSlot(root.slot)

        Loader {
            required property var modelData

            // The slot's width, when it has one (a bar capsule), so an
            // extension can lay itself out across it.
            width: root.width > 0 ? root.width : undefined
            anchors.horizontalCenter: parent?.horizontalCenter
            Component.onCompleted: setSource(modelData.url, {
                shellScreen: root.shellScreen
            })
        }
    }
}
