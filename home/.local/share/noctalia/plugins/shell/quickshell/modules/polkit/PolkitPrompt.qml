pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.components

// An authentication prompt (polkit): what's asking and why, the password
// field, and Cancel / Authenticate. A wrong password shakes it.
Column {
    id: root

    readonly property var flow: Polkit.flow

    function submit(): void {
        if (root.flow && password.text !== "") {
            root.flow.submit(password.text);
            password.text = "";
        }
    }

    spacing: Tokens.spacing.normal

    Component.onCompleted: Qt.callLater(() => password.focusInput())

    Item {
        width: parent.width
        height: 44

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.normal

            Seal {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "锁"
                size: 30
            }

            GlossTitle {
                anchors.verticalCenter: parent.verticalCenter
                text: "Authentication"
                gloss: "授权"
                size: Tokens.font.value
            }
        }
    }

    StyledText {
        width: parent.width
        text: root.flow?.message ?? ""
        color: Colours.palette.m3onSurface
        font.pixelSize: Tokens.font.body
        wrapMode: Text.Wrap
    }

    MicroLabel {
        width: parent.width
        visible: text !== ""
        text: root.flow?.actionId ?? ""
        elide: Text.ElideMiddle
    }

    TextField {
        id: password

        width: parent.width
        placeholder: root.flow?.inputPrompt || "Password"
        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
        onAccepted: root.submit()

        // Shake on a wrong password.
        transform: Translate {
            id: shake
        }

        Connections {
            target: Polkit

            function onFailuresChanged(): void {
                shakeAnim.restart();
                password.focusInput();
            }
        }

        SequentialAnimation {
            id: shakeAnim

            NumberAnimation {
                target: shake
                property: "x"
                to: -10
                duration: Tokens.dur(50)
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: 10
                duration: Tokens.dur(70)
            }
            NumberAnimation {
                target: shake
                property: "x"
                to: -6
                duration: Tokens.dur(60)
            }
            SpringAnimation {
                target: shake
                property: "x"
                to: 0
                spring: Tokens.spring.bouncy.spring
                damping: Tokens.spring.bouncy.damping
            }
        }
    }

    StyledText {
        width: parent.width
        visible: text !== ""
        text: root.flow?.supplementaryMessage ?? ""
        color: root.flow?.supplementaryIsError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        font.pixelSize: Tokens.font.small
        wrapMode: Text.Wrap
    }

    Row {
        anchors.right: parent.right
        spacing: Tokens.spacing.small

        Surface {
            width: cancelLabel.implicitWidth + Tokens.spacing.huge * 2
            height: 40
            shape: "small"
            level: 3

            StateLayer {
                hovered: cancelHover.hovered
                pressed: cancelTap.pressed
                ink: Colours.palette.m3onSurface
            }

            StyledText {
                id: cancelLabel

                anchors.centerIn: parent
                text: "Cancel"
                font.pixelSize: Tokens.font.body
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: cancelHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: cancelTap

                onTapped: root.flow?.cancelAuthenticationRequest()
            }
        }

        StyledRect {
            width: okLabel.implicitWidth + Tokens.spacing.huge * 2
            height: 40
            radius: Tokens.rounding.small
            color: Colours.palette.m3primary

            StateLayer {
                hovered: okHover.hovered
                pressed: okTap.pressed
                ink: Colours.palette.m3onPrimary
            }

            StyledText {
                id: okLabel

                anchors.centerIn: parent
                text: "Authenticate"
                color: Colours.palette.m3onPrimary
                font.pixelSize: Tokens.font.body
                font.weight: Font.DemiBold
            }

            HoverHandler {
                id: okHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: okTap

                onTapped: root.submit()
            }
        }
    }
}
