import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

// Shown right after a new wallet is created, so the user can reveal, copy,
// and write down their recovery phrase before it's cleared from memory.
// Hidden by default — the caller drives `mnemonic` and listens for
// `acknowledged()` to clear its backend-side copy once the user is done.
Popup {
    id: root

    property string mnemonic: ""
    property bool revealed: false

    signal copyRequested(string text)
    signal acknowledged()

    modal: true
    dim: true
    padding: Theme.spacing.large
    // No dismissal via Escape/outside click — the user must explicitly
    // confirm they've saved the phrase via the Continue button below.
    closePolicy: Popup.NoAutoClose

    anchors.centerIn: parent

    onOpened: root.revealed = false

    background: Rectangle {
        color: Theme.palette.backgroundSecondary
        radius: Theme.spacing.radiusXlarge
        border.color: Theme.palette.backgroundElevated
    }

    contentItem: ColumnLayout {
        width: 360
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Save your recovery phrase")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }
        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Write these words down in order and store them somewhere safe. Anyone with this phrase can access your funds, and it cannot be recovered if lost.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosTextArea {
                id: mnemonicText
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                readOnly: true
                text: root.revealed ? root.mnemonic : "•••• ".repeat(6)
            }

            LogosCopyButton {
                Layout.alignment: Qt.AlignTop
                onCopyText: root.copyRequested(root.mnemonic)
            }
        }

        FeedbackButton {
            text: root.revealed ? qsTr("Hide phrase") : qsTr("Show phrase")
            onClicked: root.revealed = !root.revealed
        }

        RowLayout {
            Layout.topMargin: Theme.spacing.medium
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            FeedbackButton {
                text: qsTr("Continue")
                onClicked: {
                    root.acknowledged()
                    root.close()
                }
            }
        }
    }
}
