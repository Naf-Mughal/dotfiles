pragma Singleton

// The shell's polkit agent: authentication prompts (the plugin turns
// Noctalia's agent off while the shell runs). The prompt itself is
// modules/polkit, shown while `active`.

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    readonly property alias agent: agent
    readonly property var flow: agent.flow
    readonly property bool active: agent.isActive && flow !== null
    // Bumped on a wrong password, so the prompt can shake.
    property int failures: 0

    PolkitAgent {
        id: agent

        onIsRegisteredChanged: console.info(`polkit: agent ${isRegistered ? "registered" : "not registered"}`)
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed(): void {
            root.failures++;
        }
    }
}
