pragma Singleton

// The MPRIS player worth showing: the one playing, else the first.

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer active: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: !!active?.isPlaying
    readonly property string art: active?.trackArtUrl ?? ""
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""

    // For the lock's media keys.
    function playPause(): void {
        togglePlaying();
    }

    function next(): void {
        if (active?.canGoNext)
            active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    function togglePlaying(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
}
