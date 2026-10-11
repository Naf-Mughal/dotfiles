pragma Singleton

// Shell extensions: every feature (built in or your own) is a folder with a
// module.json, loaded into a named slot.
//
//   extensions/<id>/module.json   { "id", "name", "slot", "entry", "order" }
//
// Folders are read from the shell's own extensions/ and from
// ~/.config/nafeel-shell/extensions/ (yours; same id overrides a built-in).
// An extension's entry is a QML file whose root may declare
// `property ShellScreen shellScreen` to learn which screen it is on.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property list<string> dirs: [
        Quickshell.shellDir + "/extensions",
        Quickshell.env("HOME") + "/.config/nafeel-shell/extensions",
    ]

    property var modules: []

    function forSlot(slot: string): var {
        return modules.filter(m => m.slot === slot).sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
    }

    function rescan(): void {
        scan.running = true;
    }

    Process {
        id: scan

        running: true
        // One manifest per line: "<dir>\t<json on one line>".
        command: ["sh", "-c", 'for d in "$@"; do for f in "$d"/*/module.json; do [ -f "$f" ] && printf "%s\\t%s\\n" "${f%/module.json}" "$(tr -d "\\n" < "$f")"; done; done', "sh", root.dirs[0], root.dirs[1]]

        stdout: StdioCollector {
            onStreamFinished: {
                const byId = {};
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const dir = line.slice(0, tab);
                    try {
                        const m = JSON.parse(line.slice(tab + 1));
                        m.dir = dir;
                        m.url = "file://" + dir + "/" + m.entry;
                        byId[m.id ?? dir] = m;
                    } catch (e) {
                        console.warn("extensions: bad module.json in", dir, e);
                    }
                }
                root.modules = Object.values(byId);
            }
        }
    }
}
