pragma Singleton

// The audio visualiser's bars (Caelestia's CavaProvider, native: PipeWire
// capture and cava's core). Capture runs only while something on screen holds
// a ServiceRef to `cava` (RadialVisualiser does), so nothing listens otherwise.

import QtQuick
import Quickshell
import Nafeel

Singleton {
    readonly property alias cava: provider
    readonly property int bars: 48

    CavaProvider {
        id: provider

        bars: 48
    }
}
