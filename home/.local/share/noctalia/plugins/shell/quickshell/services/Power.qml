pragma Singleton

// Battery and power profile, live from UPower.

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: !!battery?.isLaptopBattery
    readonly property real level: battery?.percentage ?? 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: hasBattery && !charging && level <= 0.2
    readonly property real timeToEmpty: battery?.timeToEmpty ?? 0
    readonly property real timeToFull: battery?.timeToFull ?? 0
}
