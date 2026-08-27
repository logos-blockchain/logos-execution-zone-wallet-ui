import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme

import "../controls"

Item {
    id: root

    // --- Public API: data in ---
    property var publicAccountModel: null
    property var claimableAccountModel: null
    property bool transferPending: false

    // --- Public API: signals out ---
    signal bridgeWithdrawRequested(string fromAccountId, string bedrockAccountPkHex, string amount)
    signal vaultClaimRequested(string fromAccountId, bool isPublic, string amount)
    signal refreshClaimableDepositsRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.large

        // Bridge section toggle — pill-shaped, so this secondary row reads as a
        // level below the underlined section bar above it.
        PillTabBar {
            id: bridgeSectionBar
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            currentIndex: 0


            PillTabButton {
                text: qsTr("Withdraw")
            }

            PillTabButton {
                text: qsTr("Claim Deposit")
                badgeCount: claimDepositPanel.claimableCount
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: bridgeSectionBar.currentIndex

            WithdrawPanel {
                publicAccountModel: root.publicAccountModel
                transferPending: root.transferPending

                onBridgeWithdrawRequested: (fromId, bedrockAccountPkHex, amount) => root.bridgeWithdrawRequested(fromId, bedrockAccountPkHex, amount)
            }

            ClaimDepositPanel {
                id: claimDepositPanel
                claimableAccountModel: root.claimableAccountModel
                claimPending: root.transferPending

                onVaultClaimRequested: (fromId, isPublic, amount) => root.vaultClaimRequested(fromId, isPublic, amount)
                onRefreshRequested: root.refreshClaimableDepositsRequested()
            }
        }
    }
}
