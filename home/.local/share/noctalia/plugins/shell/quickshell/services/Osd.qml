pragma Singleton

// The on-screen display: volume, microphone and brightness as a slider, and
// as a label: Wi-Fi, Bluetooth, power profile, do not disturb, caffeine, night
// light, Caps/Num Lock, keyboard layout, and privacy (microphone in use, screen
// being shared).
// It shows for a moment on any change (keys, apps, Noctalia), except at
// startup, and a level stays quiet while a drawer showing its slider is open.

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    // "volume" | "mic" | "brightness" | "toggle"
    property string kind: ""
    property string icon: ""
    property string label: ""
    property real value: 0
    property bool shown: false
    property bool ready: false

    // Drawers that already show a level (its slider is right there).
    readonly property var showsLevels: ["bar:sound", "actions", "command"]

    function show(k: string, icon: string, label: string, value: real): void {
        if (!ready)
            return;
        const open = ShellState.pinned || ShellState.previewed;
        if (k !== "toggle" && showsLevels.includes(open))
            return;
        kind = k;
        root.icon = icon;
        root.label = label;
        root.value = value;
        shown = true;
        hide.restart();
    }

    Timer {
        running: true
        interval: 2500
        onTriggered: root.ready = true
    }

    Timer {
        id: hide

        interval: 1400
        onTriggered: root.shown = false
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            root.show("volume", Audio.muted ? "volume_off" : Audio.volume < 0.5 ? "volume_down" : "volume_up", "", Audio.volume);
        }
        function onMutedChanged(): void {
            root.show("volume", Audio.muted ? "volume_off" : "volume_up", "", Audio.muted ? 0 : Audio.volume);
        }
        function onSourceVolumeChanged(): void {
            root.show("mic", Audio.sourceMuted ? "mic_off" : "mic", "", Audio.sourceVolume);
        }
        function onSourceMutedChanged(): void {
            root.show("mic", Audio.sourceMuted ? "mic_off" : "mic", "", Audio.sourceMuted ? 0 : Audio.sourceVolume);
        }
    }

    Connections {
        target: Brightness

        // (From raw: `level` may not have caught up yet here.)
        function onRawChanged(): void {
            const level = Brightness.max > 0 ? Brightness.raw / Brightness.max : 0;
            root.show("brightness", level < 0.5 ? "brightness_low" : "light_mode", "", level);
        }
    }

    Connections {
        target: Network

        function onWifiEnabledChanged(): void {
            root.show("toggle", Network.wifiEnabled ? "wifi" : "wifi_off", Network.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off", 0);
        }
    }

    Connections {
        target: BluetoothState

        function onEnabledChanged(): void {
            root.show("toggle", BluetoothState.enabled ? "bluetooth" : "bluetooth_disabled", BluetoothState.enabled ? "Bluetooth on" : "Bluetooth off", 0);
        }
    }

    Connections {
        target: PowerProfiles

        function onProfileChanged(): void {
            const p = PowerProfiles.profile;
            root.show("toggle", p === PowerProfile.PowerSaver ? "eco" : p === PowerProfile.Performance ? "speed" : "balance", p === PowerProfile.PowerSaver ? "Power saver" : p === PowerProfile.Performance ? "Performance" : "Balanced", 0);
        }
    }

    Connections {
        target: Notifs

        function onDndChanged(): void {
            root.show("toggle", Notifs.dnd ? "notifications_off" : "notifications", Notifs.dnd ? "Do not disturb on" : "Do not disturb off", 0);
        }
    }

    Connections {
        target: Display

        function onCaffeineChanged(): void {
            root.show("toggle", "coffee", Display.caffeine ? "Caffeine on" : "Caffeine off", 0);
        }
        function onNightLightChanged(): void {
            root.show("toggle", "nightlight", Display.nightLight ? "Night light on" : "Night light off", 0);
        }
    }

    Connections {
        target: LockKeys

        function onCapsChanged(): void {
            root.show("toggle", "keyboard_capslock", LockKeys.caps ? "Caps Lock on" : "Caps Lock off", 0);
        }
        function onNumChanged(): void {
            root.show("toggle", "dialpad", LockKeys.num ? "Num Lock on" : "Num Lock off", 0);
        }
    }

    Connections {
        target: Umbriel

        function onLayoutIndexChanged(): void {
            root.show("toggle", "keyboard", Umbriel.layout, 0);
        }
        function onScreencastChanged(): void {
            if (Umbriel.screencast)
                root.show("toggle", "screen_share", "Screen is being shared", 0);
        }
    }

    Connections {
        target: Audio

        function onMicInUseChanged(): void {
            if (Audio.micInUse)
                root.show("toggle", "mic", `Microphone in use · ${Audio.streamName(Audio.recorders[0])}`, 0);
        }
    }
}
