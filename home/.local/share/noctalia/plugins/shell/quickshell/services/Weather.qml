pragma Singleton

// Weather from Noctalia's cache (~/.cache/noctalia/weather.json, Open-Meteo).

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var data: null
    readonly property var current: data?.current ?? null
    readonly property var days: data?.forecast_days ?? []
    readonly property var hours: data?.forecast_hours ?? []
    readonly property string place: data?.location_name ?? ""
    readonly property real temp: current?.temperature_c ?? 0
    readonly property string icon: current ? iconFor(current.weather_code, current.is_day) : "cloud"
    readonly property string description: current ? describe(current.weather_code) : ""

    // WMO weather codes.
    function describe(code: int): string {
        if (code === 0)
            return "Clear";
        if (code <= 2)
            return "Partly cloudy";
        if (code === 3)
            return "Overcast";
        if (code <= 48)
            return "Fog";
        if (code <= 57)
            return "Drizzle";
        if (code <= 67)
            return "Rain";
        if (code <= 77)
            return "Snow";
        if (code <= 82)
            return "Showers";
        if (code <= 86)
            return "Snow showers";
        return "Thunderstorm";
    }

    function iconFor(code: int, day: bool): string {
        if (code === 0)
            return day === false ? "clear_night" : "clear_day";
        if (code <= 2)
            return day === false ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 3)
            return "cloud";
        if (code <= 48)
            return "foggy";
        if (code <= 67 || (code >= 80 && code <= 82))
            return "rainy";
        if (code <= 77 || code <= 86)
            return "weather_snowy";
        return "thunderstorm";
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/noctalia/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text()).snapshot ?? null;
            } catch (e) {}
        }
    }
}
