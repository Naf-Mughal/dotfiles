pragma Singleton

// The capture plugin (nafeel/capture): its state from the state.json it
// writes for outside readers (Cave Abode too), and actions over its IPC.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var state: ({})
    // The capture dialog's choices: { kind: screenshot|record, shot:
    // region|screen|edit, area: region|screen, delay: 0|3|5|10, mic, system }.
    property var prefs: ({
            kind: "screenshot",
            shot: "region",
            area: "region",
            delay: 0,
            mic: false,
            system: true
        })
    readonly property bool recording: !!state.recording
    readonly property bool paused: !!state.paused

    // Seconds recorded, not counting pauses (as the capture plugin counts).
    function elapsed(nowMs: real): real {
        if (!recording || !state.startedAt)
            return 0;
        const paused = (state.pausedMs ?? 0) + (state.paused ? nowMs - (state.pausedAt ?? nowMs) : 0);
        return Math.max(0, (nowMs - state.startedAt - paused) / 1000);
    }

    // An action for the capture service (its onIpc): "screenshot region",
    // "stop", "pause", "set kind record", …
    function request(action: string, arg: string): void {
        Noctalia.plugin("nafeel/capture:service", action, arg ?? "");
    }

    function setPref(key: string, value: var): void {
        const next = Object.assign({}, prefs);
        next[key] = value;
        prefs = next;
        request("set", `${key} ${value}`);
    }

    // Take the screenshot or start the recording the prefs describe, after
    // `afterMs` (time for the popout to close, so it's never in the picture).
    function go(afterMs: int): void {
        goTimer.interval = afterMs;
        goTimer.restart();
    }

    Timer {
        id: goTimer

        onTriggered: root.request("capture", "")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/noctalia/plugins/data/nafeel/capture/prefs.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.prefs = Object.assign({}, root.prefs, JSON.parse(text()));
            } catch (e) {}
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/noctalia/plugins/data/nafeel/capture/state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.state = JSON.parse(text());
            } catch (e) {}
        }
    }
}
