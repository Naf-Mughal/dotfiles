pragma Singleton

// The shell's settings: one file the shell owns,
// ~/.config/nafeel-shell/settings.json, read and written here, applied live
// (edits from outside are picked up too).
//
// Settings are declared next to the feature they belong to, as a
// SettingsPage of SettingItems (key, kind, label, default), and read back
// from that page (`page.v.<key>`): the default lives in one place. The
// Settings panel builds a page per declaration. Keys are flat; a feature's
// own prefix ("idle.…") keeps them apart.
//
//   readonly property SettingsPage settings: SettingsPage {
//       name: "weather"; title: "Weather"; gloss: "天气"; icon: "partly_cloudy_day"
//       SettingItem { key: "location"; kind: "text"; label: "Place"; def: "" }
//   }
//   … settings.v.location …
//
// The first run takes the values the Noctalia plugin used to write
// (~/.local/state/nafeel-shell/settings.json).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/nafeel-shell`
    readonly property string path: dir + "/settings.json"

    // What's stored: only what has been set (defaults stay with the
    // declarations).
    property var values: ({})
    property bool loaded: false
    // Every declared page, in panel order.
    property var pages: []

    function set(key: string, value: var): void {
        if (values[key] === value)
            return;
        const next = Object.assign({}, values);
        next[key] = value;
        values = next;
        save();
    }

    // Back to the declared default.
    function reset(key: string): void {
        if (!(key in values))
            return;
        const next = Object.assign({}, values);
        delete next[key];
        values = next;
        save();
    }

    function save(): void {
        file.setText(JSON.stringify(values, null, 2) + "\n");
    }

    function register(page: QtObject): void {
        if (pages.includes(page))
            return;
        const next = pages.concat([page]);
        next.sort((a, b) => a.order - b.order);
        pages = next;
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])

    // qs ipc call settings get <key> | set <key> <value> | reset <key> | list
    // (a value that reads as JSON is taken as JSON: true, 85, "x").
    IpcHandler {
        target: "settings"

        function get(key: string): string {
            for (const page of root.pages)
                if (key in page.v)
                    return JSON.stringify(page.v[key]);
            return JSON.stringify(root.values[key] ?? null);
        }

        function set(key: string, value: string): void {
            let v = value;
            try {
                v = JSON.parse(value);
            } catch (e) {}
            root.set(key, v);
        }

        function reset(key: string): void {
            root.reset(key);
        }

        function list(): string {
            return root.pages.map(p => `${p.name}: ${Array.from(p.items).map(i => i.key).join(", ")}`).join("\n");
        }
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.values = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn(`settings: ${root.path} isn't valid JSON; keeping what was loaded`);
            }
            root.loaded = true;
        }
        // First run: what the Noctalia plugin wrote, carried over.
        onLoadFailed: legacy.reload()
    }

    FileView {
        id: legacy

        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/settings.json"
        printErrors: false
        onLoaded: {
            try {
                root.values = JSON.parse(text()) ?? {};
            } catch (e) {}
            root.loaded = true;
            root.save();
        }
        onLoadFailed: root.loaded = true
    }
}
