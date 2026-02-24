import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

Popup {
    id: root

    signal createPublicRequested()
    signal createPrivateRequested()

    modal: true
    dim: true
    padding: Theme.spacing.large
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    anchors.centerIn: parent

    background: Rectangle {
        color: Theme.palette.backgroundSecondary
        radius: Theme.spacing.radiusXlarge
        border.color: Theme.palette.backgroundElevated
    }

    contentItem: ColumnLayout {
        id: contentLayout
        width: parent.width
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Create account")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        LogosText {
            text: qsTr("Choose account type.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            Layout.topMargin: -Theme.spacing.small
        }

        TabBar {
            id: tabBar
            Layout.preferredWidth: 200
            currentIndex: 0

            background: Rectangle {
                color: Theme.palette.backgroundSecondary
                radius: Theme.spacing.radiusSmall
            }

            LogosTabButton {
                text: qsTr("Public")
            }

            LogosTabButton {
                text: qsTr("Private")
            }
        }

        LogosText {
            text: tabBar.currentIndex === 0
                  ? qsTr("Address visible. Balance on-chain.")
                  : qsTr("Private balance and activity.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.topMargin: Theme.spacing.medium
            spacing: Theme.spacing.medium
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LogosButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }
            LogosButton {
                text: qsTr("Create")
                onClicked: {
                    if (tabBar.currentIndex === 0)
                        root.createPublicRequested()
                    else
                        root.createPrivateRequested()
                    root.close()
                }
            }
        }
    }
}
