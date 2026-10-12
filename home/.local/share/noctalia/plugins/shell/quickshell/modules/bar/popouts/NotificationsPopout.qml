pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.notifications
import qs.config
import qs.services
import qs.components

// Notification history, newest first, with do not disturb and clear all in
// the header. Showing it marks everything seen.
Panel {
    id: root


    Component.onCompleted: Notifs.markSeen()

    PopoutHeader {
        width: parent.width
        gloss: Xian.gloss.notifications
        icon: Notifs.dnd ? "notifications_off" : "notifications"
        title: "Notifications"
        subtitle: Notifs.history.length > 0 ? `${Notifs.history.length} in history` : "All caught up"

        Row {
            spacing: Tokens.spacing.small

            IconButton {
                icon: "do_not_disturb_on"
                filled: Notifs.dnd
                size: 36
                onClicked: Notifs.toggleDnd()
            }

            IconButton {
                icon: "clear_all"
                size: 36
                onClicked: Notifs.clear()
            }
        }
    }

    EmptyState {
        width: parent.width
        visible: Notifs.history.length === 0
        icon: "notifications_paused"
        title: "All quiet"
        hint: Notifs.dnd ? "Do not disturb is on" : "No messages have arrived"
    }

    Scroller {
        width: parent.width
        height: Math.min(cards.implicitHeight, 460)
        visible: Notifs.history.length > 0
        contentHeight: cards.implicitHeight
        clip: true

        Column {
            id: cards

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: Notifs.history

                NotificationCard {
                    required property var modelData

                    width: cards.width
                    entry: modelData
                }
            }
        }
    }
}
