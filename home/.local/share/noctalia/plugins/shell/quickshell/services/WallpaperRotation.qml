pragma Singleton

// Wallpaper rotation: the wallpaper changes on its own every so often, from a
// pool you pick (everything, favourites, a folder, or what the picker shows
// now), shuffled or in order, never repeating until the pool has gone round.
// Day and night: two folders, swapped at the real sunrise and sunset (the
// weather's, 06:00 / 18:00 without it). After Ryoku's playlist and day/night
// rotation (ryogami daemon, MIT), as a shell service.
//
// Every change is an ordinary Wallpapers.set: the theme follows, under the
// ink. Nothing rotates while the screen is locked.
//
// IPC: qs -p <shell> ipc call rotation next | toggle | on | off

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/nafeel-shell/rotation.json"

    property bool enabled: false
    // Minutes between changes.
    property int minutes: 60
    // "all" | "favourites" | "shown" | "folder:<name>"
    property string from: "all"
    // "random" | "sequence"
    property string order: "random"
    property bool dayNight: false
    property string dayFolder: ""
    property string nightFolder: ""
    // Paths shown since the pool last went round (no repeats till then).
    property var seen: []
    property bool loaded: false

    readonly property var everyChoices: [15, 30, 60, 180, 360, 1440]

    // Is it day: between today's sunrise and sunset.
    property bool isDay: true
    function _phase(): bool {
        const now = new Date();
        const today = Weather.days?.[0];
        if (today?.sunrise_iso && today?.sunset_iso) {
            const up = new Date(today.sunrise_iso), down = new Date(today.sunset_iso);
            if (!isNaN(up) && !isNaN(down))
                return now >= up && now < down;
        }
        const h = now.getHours();
        return h >= 6 && h < 18;
    }

    function pool(): var {
        let walls = Wallpapers.all;
        if (dayNight) {
            const folder = isDay ? dayFolder : nightFolder;
            if (folder)
                return walls.filter(w => w.folder === folder);
        }
        if (from === "favourites")
            walls = walls.filter(w => Wallpapers.favourites[w.path]);
        else if (from === "shown")
            walls = Wallpapers.shown;
        else if (from.startsWith("folder:"))
            walls = walls.filter(w => w.folder === from.slice(7));
        return walls;
    }

    function next(): void {
        if (ShellState.locked)
            return;
        const walls = pool().filter(w => w.path !== Wallpapers.current);
        if (walls.length === 0)
            return;
        let fresh = walls.filter(w => !seen.includes(w.path));
        if (fresh.length === 0) {
            // Round again.
            seen = [];
            fresh = walls;
        }
        let pick;
        if (order === "sequence") {
            const all = pool();
            const i = all.findIndex(w => w.path === Wallpapers.current);
            pick = all[(i + 1) % all.length];
            if (pick.path === Wallpapers.current)
                return;
        } else {
            pick = fresh[Math.floor(Math.random() * fresh.length)];
        }
        seen = [...seen.slice(-500), pick.path];
        save();
        Wallpapers.set(pick.path);
    }

    function save(): void {
        if (!loaded)
            return;
        file.setText(JSON.stringify({
            enabled,
            minutes,
            from,
            order,
            dayNight,
            dayFolder,
            nightFolder,
            seen
        }, null, 2) + "\n");
    }

    onEnabledChanged: {
        save();
        if (enabled)
            tick.restart();
    }
    onMinutesChanged: {
        save();
        tick.restart();
    }
    onFromChanged: {
        seen = [];
        save();
    }
    onOrderChanged: save()
    onDayNightChanged: {
        save();
        isDay = _phase();
    }
    onDayFolderChanged: save()
    onNightFolderChanged: save()

    Timer {
        id: tick

        running: root.enabled
        repeat: true
        interval: Math.max(1, root.minutes) * 60000
        onTriggered: root.next()
    }

    // Sunrise and sunset: with day/night on, the pool changes, so does the
    // wallpaper (checked each minute).
    Timer {
        running: root.enabled && root.dayNight
        repeat: true
        interval: 60000
        triggeredOnStart: true
        onTriggered: {
            const day = root._phase();
            if (day !== root.isDay) {
                root.isDay = day;
                root.next();
            }
        }
    }

    // A change was missed while locked: catch up once unlocked.
    Connections {
        target: ShellState

        function onLockedChanged(): void {
            if (!ShellState.locked && root.enabled && root.dayNight && root._phase() !== root.isDay) {
                root.isDay = root._phase();
                root.next();
            }
        }
    }

    IpcHandler {
        target: "rotation"

        function next(): void {
            root.next();
        }
        function toggle(): void {
            root.enabled = !root.enabled;
        }
        function on(): void {
            root.enabled = true;
        }
        function off(): void {
            root.enabled = false;
        }
    }

    FileView {
        id: file

        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.minutes = s.minutes ?? root.minutes;
                root.from = s.from ?? root.from;
                root.order = s.order ?? root.order;
                root.dayNight = s.dayNight ?? false;
                root.dayFolder = s.dayFolder ?? "";
                root.nightFolder = s.nightFolder ?? "";
                root.seen = s.seen ?? [];
                root.enabled = s.enabled ?? false;
            } catch (e) {}
            root.isDay = root._phase();
            root.loaded = true;
        }
        onLoadFailed: {
            root.isDay = root._phase();
            root.loaded = true;
        }
    }
}
