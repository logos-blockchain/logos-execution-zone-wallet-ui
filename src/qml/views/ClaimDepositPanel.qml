import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../Base58.js" as Base58

Item {
    id: root

    // --- Public API: data in ---
    property var claimableAccountModel: null
    property bool claimPending: false

    // --- Public API: signals out ---
    signal vaultClaimRequested(string fromAccountId, bool isPublic, string amount)
    signal refreshRequested()

    onVisibleChanged: if (visible) root.refreshRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.large

        LogosText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing.xlarge
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("No deposits pending claim")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            visible: !listView.visible
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            clip: true
            spacing: Theme.spacing.small
            model: root.claimableAccountModel

            delegate: ItemDelegate {
                id: delegateRoot
                width: listView.width

                leftPadding: Theme.spacing.medium
                rightPadding: Theme.spacing.medium
                topPadding: Theme.spacing.medium
                bottomPadding: Theme.spacing.medium

                background: Rectangle {
                    color: delegateRoot.hovered ? Theme.palette.backgroundMuted : Theme.palette.backgroundTertiary
                    radius: Theme.spacing.radiusLarge
                }

                contentItem: RowLayout {
                    spacing: Theme.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.tiny

                        LogosText {
                            text: model.name || (qsTr("Account ") + Base58.encode(model.accountId ?? "").slice(0, 4))
                            font.pixelSize: Theme.typography.secondaryText
                            font.bold: true
                        }

                        LogosText {
                            text: qsTr("Claimable: %1").arg(model.vaultBalance ?? "0")
                            font.pixelSize: Theme.typography.secondaryText
                            color: Theme.palette.textSecondary
                        }
                    }

                    LogosButton {
                        text: qsTr("Claim")
                        enabled: !root.claimPending
                        onClicked: root.vaultClaimRequested(model.accountId, model.isPublic, model.vaultBalance)
                    }
                }
            }
        }

        LogosButton {
            Layout.fillWidth: true
            text: qsTr("Refresh")
            enabled: !root.claimPending
            onClicked: root.refreshRequested()
        }
    }
}
