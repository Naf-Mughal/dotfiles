pragma Singleton

// Idle management, run by the shell: a port of Noctalia's idle manager
// (src/idle/idle_manager.cpp, MIT) onto Quickshell's IdleMonitor (the same
// ext-idle-notify protocol Noctalia drives by hand).
//
// Behaviours (dim, lock, screen off, suspend, …) come from idle-kit's two
// profiles, plugged in and on battery (bin/idle-profiles turns them into
// JSON), and the profile follows the charger. Each behaviour fires after its
// timeout of no input (its locked timeout instead while locked, if it has
// one) unless something inhibits idle (caffeine, a video playing: Wayland
// idle inhibitors); input runs its resume action. As Noctalia does, a
// pre-action fade warns first (the screens darken over `fade` seconds; move
// and it's cancelled), and every behaviour that comes due during a fade
// joins it.
//
// Actions: lock (the shell's lock), screen_off (umbriel dpms-off; dpms-on on
// return), suspend, lock_and_suspend, command (+ resume_command).
//
// Bus: "idle.idled" / "idle.resumed" { name, action }, "idle.grace"
// { active, willLock }, retained "idle.state" { dimmed, screenOff }. The lock
// screen keeps its motion (and a live wallpaper) running until `dimmed`.
//
// IPC: qs -p <shell> ipc call idle status | reload

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    readonly property string bin: Quickshell.shellDir + "/../bin/idle-profiles"
    readonly property string profileDir: Quickshell.env("HOME") + "/.local/share/noctalia/plugins/idle-kit/profiles"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/nafeel-shell"

    property var profiles: ({})
    readonly property string profile: !Power.hasBattery || Power.charging ? "ac" : "battery"
    readonly property var config: profiles[profile] ?? ({
            fade: 0,
            behaviors: []
        })
    readonly property real fade: config.fade ?? 0

    // name -> "waiting" | "fading" | "idled"
    property var phases: ({})
    // The pre-action fade: running, its length, who waits on it, whether it
    // ends in a lock.
    property bool fading: false
    property var graceNames: []
    property bool graceWillLock: false

    // The screen has been dimmed or turned off by a behaviour (the lock goes
    // still then).
    readonly property bool dimmed: (config.behaviors ?? []).some(b => phases[b.name] === "idled" && (b.name === "dim" || b.action === "screen_off"))
    readonly property bool screenOff: (config.behaviors ?? []).some(b => phases[b.name] === "idled" && b.action === "screen_off")
    // Does this profile have a stage that dims at all.
    readonly property bool hasDimStage: (config.behaviors ?? []).some(b => b.enabled && (b.name === "dim" || b.action === "screen_off"))

    onDimmedChanged: Bus.retain("idle.state", {
        dimmed,
        screenOff
    })

    function _set(name: string, phase: string): void {
        const p = Object.assign({}, phases);
        p[name] = phase;
        phases = p;
    }

    function _willLock(b: var): bool {
        return b.action === "lock" || b.action === "lock_and_suspend";
    }

    // ── From the monitors ──

    function _idled(b: var): void {
        if ((phases[b.name] ?? "waiting") !== "waiting")
            return;
        if (fade > 0.0005) {
            _set(b.name, "fading");
            graceNames = [...graceNames, b.name];
            graceWillLock = graceWillLock || _willLock(b);
            if (!fading) {
                fading = true;
                console.log(`idle: '${b.name}' pre-action fade ${fade}s`);
                Bus.publish("idle.grace", {
                    active: true,
                    willLock: graceWillLock
                });
                graceTimer.interval = Math.round(fade * 1000);
                graceTimer.restart();
            } else {
                console.log(`idle: '${b.name}' joined the fade`);
            }
            return;
        }
        _set(b.name, "idled");
        console.log(`idle: '${b.name}' triggered`);
        _run(b);
    }

    function _resumed(b: var): void {
        const phase = phases[b.name] ?? "waiting";
        if (phase === "fading") {
            console.log(`idle: '${b.name}' fade cancelled (you're back)`);
            _cancelGrace();
            return;
        }
        if (phase !== "idled")
            return;
        _set(b.name, "waiting");
        console.log(`idle: '${b.name}' resumed`);
        _resume(b);
    }

    function _cancelGrace(): void {
        if (!fading)
            return;
        for (const n of graceNames)
            _set(n, "waiting");
        graceNames = [];
        graceWillLock = false;
        fading = false;
        graceTimer.stop();
        Bus.publish("idle.grace", {
            active: false,
            willLock: false
        });
    }

    // The fade is done: tear the overlay down first (suspend can freeze the
    // process before a later hide; the lock's capture must see the desktop),
    // then the actions.
    function _graceDone(): void {
        if (!fading)
            return;
        const names = graceNames;
        graceNames = [];
        graceWillLock = false;
        fading = false;
        Bus.publish("idle.grace", {
            active: false,
            willLock: false
        });
        const due = (config.behaviors ?? []).filter(b => names.includes(b.name) && phases[b.name] === "fading");
        for (const b of due)
            _set(b.name, "idled");
        afterGrace.due = due;
        afterGrace.restart();
    }

    Timer {
        id: graceTimer

        onTriggered: root._graceDone()
    }

    // A couple of frames for the overlay to go before the actions.
    Timer {
        id: afterGrace

        property var due: []

        interval: 120
        onTriggered: {
            for (const b of due) {
                console.log(`idle: '${b.name}' triggered after the fade`);
                root._run(b);
            }
            due = [];
        }
    }

    // ── Actions ──

    function _run(b: var): void {
        Bus.publish("idle.idled", {
            name: b.name,
            action: b.action
        });
        switch (b.action) {
        case "lock":
            Session.run("lock");
            break;
        case "screen_off":
            Umbriel.dispatch("dpms-off");
            break;
        case "suspend":
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "lock_and_suspend":
            Session.run("suspend");
            break;
        default:
            if (b.command)
                Quickshell.execDetached(["sh", "-c", b.command]);
        }
    }

    function _resume(b: var): void {
        Bus.publish("idle.resumed", {
            name: b.name,
            action: b.action
        });
        if (b.action === "screen_off")
            Umbriel.dispatch("dpms-on");
        if (b.resumeCommand)
            Quickshell.execDetached(["sh", "-c", b.resumeCommand]);
    }

    // ── The monitors: one per behaviour of the current profile ──

    Instantiator {
        model: root.config.behaviors ?? []

        delegate: IdleMonitor {
            required property var modelData
            // While locked, a behaviour with a locked timeout re-arms at it.
            readonly property real seconds: ShellState.locked && modelData.lockedTimeout > 0 ? modelData.lockedTimeout : modelData.timeout

            enabled: modelData.enabled && seconds > 0
            timeout: seconds
            respectInhibitors: true
            onIsIdleChanged: {
                if (isIdle)
                    root._idled(modelData);
                else
                    root._resumed(modelData);
            }
        }
    }

    // A profile switch (the charger) re-arms everything: anything idled is
    // resumed first so nothing stays dimmed or off.
    onProfileChanged: {
        _cancelGrace();
        for (const b of (config.behaviors ?? []))
            if (phases[b.name] === "idled")
                _resume(b);
        phases = {};
    }

    // ── Profiles ──

    function reload(): void {
        loader.running = true;
    }

    Process {
        id: loader

        running: true
        command: [root.bin, root.profileDir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.profiles = JSON.parse(text).profiles ?? {};
                    console.log(`idle: profiles ${Object.keys(root.profiles).join(", ")}; now ${root.profile}`);
                } catch (e) {
                    console.warn("idle: bad profiles:", e);
                }
            }
        }
    }

    // Edited profiles apply at once.
    FileView {
        path: root.profileDir + "/ac.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }

    FileView {
        path: root.profileDir + "/battery.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }

    // idle-kit sees this and stops handing the profile to Noctalia (the
    // shell runs idle now).
    FileView {
        path: root.stateDir + "/idle-managed"
        printErrors: false
        Component.onCompleted: setText("shell\n")
    }

    IpcHandler {
        target: "idle"

        function status(): string {
            return JSON.stringify({
                profile: root.profile,
                fading: root.fading,
                dimmed: root.dimmed,
                phases: root.phases,
                behaviors: (root.config.behaviors ?? []).map(b => `${b.name}:${b.timeout}s:${b.action}`)
            });
        }
        function reload(): void {
            root.reload();
        }
    }
}
