pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import qs.config
import qs.services

// One of a screen's two wallpaper slots: a picture, or a live wallpaper (a
// video, looped, silent). `ready` once there's something to show (decoded, or
// the video's first frames), `failed` if it can't be; settled() either way. A
// video plays only while `playing`; held, it keeps its current frame.
//
// Live quality (Settings.liveQuality): "original" plays the file, "light"
// its 720p copy, "adaptive" the file while `detail` (an empty workspace: the
// wallpaper is all you see) and the copy once windows cover it. Switching
// hands over: the other one starts at the same moment, fades in over it, and
// the first one goes, so the motion doesn't jump.
Item {
    id: root

    property string path: ""
    property size decode
    property bool playing: true
    // Is the wallpaper in full view (nothing over it)?
    property bool detail: true
    readonly property bool isVideo: Wallpapers.isVideo(path)
    property bool ready: false
    property bool failed: false

    // Which video plays: the file ("full") or the 720p copy ("light").
    readonly property string light: Wallpapers.lightOf(path)
    readonly property string want: !light || Settings.liveQuality === "original" ? "full" : Settings.liveQuality === "light" ? "light" : detail ? "full" : "light"
    // The layer on screen, and the one taking over (or "").
    property string shownLayer: ""
    property string incoming: ""

    signal settled

    onPathChanged: {
        ready = false;
        failed = false;
        incoming = "";
        shownLayer = "";
        // isVideo and want are bindings on path: read them once they've
        // caught up (a handler can run before them).
        Qt.callLater(() => {
            if (root.isVideo)
                root.shownLayer = root.want;
        });
    }
    onWantChanged: {
        if (!isVideo || !ready || want === shownLayer)
            return;
        incoming = want;
    }

    function _done(ok: bool): void {
        if (ready || failed)
            return;
        ready = ok;
        failed = !ok;
        settled();
    }

    function _urlFor(layer: string): string {
        return "file://" + (layer === "light" ? light : path);
    }

    // A picture.
    Loader {
        anchors.fill: parent
        active: root.path !== "" && !root.isVideo
        sourceComponent: Image {
            source: "file://" + root.path
            sourceSize: root.decode
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            onStatusChanged: {
                if (status === Image.Ready)
                    root._done(true);
                else if (status === Image.Error)
                    root._done(false);
            }
        }
    }

    // The video layer on screen.
    Loader {
        id: shownLoader

        anchors.fill: parent
        active: root.isVideo && root.shownLayer !== ""
        sourceComponent: VideoLayer {
            source: root._urlFor(root.shownLayer)
            run: root.playing
            onFirstFrame: root._done(true)
            onBroken: root._done(false)
        }
    }

    // The one taking over: starts where the other is, fades in, then swaps.
    Loader {
        id: incomingLoader

        anchors.fill: parent
        active: root.incoming !== ""
        sourceComponent: VideoLayer {
            id: next

            source: root._urlFor(root.incoming)
            run: true
            startAt: shownLoader.item?.position ?? 0
            opacity: 0
            onFirstFrame: fade.start()
            onBroken: root.incoming = ""

            NumberAnimation {
                id: fade

                target: next
                property: "opacity"
                to: 1
                duration: Tokens.dur(350)
                onFinished: {
                    root.shownLayer = root.incoming;
                    root.incoming = "";
                }
            }
        }
    }
}
