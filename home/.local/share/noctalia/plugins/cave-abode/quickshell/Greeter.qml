pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Greetd
import Quickshell.Wayland
import qs.modules.lock
import qs.modules.lock.themes.xianxia
import qs.services as Services

// Cave Abode as a greetd greeter (greeter/session.sh starts it inside a bare
// umbriel). The same surface as the lock screen, covering every output with a
// session lock so it gets all input; LockContext runs in greeter mode
// (CAVE_ABODE_GREETER=1) and authenticates through greetd. Once the outro has
// played, greetd launches the session and Quickshell quits.
//
// There is no desktop to capture here, so the formation draws over black.
ShellRoot {
    Component.onCompleted: {
        lockCtx.configure(Services.CaveAbode.timing);
        lockCtx.begin();
    }

    LockContext {
        id: lockCtx
        onReleased: Greetd.launch(["/bin/sh", "-c", "exec " + Services.CaveAbode.session], ["XDG_SESSION_TYPE=wayland"], true)
    }

    WlSessionLock {
        locked: true

        WlSessionLockSurface {
            id: surface
            color: "black"

            XianxiaSurface {
                anchors.fill: parent
                ctx: lockCtx
                shown: surface.visible
            }
        }
    }
}
