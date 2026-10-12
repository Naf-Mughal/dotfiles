import QtQuick
import Quickshell

// The notes plugin's root, made while it's on (Plugins.instance("notes")):
// it owns the store (its files, its IPC `notes jot|create`, its settings
// page), so a jot works without the drawer ever opening, and everything goes
// when the plugin is switched off. The drawer is the manifest's.
//
// Plugin folders aren't Quickshell modules, so the files beside this one
// are made from their URL.
Scope {
    id: root

    property var store: null

    Component.onCompleted: {
        const c = Qt.createComponent(Qt.resolvedUrl("NotesStore.qml"));
        if (c.status === Component.Ready)
            store = c.createObject(root);
        else
            console.warn("notes:", c.errorString());
    }
}
