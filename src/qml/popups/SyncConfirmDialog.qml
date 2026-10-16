import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls


LogosDialog {
    id: root

    property int blocks: 0

    signal syncAccepted()
    signal syncDeclined()

    modal: true
    dim: true
    padding: Theme.spacing.large
    closePolicy: Popup.NoAutoClose

    anchors.centerIn: parent

    contentItem: ColumnLayout {
        width: 320
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Sync wallet?")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        LogosText {
            Layout.fillWidth: true
            Layout.maximumWidth: 320
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.text
            text: qsTr("This wallet is %1 blocks behind. Scanning them can take a while, and balances stay out of date until it finishes.").arg(root.blocks)
        }

        RowLayout {
            Layout.topMargin: Theme.spacing.medium
            spacing: Theme.spacing.medium
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LogosButton {
                text: qsTr("Not now")
                onClicked: {
                    root.close()
                    root.syncDeclined()
                }
            }
            LogosButton {
                text: qsTr("Sync now")
                onClicked: {
                    root.close()
                    root.syncAccepted()
                }
            }
        }
    }
}
