pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// A corner's popout: one drawer anchored to a corner of the frame that shows
// whichever of its kinds a bar control opened ("bar:<kind>"), and morphs
// between them with the corner springs. It keeps a generous minimum size,
// so a corner reads as a corner piece even when its content is short.
//
//   components  { kind: Component } this corner hosts
Drawer {
    id: root

    required property var components
    // Kinds that need another width than the default ({ kind: px }).
    property var widths: ({})
    property int minHeight: 420
    readonly property int pad: Tokens.spacing.large

    readonly property string current: ShellState.current(screenName)
    readonly property string kind: current.startsWith("bar:") && components[current.slice(4)] ? current.slice(4) : ""
    // What's shown: kept while the drawer closes, so it doesn't empty first.
    property string shownKind: ""

    onKindChanged: {
        if (kind)
            shownKind = kind;
    }

    name: "corner:" + corner
    key: kind ? `bar:${kind}` : name
    open: enabled && kind !== ""
    edge: "corner"
    hoverZone: false
    atmosphere: true
    panelWidth: widths[shownKind] ?? 380
    panelHeight: Math.max(minHeight, (loader.item?.implicitHeight ?? 0) + pad * 2)

    Behavior on panelWidth {
        enabled: root.active
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.25
        }
    }

    Behavior on panelHeight {
        enabled: root.active
        SpringAnimation {
            spring: Tokens.spring.spatial.spring
            damping: Tokens.spring.spatial.damping
            epsilon: 0.25
        }
    }

    Loader {
        id: loader

        x: root.pad
        y: root.pad
        width: root.panelWidth - root.pad * 2
        sourceComponent: root.components[root.shownKind] ?? null
        onLoaded: Choreo.cascade(item, 60)
    }
}
