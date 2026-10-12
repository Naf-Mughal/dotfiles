pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Nafeel
import qs.config
import qs.services
import qs.components
import qs.modules.bar
import qs.modules.bar.popouts
import qs.modules.commandcenter
import qs.modules.notifications
import qs.modules.osd
import qs.modules.wallpaper
import qs.modules.dashboard
import qs.modules.notes
import qs.modules.polkit
import qs.modules.switcher

// A full-screen layer surface that draws the frame, the bar and the drawers
// as one shape (SDF blobs: BlobGroup, below). The frame's edges are reserved in umbriel
// (layout.struts, set by the plugin service). Only the frame and open drawers
// take input; the desktop hole passes through, except while a drawer is
// pinned, when a click anywhere outside it closes it.
PanelWindow {
    id: win

    readonly property bool fullscreen: Umbriel.fullscreenOn(screen?.name ?? "", screen?.width ?? 0, screen?.height ?? 0)
    property real fsProg: fullscreen ? 1 : 0
    readonly property real border: Tokens.border * (1 - fsProg)
    readonly property real barWidth: Tokens.barWidth * (1 - fsProg)
    readonly property bool pinnedHere: ShellState.isPinned(screen?.name ?? "")
    // An authentication prompt takes the keyboard on the focused screen.
    readonly property bool polkitHere: Polkit.active && (Umbriel.focusedOutput === "" || Umbriel.focusedOutput === (screen?.name ?? ""))

    // Every drawer on this screen (the blob engine takes up to sixteen shapes
    // near any one).
    readonly property list<Drawer> drawers: [commandCenter, toasts, actionCenter, topLeft, bottomLeft, osd, dashboard, wallpapers, notes, polkit, switcher]

    function drawerRegion(i: int): rect {
        return i < drawers.length && drawers[i].active ? drawers[i].region : Qt.rect(0, 0, 0, 0);
    }

    onFullscreenChanged: {
        if (fullscreen)
            ShellState.close();
    }

    Behavior on fsProg {
        Anim {}
    }

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nafeel-shell-frame"
    WlrLayershell.layer: WlrLayer.Top
    // A pinned drawer (opened by a keybind or a click) takes the keyboard, so
    // Esc closes it and its fields can be typed in straight away; a hover
    // preview never does, so typing in apps isn't interrupted.
    WlrLayershell.keyboardFocus: polkitHere || pinnedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    mask: fullscreen ? noInput : pinnedHere ? everywhere : frameInput

    // Caffeine: keeps the session from going idle (dim, lock, sleep) while on.
    IdleInhibitor {
        window: win
        enabled: Display.caffeine
    }

    Region {
        id: noInput
    }

    Region {
        id: everywhere

        width: win.width
        height: win.height
    }

    // The whole window XOR the desktop hole = the frame; open drawers are
    // then cut back out of the hole.
    Region {
        id: frameInput

        x: win.barWidth
        y: win.border
        width: win.width - win.barWidth - win.border
        height: win.height - win.border * 2
        intersection: Intersection.Xor

        DrawerRegion {
            index: 0
        }
        DrawerRegion {
            index: 1
        }
        DrawerRegion {
            index: 2
        }
        DrawerRegion {
            index: 3
        }
        DrawerRegion {
            index: 4
        }
        DrawerRegion {
            index: 5
        }
        DrawerRegion {
            index: 6
        }
        DrawerRegion {
            index: 7
        }
        DrawerRegion {
            index: 8
        }
        DrawerRegion {
            index: 9
        }
    }

    // Outside click / Esc closes a pinned drawer.
    // (Not on the bar, whose icons toggle and switch panels themselves, and
    // not inside an open drawer.)
    MouseArea {
        anchors.fill: parent
        enabled: win.pinnedHere
        onPressed: mouse => {
            // Presses inside an open drawer belong to it: handlers in there
            // don't stop a press reaching this catcher below.
            const inside = win.drawers.some(d => {
                if (!d.active)
                    return false;
                const r = d.region;
                return mouse.x >= r.x && mouse.x < r.x + r.width && mouse.y >= r.y && mouse.y < r.y + r.height;
            });
            if (inside || mouse.x < win.barWidth) {
                mouse.accepted = false;
                return;
            }
            ShellState.close();
        }
    }

    Item {
        id: escCatcher

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.close()

        // When a drawer gets pinned, its search field (if it has one) takes
        // the keyboard; otherwise this does, so Esc closes it. (A window here
        // has no activeFocusItem to ask, so the drawer says so itself.)
        function claim(): void {
            if (!win.pinnedHere)
                return;
            const req = {
                taken: false
            };
            ShellState.keyboardGranted(req);
            if (!req.taken)
                escCatcher.forceActiveFocus();
        }

        Connections {
            target: win

            function onPinnedHereChanged(): void {
                Qt.callLater(escCatcher.claim);
            }
        }
    }

    SwitcherKeys {
        anchors.fill: parent
        here: ShellState.isOpen("switcher", win.screen?.name ?? "")
    }

    // The frame and every open drawer as SDF blobs (Ryoku's engine, in the
    // Nafeel module): the frame a BlobInvertedRect, each drawer a BlobRect,
    // merged with circular fillets where they meet; each squashes and
    // stretches with its own velocity. Drawn opaque inside one layer and faded
    // as a whole (the frosted paper), so where shapes overlap there are no
    // seams.
    Item {
        id: paper

        anchors.fill: parent
        layer.enabled: true
        opacity: Tokens.transparency.enabled ? Tokens.transparency.base : 1

        BlobGroup {
            id: blobs

            color: Colours.palette.m3surface
            smoothing: Tokens.frameSmoothing
            // Xianxia ornament: ink wash and grain, paper fibre while frosted,
            // and a gilded edge (stronger when fully immersive).
            ink: Tokens.immersive ? 1 : 0.55
            fibre: Tokens.transparency.enabled ? 1 : 0
            gild: (Tokens.immersive ? 0.4 : 0.25) * (1 - win.fsProg)
            accent: Colours.palette.m3primary
        }

        BlobInvertedRect {
            group: blobs
            anchors.fill: parent
            borderLeft: win.barWidth
            borderTop: win.border
            borderRight: win.border
            borderBottom: win.border
            radius: Tokens.frameRounding * (1 - win.fsProg)
        }

        Repeater {
            model: win.drawers

            BlobRect {
                id: blob

                required property Drawer modelData
                readonly property rect r: modelData.active ? modelData.region : Qt.rect(0, 0, 0, 0)

                group: blobs
                x: r.x
                y: r.y
                width: r.width
                height: r.height
                visible: modelData.active
                // Flush with the frame where it grows out of it (no pocket).
                sinks: false
                radius: Tokens.rounding.large
                topLeftRadius: modelData.radii.x
                topRightRadius: modelData.radii.y
                bottomRightRadius: modelData.radii.z
                bottomLeftRadius: modelData.radii.w
                // The goo, pinned at the side it grows out of, so only the
                // free edge springs and it stays part of the bar (a corner
                // bounces outward rather than tilting).
                anchor: modelData.goo
                axisAligned: modelData.isCorner
                stiffness: Tokens.goo.stiffness
                damping: Tokens.goo.damping
                deformScale: Tokens.goo.enabled ? Tokens.goo.scale : 0
                maxStretch: Tokens.goo.maxStretch

                Component.onCompleted: modelData.blob = blob
            }
        }
    }


    // Above every drawer: the corners and popouts that merge into the bar
    // cover its strip, and its icons must still get the pointer (hovering
    // from one icon to the next switches the panel).
    Bar {
        z: 2
        x: 0
        width: Tokens.barWidth
        height: parent.height
        opacity: 1 - win.fsProg
        visible: opacity > 0
        shellScreen: win.screen
    }

    // The dock and the command center, one drawer at the bottom centre:
    // hidden while the workspace has windows (hovering the bottom edge shows
    // it), the dock while it's empty, and resting on the dock grows it into
    // the command center.
    Drawer {
        id: commandCenter

        readonly property string current: ShellState.current(screenName)
        readonly property bool expanded: current === "command"
        readonly property bool workspaceEmpty: {
            const ws = Umbriel.activeWorkspace(screenName);
            return !ws || Umbriel.windowsOn(ws.id).length === 0;
        }

        name: "command"
        key: expanded ? "command" : "dock"
        open: enabled && (expanded || current === "dock" || workspaceEmpty)
        pinOnPress: expanded
        wantsKeyboard: expanded
        edge: "bottom"
        thickness: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        panelWidth: expanded ? 920 : Math.max(160, content.dockWidth + Tokens.spacing.large * 2)
        panelHeight: expanded ? 640 : content.dockHeight

        Behavior on panelWidth {
            enabled: commandCenter.active
            SpringAnimation {
                spring: Tokens.springK(3.2)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on panelHeight {
            enabled: commandCenter.active
            SpringAnimation {
                spring: Tokens.springK(3.2)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }

        CommandCenter {
            id: content

            anchors.fill: parent
            expanded: commandCenter.expanded
            shellScreen: win.screen

            // Resting on the dock grows the command center.
            HoverHandler {
                id: dockHover

                enabled: !commandCenter.expanded
            }

            Timer {
                running: dockHover.hovered
                interval: 450
                onTriggered: ShellState.preview("command", commandCenter.screenName)
            }
        }
    }

    // ── Corners ───────────────────────────────────────────────────────────
    // Each grows out of its corner point, merged into both bars it touches.

    // Notification toasts: the top-right corner, on the focused screen.
    Drawer {
        id: toasts

        readonly property int pad: Tokens.spacing.normal

        name: "toasts"
        managed: false
        edge: "corner"
        corner: "topRight"
        thickness: win.border
        thicknessY: win.border
        shellScreen: win.screen
        open: !win.fullscreen && Notifs.popups.length > 0 && (Umbriel.focusedOutput === "" || Umbriel.focusedOutput === screenName)
        panelWidth: 400
        panelHeight: Math.max(60, toastStack.implicitHeight + pad * 2)

        Behavior on panelHeight {
            enabled: toasts.active
            SpringAnimation {
                spring: Tokens.spring.spatial.spring
                damping: Tokens.spring.spatial.damping
                epsilon: 0.25
            }
        }

        Toasts {
            id: toastStack

            x: toasts.pad
            y: toasts.pad
            width: toasts.panelWidth - toasts.pad * 2
        }
    }

    // The action center: the bottom-right corner (rest on the corner).
    Drawer {
        id: actionCenter

        name: "actions"
        edge: "corner"
        corner: "bottomRight"
        thickness: win.border
        thicknessY: win.border
        zoneLength: 56
        shellScreen: win.screen
        enabled: !win.fullscreen
        panelWidth: 420
        panelHeight: Math.min(780, win.height - 120)

        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            active: actionCenter.active
            sourceComponent: ActionCenter {}
        }
    }

    // The bar's corners, merged into the bar so they read as part of it: the
    // top-left holds what the bar's top icons open, the bottom-left what its
    // bottom icons open.
    CornerPopout {
        id: topLeft

        corner: "topLeft"
        thickness: win.barWidth
        thicknessY: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 460
        components: ({
                notifications: notificationsPopout,
                capture: capturePopout,
                workspaces: workspacesPopout,
                clipboard: clipboardPopout
            })
        widths: ({
                workspaces: 620,
                clipboard: 680
            })
    }

    CornerPopout {
        id: bottomLeft

        corner: "bottomLeft"
        thickness: win.barWidth
        thicknessY: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        minHeight: 420
        components: ({
                session: sessionPopout,
                sound: soundPopout,
                connect: connectPopout,
                battery: batteryPopout
            })
    }

    Component {
        id: notificationsPopout

        NotificationsPopout {}
    }
    Component {
        id: capturePopout

        CapturePopout {}
    }
    Component {
        id: clipboardPopout

        ClipboardPopout {}
    }
    Component {
        id: workspacesPopout

        WorkspacesPopout {}
    }
    Component {
        id: sessionPopout

        SessionPopout {}
    }
    Component {
        id: soundPopout

        SoundPopout {}
    }
    Component {
        id: connectPopout

        ConnectPopout {}
    }
    Component {
        id: batteryPopout

        BatteryPopout {}
    }

    // The OSD, a pill out of the top bar's centre, on the focused screen.
    Drawer {
        id: osd

        name: "osd"
        managed: false
        edge: "top"
        thickness: win.border
        shellScreen: win.screen
        open: !win.fullscreen && Osd.shown && (Umbriel.focusedOutput === "" || Umbriel.focusedOutput === screenName)
        panelWidth: osdView.implicitWidth
        panelHeight: osdView.implicitHeight

        Behavior on panelHeight {
            enabled: osd.active
            SpringAnimation {
                spring: Tokens.springK(3.5)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }
        Behavior on panelWidth {
            enabled: osd.active
            SpringAnimation {
                spring: Tokens.springK(3.5)
                damping: Tokens.dampK(0.32)
                epsilon: 0.25
            }
        }

        OsdView {
            id: osdView

            anchors.fill: parent
        }
    }

    // The dashboard, out of the top bar's centre (hover there, or
    // Mod+Shift+D): Caelestia's, on the shell's own parts.
    Drawer {
        id: dashboard

        name: "dashboard"
        edge: "top"
        thickness: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        panelWidth: Math.min(1100, win.width - 2 * win.barWidth - 160)
        panelHeight: 540

        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            active: dashboard.active
            sourceComponent: Dashboard {}
        }
    }

    // The wallpaper picker, out of the top bar's centre (Mod+W).
    Drawer {
        id: wallpapers

        name: "wallpapers"
        wantsKeyboard: true
        edge: "top"
        thickness: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        hoverZone: false
        // The slice band runs nearly the screen's width, as Ryoku's does.
        panelWidth: Wallpapers.view === "slice" ? win.width - 2 * win.barWidth - 120 : Math.min(1280, win.width - 260)
        panelHeight: (Wallpapers.view === "mosaic" ? 560 : Wallpapers.view === "slice" ? 600 : 330) + (Quickshell.screens.length > 1 ? 36 : 0)

        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            active: wallpapers.active
            sourceComponent: WallpaperPicker {}
        }
    }

    // Notes, out of the right edge's upper part (Mod+X): keyboard while open.
    Drawer {
        id: notes

        name: "notes"
        edge: "right"
        thickness: win.border
        shellScreen: win.screen
        enabled: !win.fullscreen
        hoverZone: false
        wantsKeyboard: true
        along: 0.36
        panelWidth: 780
        panelHeight: 600

        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            active: notes.active
            sourceComponent: Notes {}
        }
    }

    // An authentication prompt (polkit), out of the top bar's centre.
    Drawer {
        id: polkit

        name: "polkit"
        managed: false
        edge: "top"
        thickness: win.border
        shellScreen: win.screen
        open: win.polkitHere
        hoverZone: false
        panelWidth: 460
        panelHeight: promptLoader.implicitHeight + Tokens.spacing.large * 2

        Loader {
            id: promptLoader

            x: Tokens.spacing.large
            y: Tokens.spacing.large
            width: polkit.panelWidth - Tokens.spacing.large * 2
            active: polkit.active
            sourceComponent: PolkitPrompt {}
        }
    }

    // Alt+Tab, out of the top bar's centre. Also over a fullscreen window.
    Drawer {
        id: switcher

        readonly property int count: Switcher.list.length
        readonly property int pad: Tokens.spacing.large

        name: "switcher"
        // Held back for a beat after Alt+Tab (Switcher.shown): a quick tap
        // switches without the panel coming out at all.
        open: enabled && ShellState.isOpen(name, screenName) && Switcher.shown
        edge: "top"
        thickness: win.border
        shellScreen: win.screen
        hoverZone: false
        wantsKeyboard: true
        panelWidth: Math.min(win.width - 200, Math.max(440, count * 320 + Math.max(0, count - 1) * Tokens.spacing.normal) + pad * 2)
        panelHeight: 36 + Tokens.spacing.normal + 180 + Tokens.spacing.small + 46 + pad * 2

        Behavior on panelWidth {
            enabled: switcher.active
            SpringAnimation {
                spring: Tokens.spring.spatial.spring
                damping: Tokens.spring.spatial.damping
                epsilon: 0.25
            }
        }

        Loader {
            anchors.fill: parent
            anchors.margins: switcher.pad
            active: switcher.active && Switcher.list.length > 0
            sourceComponent: SwitcherView {}
        }
    }

    component DrawerRegion: Region {
        required property int index
        readonly property rect r: win.drawerRegion(index)

        x: r.x
        y: r.y
        width: r.width
        height: r.height
        intersection: Intersection.Subtract
    }

    // The shell's ink transition: this window's still (the frame, the bars,
    // every open panel) soaks away over the new look.
    InkStill {}
}
