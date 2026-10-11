pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.modules.bar.popouts
import "tabs"

// The dock and, grown up out of it, the command center: the search on top,
// the tabs down the side, the current tab beside them (fixed size; switching
// tabs cross-fades the content), and the dock as the base.
Item {
    id: root

    required property bool expanded
    property ShellScreen shellScreen

    readonly property int dockHeight: 72
    readonly property real dockWidth: dock.implicitWidth
    readonly property int pad: Tokens.spacing.large

    // Launcher state, shared with the search bar and the Apps tab.
    readonly property string query: ShellState.ccQuery
    readonly property string mode: query.startsWith(">") ? "command" : query.startsWith("=") ? "calc" : "apps"
    property int selected: 0
    readonly property var results: mode === "apps" ? Apps.search(query) : []

    readonly property var tabs: [
        { id: "home", icon: "home", label: "Home" },
        { id: "apps", icon: "apps", label: "Apps" },
        { id: "media", icon: "music_note", label: "Media" },
        { id: "audio", icon: "volume_up", label: "Audio" },
        { id: "display", icon: "light_mode", label: "Display" },
        { id: "system", icon: "monitoring", label: "System" },
        { id: "power", icon: "battery_full", label: "Power" },
        { id: "network", icon: "wifi", label: "Network" },
        { id: "bluetooth", icon: "bluetooth", label: "Bluetooth" },
        { id: "weather", icon: "partly_cloudy_day", label: "Weather" },
        { id: "calendar", icon: "calendar_month", label: "Calendar" },
        { id: "notifications", icon: "notifications", label: "Notifications" }
    ]

    function move(by: int): void {
        if (ShellState.ccTab !== "apps")
            ShellState.ccTab = "apps";
        if (results.length > 0)
            selected = (selected + by + results.length) % results.length;
    }

    function cycleTab(by: int): void {
        const i = tabs.findIndex(t => t.id === ShellState.ccTab);
        ShellState.ccTab = tabs[(i + by + tabs.length) % tabs.length].id;
    }

    function activate(): void {
        if (mode === "command") {
            const cmd = query.slice(1).trim();
            if (cmd)
                Quickshell.execDetached(["sh", "-c", cmd]);
        } else if (mode === "calc") {
            if (Calc.result)
                Noctalia.msg("clipboard-copy", Calc.result);
        } else {
            const app = results[selected];
            if (!app)
                return;
            Apps.launch(app);
        }
        ShellState.ccQuery = "";
        ShellState.close();
    }

    // (`mode` may not have caught up with `query` yet here.)
    onQueryChanged: {
        if (query.startsWith("="))
            Calc.evaluate(query.slice(1));
    }

    Connections {
        target: ShellState

        function onCcFocusChanged(): void {
            Qt.callLater(() => search.focusInput());
        }
    }

    // The command center, above the dock.
    Item {
        id: cc

        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        height: parent.height - root.dockHeight - root.pad
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                duration: Tokens.anim.fast
            }
        }

        SearchBar {
            id: search

            width: parent.width
            cc: root
        }

        Sidebar {
            id: sidebar

            anchors.top: search.bottom
            anchors.topMargin: Tokens.spacing.large
            anchors.bottom: parent.bottom
            width: 176
            tabs: root.tabs
        }

        // The current tab, cross-faded on change.
        Item {
            id: page

            property string shown: ShellState.ccTab

            anchors.top: search.bottom
            anchors.topMargin: Tokens.spacing.large
            anchors.left: sidebar.right
            anchors.leftMargin: Tokens.spacing.large
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Connections {
                target: ShellState

                function onCcTabChanged(): void {
                    swap.restart();
                }
            }

            SequentialAnimation {
                id: swap

                NumberAnimation {
                    target: loader
                    property: "opacity"
                    to: 0
                    duration: 80
                }
                ScriptAction {
                    script: page.shown = ShellState.ccTab
                }
                NumberAnimation {
                    target: loader
                    property: "opacity"
                    to: 1
                    duration: 160
                }
            }

            Loader {
                id: loader

                anchors.fill: parent
                onLoaded: Choreo.cascade(item?.contentItem ?? item, 40)
                active: root.expanded
                sourceComponent: ({
                        home: home,
                        apps: apps,
                        media: media,
                        audio: audio,
                        display: display,
                        system: system,
                        power: power,
                        network: network,
                        bluetooth: bluetooth,
                        weather: weather,
                        calendar: calendar,
                        notifications: notifications
                    })[page.shown] ?? home
            }

            Component {
                id: home

                HomeTab {}
            }
            Component {
                id: apps

                AppsTab {
                    cc: root
                }
            }
            Component {
                id: system

                SystemTab {}
            }
            Component {
                id: weather

                WeatherTab {}
            }
            Component {
                id: calendar

                CalendarTab {}
            }
            Component {
                id: media

                PopoutTab {
                    content: MediaPopout {}
                }
            }
            Component {
                id: audio

                PopoutTab {
                    content: AudioPopout {}
                }
            }
            Component {
                id: display

                PopoutTab {
                    content: BrightnessPopout {}
                }
            }
            Component {
                id: power

                PopoutTab {
                    content: BatteryPopout {}
                }
            }
            Component {
                id: network

                PopoutTab {
                    content: NetworkPopout {}
                }
            }
            Component {
                id: bluetooth

                PopoutTab {
                    content: BluetoothPopout {}
                }
            }
            Component {
                id: notifications

                PopoutTab {
                    content: NotificationsPopout {}
                }
            }
        }
    }

    DockBar {
        id: dock

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        expanded: root.expanded
    }
}
