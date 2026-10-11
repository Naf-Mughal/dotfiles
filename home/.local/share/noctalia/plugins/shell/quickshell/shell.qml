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
import qs.modules.frame
import qs.modules.lock
import qs.modules.capture
import qs.modules.background

ShellRoot {
    settings.watchFiles: true

    // The clipboard keeps its history from the start, not only once a panel
    // first shows it.
    readonly property var clipboard: Clipboard

    Background {}
    Frame {}
    Picker {}
    Lock {}
}
