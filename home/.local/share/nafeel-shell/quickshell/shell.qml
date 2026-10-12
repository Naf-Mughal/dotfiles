//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// One render thread for every window: ~30 MB less than the threaded loop.
//@ pragma DefaultEnv QSG_RENDER_LOOP=basic

// nafeel shell: every on-screen surface of the desktop (frame, bar, drawers,
// dock, command center…) in one Quickshell process, on top of umbriel and
// Noctalia's services. Started and themed by the nafeel/shell Noctalia plugin.

import QtQuick
import Quickshell
import Nafeel
import qs.services
import qs.modules.frame
import qs.modules.lock
import qs.modules.capture
import qs.modules.background
import qs.modules.idle
import qs.modules.overview

ShellRoot {
    settings.watchFiles: true

    // The clipboard keeps its history from the start, not only once a panel
    // first shows it.
    readonly property var clipboard: Clipboard
    // The theme follows the wallpaper from the start.
    readonly property var theme: Theme
    // Wallpaper rotation runs whether or not the picker has been opened.
    readonly property var rotation: WallpaperRotation
    // Idle management (dim, lock, screen off, suspend) from the start.
    readonly property var idle: Idle
    // Notes take a jot (IPC, launcher) without the drawer open.
    readonly property var notes: NotesStore
    // The lock locks before every sleep from the start (CaveAbode's watcher),
    // and the battery's saver and warnings run whether or not a panel shows.
    readonly property var lockLook: CaveAbode
    readonly property var power: Power
    // Qt apps' theming and the default apps are applied at login too.
    readonly property var appTheming: AppTheming
    readonly property var defaultApps: DefaultApps
    // The login screen shows the shell's world: kept up to date from here.
    readonly property var greeterExport: GreeterExport

    Background {}
    GraceOverlay {}
    Frame {}
    Picker {}
    Annotator {}
    OverviewCapture {}
    Lock {}
}
