import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

Rectangle {
    id: root

    // --- Public API: data in ---
    property var publicAccountModel: null
    property var privateAccountModel: null
    property var claimableAccountModel: null
    property string transferResult: ""
    property string transferTxHash: ""
    property bool transferResultIsError: false
    property bool transferPending: false

    // --- Public API: signals out (match backend: transfer_public, transfer_private, transfer_private_owned, transfer_shielded, transfer_shielded_owned, transfer_deshielded, bridge_withdraw, vault_claim) ---
    signal transferPublicRequested(string fromAccountId, string toAddress, string amount)
    signal transferPrivateRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferPrivateOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferShieldedRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferShieldedOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferDeshieldedRequested(string fromAccountId, string toAccountId, string amount)
    signal bridgeWithdrawRequested(string fromAccountId, string bedrockAccountPkHex, string amount)
    signal vaultClaimRequested(string fromAccountId, bool isPublic, string amount)
    signal refreshClaimableDepositsRequested()
    signal copyRequested(string copyText)

    radius: Theme.spacing.radiusXlarge
    color: Theme.palette.backgroundSecondary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        spacing: Theme.spacing.large

        // Main section toggle
        TabBar {
            id: mainSectionBar
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            currentIndex: 0

            background: Rectangle {
                color: Theme.palette.backgroundSecondary
                radius: Theme.spacing.radiusSmall
            }

            LogosTabButton {
                text: qsTr("Transfer")
            }

            LogosTabButton {
                text: qsTr("Bridge")
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: mainSectionBar.currentIndex

            TransferTypesPanel {
                publicAccountModel: root.publicAccountModel
                privateAccountModel: root.privateAccountModel
                transferPending: root.transferPending

                onTransferPublicRequested: (fromId, toAddress, amount) => root.transferPublicRequested(fromId, toAddress, amount)
                onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) => root.transferPrivateRequested(fromId, toKeysJsonOrAddress, amount)
                onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) => root.transferPrivateOwnedRequested(fromId, toAccountId, amount)
                onTransferShieldedRequested: (fromId, toKeysJsonOrAddress, amount) => root.transferShieldedRequested(fromId, toKeysJsonOrAddress, amount)
                onTransferShieldedOwnedRequested: (fromId, toAccountId, amount) => root.transferShieldedOwnedRequested(fromId, toAccountId, amount)
                onTransferDeshieldedRequested: (fromId, toAccountId, amount) => root.transferDeshieldedRequested(fromId, toAccountId, amount)
                onCopyRequested: (copyText) => root.copyRequested(copyText)
            }

            BridgePanel {
                publicAccountModel: root.publicAccountModel
                claimableAccountModel: root.claimableAccountModel
                transferPending: root.transferPending

                onBridgeWithdrawRequested: (fromId, bedrockAccountPkHex, amount) => root.bridgeWithdrawRequested(fromId, bedrockAccountPkHex, amount)
                onVaultClaimRequested: (fromId, isPublic, amount) => root.vaultClaimRequested(fromId, isPublic, amount)
                onRefreshClaimableDepositsRequested: root.refreshClaimableDepositsRequested()
                onCopyRequested: (copyText) => root.copyRequested(copyText)
            }
        }

        // Proof pending indicator
        RowLayout {
            Layout.fillWidth: true
            visible: root.transferPending
            spacing: Theme.spacing.small

            LogosSpinner {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                running: root.transferPending
            }

            LogosText {
                Layout.fillWidth: true
                text: qsTr("Generating proof, please wait…")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }
        }

        // Result label
        RowLayout {
            Layout.fillWidth: true
            visible: !root.transferPending
            LogosText {
                id: resultText
                Layout.fillWidth: true
                text: root.transferResult
                font.pixelSize: Theme.typography.secondaryText
                color: root.transferResult.length > 0
                       ? (root.transferResultIsError ? Theme.palette.error : Theme.palette.textSecondary)
                       : "transparent"
                elide: Text.ElideMiddle
            }
            LogosCopyButton {
                Layout.alignment: Qt.AlignRight
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                onCopyText: root.copyRequested(root.transferTxHash || root.transferResult)
                visible: resultText.text
            }
        }
    }
}
