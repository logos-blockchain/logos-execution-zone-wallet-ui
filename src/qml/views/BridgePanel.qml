import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

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

        // Bridge section toggle
        LogosTabBar {
            id: bridgeSectionBar
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            currentIndex: 0


            LogosTabButton {
                text: qsTr("Withdraw")
            }

            LogosTabButton {
                text: qsTr("Claim Deposit")
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
                claimableAccountModel: root.claimableAccountModel
                claimPending: root.transferPending

                onVaultClaimRequested: (fromId, isPublic, amount) => root.vaultClaimRequested(fromId, isPublic, amount)
                onRefreshRequested: root.refreshClaimableDepositsRequested()
            }
        }
    }
}
