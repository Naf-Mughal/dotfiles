pragma Singleton

// The kernel's plugin registry. The shell is a kernel (the frame and its
// drawers, Settings, the primitives, the Bus, the theme, umbriel, IPC) and
// every feature on it is a plugin: a folder in plugins/ with a manifest.
//
//   plugins/<id>/plugin.json
//     { "id", "name", "gloss", "icon", "description",
//       "default": true,            on unless switched off on the Plugins page
//       "root": "Plugin.qml",       started while the plugin is on: its
//                                   services, settings page and IPC
//       "drawers": [{ "name", "entry", "edge", "along", "corner",
//                     "width", "height" (a number, or "content": the
//                     entry's implicitHeight), "keyboard", "hoverZone" }] }
//
// A plugin that's off loads nothing: no root, no drawers. Plugin files live
// under the shell (plugins/), so they reach the kernel's parts (qs.config,
// qs.services, qs.components) and the types beside them; their services are
// objects their root makes (no singletons), found with instance(id).

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/plugins"

    // Every plugin found: [{ id, name, …, dir }] in name order.
    property var all: []

    // A plugin file's URL through Quickshell's own scheme (as the shell's
    // files are served), so it sees its neighbours (qs.plugins.<id>) and
    // the kernel's modules; a plain file:// URL would bypass that.
    function urlOf(p: var, file: string): string {
        return Qt.resolvedUrl(`../plugins/${p.dir.split("/").pop()}/${file}`);
    }

    function isOn(p: var): bool {
        const v = Settings.values[`plugin.${p.id}`];
        return v === undefined ? p.default !== false : v === true;
    }

    readonly property var enabled: Settings.loaded ? all.filter(p => isOn(p)) : []
    // The enabled plugins' roots: [{ id, url }].
    readonly property var roots: enabled.filter(p => p.root).map(p => ({
                id: p.id,
                url: urlOf(p, p.root)
            }))
    // The enabled plugins' drawers, with their entry's url.
    readonly property var drawers: enabled.reduce((out, p) => out.concat((p.drawers ?? []).map(d => Object.assign({}, d, {
                    plugin: p.id,
                    url: urlOf(p, d.entry)
                }))), [])

    // The running roots, by plugin id (shell.qml's loaders fill this):
    // a plugin's files reach their own objects through it, since plugin
    // folders aren't Quickshell modules (they can't hold singletons, and a
    // plugin's objects should go when it's switched off anyway).
    property var instances: ({})

    function instance(id: string): var {
        return instances[id] ?? null;
    }

    function attach(id: string, obj: var): void {
        const next = Object.assign({}, instances);
        if (obj)
            next[id] = obj;
        else
            delete next[id];
        instances = next;
    }

    // The Settings panel's Plugins page: one switch per plugin.
    readonly property SettingsPage settings: SettingsPage {
        name: "plugins"
        title: "Plugins"
        gloss: "法宝"
        icon: "extension"
        order: 5
        description: "The shell's features, each a plugin; one that's off loads nothing."
        extraItems: toggles.items
    }

    Instantiator {
        id: toggles

        property var items: []

        model: root.all

        delegate: SettingItem {
            required property var modelData

            key: `plugin.${modelData.id}`
            kind: "toggle"
            icon: modelData.icon ?? "extension"
            label: modelData.gloss ? `${modelData.name}  ${modelData.gloss}` : modelData.name
            description: modelData.description ?? ""
            def: modelData.default !== false
        }

        onObjectAdded: (i, o) => items = items.concat([o])
        onObjectRemoved: (i, o) => items = items.filter(x => x !== o)
    }

    function rescan(): void {
        scan.running = true;
    }

    Process {
        id: scan

        running: true
        // One manifest per line: "<dir>\t<json on one line>".
        command: ["sh", "-c", 'for f in "$1"/*/plugin.json; do [ -f "$f" ] && printf "%s\\t%s\\n" "${f%/plugin.json}" "$(tr -d "\\n" < "$f")"; done', "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    try {
                        const p = JSON.parse(line.slice(tab + 1));
                        p.dir = line.slice(0, tab);
                        p.id = p.id ?? p.dir.split("/").pop();
                        found.push(p);
                    } catch (e) {
                        console.warn("plugins: bad plugin.json in", line.slice(0, tab), e);
                    }
                }
                found.sort((a, b) => (a.name ?? a.id).localeCompare(b.name ?? b.id));
                root.all = found;
                console.info(`plugins: ${found.map(p => p.id + (root.isOn(p) ? "" : " (off)")).join(", ")}`);
            }
        }
    }

    IpcHandler {
        target: "plugins"

        function list(): string {
            return root.all.map(p => `${p.id}${root.isOn(p) ? "" : " (off)"}`).join("\n");
        }

        function enable(id: string): void {
            Settings.set(`plugin.${id}`, true);
        }

        function disable(id: string): void {
            Settings.set(`plugin.${id}`, false);
        }
    }
}
