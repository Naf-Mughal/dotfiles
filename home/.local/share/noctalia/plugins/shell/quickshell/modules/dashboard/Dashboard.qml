import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.modules.commandcenter.tabs

// The dashboard (Mod+Shift+D, or hover the top centre): Caelestia's, built
// from the shell's own parts. A Panel whose heading carries the tabs as a
// connected button group, and the tab below: the dashboard grid, media,
// performance, weather. The tab you were on is remembered.
Panel {
    id: root

    readonly property var tabs: [
        {
            value: "dash",
            icon: "dashboard",
            label: "Dashboard"
        },
        {
            value: "media",
            icon: "queue_music",
            label: "Media"
        },
        {
            value: "performance",
            icon: "speed",
            label: "Performance"
        },
        {
            value: "weather",
            icon: "cloud",
            label: "Weather"
        }
    ]

    icon: "space_dashboard"
    title: "Dashboard"
    gloss: "总览"
    subtitle: Qt.formatDateTime(clock.date, "dddd d MMMM")
    actions: [
        ButtonGroup {
            model: root.tabs
            current: ShellState.dashTab
            onSelected: value => ShellState.dashTab = value
        }
    ]

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Loader {
        width: parent.width
        height: 420
        sourceComponent: ShellState.dashTab === "media" ? media : ShellState.dashTab === "performance" ? performance : ShellState.dashTab === "weather" ? weather : dash
    }

    Component {
        id: dash

        DashTab {}
    }

    Component {
        id: media

        MediaTab {}
    }

    Component {
        id: performance

        PerformanceTab {}
    }

    Component {
        id: weather

        Surface {
            level: 2

            WeatherTab {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.large
            }
        }
    }
}
