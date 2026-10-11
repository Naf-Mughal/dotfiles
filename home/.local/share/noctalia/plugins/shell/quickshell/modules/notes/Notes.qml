pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Notes (Mod+X): a scratch pad, saved as you type (a moment after you stop)
// to ~/.local/state/nafeel-shell/notes.md.
Item {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/state/nafeel-shell/notes.md"
    property bool loaded: false
    property real savedAt: 0
    readonly property int words: edit.text.trim() ? edit.text.trim().split(/\s+/).length : 0

    function focusEditor(): void {
        edit.forceActiveFocus();
        edit.cursorPosition = edit.length;
    }

    Component.onCompleted: Qt.callLater(focusEditor)

    FileView {
        id: file

        path: root.path
        printErrors: false
        onLoaded: {
            edit.text = text();
            root.loaded = true;
            Qt.callLater(root.focusEditor);
        }
        onLoadFailed: root.loaded = true
    }

    Timer {
        id: save

        interval: 600
        onTriggered: {
            file.setText(edit.text);
            root.savedAt = Date.now();
        }
    }

    Item {
        id: head

        width: parent.width
        height: 40

        GlossTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notes"
            gloss: Xian.gloss.notes
            size: Tokens.font.value
        }

        MicroLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.words} words · ${save.running ? "saving" : root.savedAt ? "saved" : "ready"}`
        }
    }

    Surface {
        anchors.top: head.bottom
        anchors.topMargin: Tokens.spacing.small
        anchors.bottom: parent.bottom
        width: parent.width
        level: 1
        border.width: edit.activeFocus ? 1 : 0
        border.color: Qt.alpha(Colours.palette.m3primary, 0.5)

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Tokens.spacing.large
            contentHeight: edit.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            function ensureVisible(r: rect): void {
                if (contentY >= r.y)
                    contentY = r.y;
                else if (contentY + height <= r.y + r.height)
                    contentY = r.y + r.height - height;
            }

            TextEdit {
                id: edit

                width: flick.width
                wrapMode: TextEdit.Wrap
                color: Colours.palette.m3onSurface
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
                font.pixelSize: Tokens.font.row
                textFormat: TextEdit.PlainText
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                onTextChanged: {
                    if (root.loaded)
                        save.restart();
                }
                Keys.onEscapePressed: ShellState.close()

                StyledText {
                    visible: edit.text === ""
                    text: "Write anything. It's kept as you type."
                    color: Colours.palette.m3onSurfaceVariant
                    font.pixelSize: Tokens.font.row
                    font.italic: true
                }
            }
        }
    }
}
