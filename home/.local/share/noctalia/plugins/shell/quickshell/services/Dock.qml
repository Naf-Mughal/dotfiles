pragma Singleton

// The dock's apps: pinned ones (kept in ~/.local/state/nafeel-shell/dock.json)
// in their order, then any other running app, each with its windows from
// umbriel.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<string> pinned: ["google-chrome", "foot", "dolphin"]

    // [{ appId, pinned, windows: [umbriel window…] }]
    readonly property var items: {
        const byApp = {};
        for (const w of Umbriel.windows) {
            if (!byApp[w.app_id])
                byApp[w.app_id] = [];
            byApp[w.app_id].push(w);
        }
        const out = pinned.map(id => ({
                    appId: id,
                    pinned: true,
                    windows: byApp[id] ?? []
                }));
        for (const [id, wins] of Object.entries(byApp))
            if (!pinned.includes(id))
                out.push({
                    appId: id,
                    pinned: false,
                    windows: wins
                });
        return out;
    }

    function togglePin(appId: string): void {
        pinned = pinned.includes(appId) ? pinned.filter(p => p !== appId) : [...pinned, appId];
        file.setText(JSON.stringify({
            pinned: pinned
        }));
    }

    // Focus the app (cycling through its windows), or start it.
    function activate(item: var): void {
        if (item.windows.length === 0) {
            const entry = Apps.forAppId(item.appId);
            if (entry)
                entry.execute();
            else
                Quickshell.execDetached([item.appId]);
            return;
        }
        const focused = item.windows.findIndex(w => w.focused);
        const next = item.windows[(focused + 1) % item.windows.length];
        Umbriel.dispatch("window-focus:" + next.id);
    }

    FileView {
        id: file

        path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/dock.json"
        printErrors: false
        onLoaded: {
            try {
                const p = JSON.parse(text()).pinned;
                if (Array.isArray(p))
                    root.pinned = p;
            } catch (e) {}
        }
    }
}
