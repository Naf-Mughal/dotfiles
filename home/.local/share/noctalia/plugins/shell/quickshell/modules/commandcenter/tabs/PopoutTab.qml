import QtQuick

// A bar popout as a command center tab: centred, scrolling if it's taller
// than the tab.
Flickable {
    id: root

    property Component content

    contentHeight: loader.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Loader {
        id: loader

        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width, 520)
        sourceComponent: root.content
    }
}
