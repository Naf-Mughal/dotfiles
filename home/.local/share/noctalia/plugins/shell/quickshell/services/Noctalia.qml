pragma Singleton

// Noctalia, over its IPC (`noctalia msg …`), for what the shell leaves to it.

import QtQuick
import Quickshell

Singleton {
    function msg(...args): void {
        Quickshell.execDetached(["noctalia", "msg", ...args]);
    }

    // An event for a plugin service entry, e.g. ("nafeel/shell:service", "capture", "{…}").
    function plugin(entry: string, event: string, payload: string): void {
        Quickshell.execDetached(["noctalia", "msg", "plugin", entry, "all", event, payload ?? ""]);
    }
}
