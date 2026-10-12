import QtQuick
import QtMultimedia
import qs.services

// One of a screen's two wallpaper slots: a picture, or a live wallpaper (a
// video, looped and muted). `ready` once there's something to show (decoded,
// or the video's first frame), `failed` if it can't be; settled() either way.
// A video plays only while `playing`; held, it shows its current frame.
Item {
    id: root

    // The wallpaper (its path); `source` is what's loaded for it.
    property string path: ""
    readonly property string source: path ? "file://" + Wallpapers.liveOf(path) : ""
    property size decode
    property bool playing: true
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov|m4v)$/i.test(path)
    property bool ready: false
    property bool failed: false

    signal settled

    onPathChanged: {
        ready = false;
        failed = false;
    }

    function _done(ok: bool): void {
        if (ready || failed)
            return;
        ready = ok;
        failed = !ok;
        settled();
    }

    Loader {
        anchors.fill: parent
        active: root.source !== ""
        sourceComponent: root.isVideo ? video : image
    }

    Component {
        id: image

        Image {
            source: root.source
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

    Component {
        id: video

        // A player and its output (no audio output at all: silent, and no
        // audio device kept open).
        Item {
            MediaPlayer {
                id: player

                source: root.source
                loops: MediaPlayer.Infinite
                videoOutput: out
                // Started to get a first frame; held right away if it
                // shouldn't play (the spare slot, locked, fullscreen, battery).
                Component.onCompleted: play()
                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia)
                        firstFrame.restart();
                    else if (mediaStatus === MediaPlayer.InvalidMedia)
                        root._done(false);
                }
                onErrorOccurred: root._done(false)
            }

            VideoOutput {
                id: out

                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }

            // A frame or two in, so there's a picture to show.
            Timer {
                id: firstFrame

                interval: 120
                onTriggered: {
                    root._done(true);
                    if (!root.playing)
                        player.pause();
                }
            }

            Connections {
                target: root

                function onPlayingChanged(): void {
                    if (root.playing)
                        player.play();
                    else if (root.ready)
                        player.pause();
                }
            }
        }
    }
}
