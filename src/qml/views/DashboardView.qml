import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    // --- Public API: input properties (set by parent / MainView) ---
    property var accountModel: null
    property var publicAccountModel: null
    property var privateAccountModel: null
    property string transferResult: ""
    property bool transferResultIsError: false
    property bool transferPending: false
    property int lastSyncedBlock: 0
    property int currentBlockHeight: 0

    // --- Public API: output signals (parent connects and calls backend) ---
    signal createPublicAccountRequested()
    signal createPrivateAccountRequested()
    signal fetchBalancesRequested()
    signal transferPublicRequested(string fromAccountId, string toAddress, string amount)
    signal transferPrivateRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferPrivateOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferShieldedRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferShieldedOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferDeshieldedRequested(string fromAccountId, string toAccountId, string amount)
    signal copyRequested(string copyText)
    signal copyPublicKeysRequested(string accountIdHex)

    color: Theme.palette.background

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.xlarge
        spacing: Theme.spacing.large

        AccountsPanel {
            id: accountsPanel
            Layout.preferredWidth: parent ? parent.width * 0.40 : 400
            Layout.fillHeight: true

            accountModel: root.accountModel
            lastSyncedBlock: root.lastSyncedBlock
            currentBlockHeight: root.currentBlockHeight

            onCreatePublicAccountRequested: root.createPublicAccountRequested()
            onCreatePrivateAccountRequested: root.createPrivateAccountRequested()
            onFetchBalancesRequested: root.fetchBalancesRequested()
            onCopyRequested: (text) => root.copyRequested(text)
            onCopyPublicKeysRequested: (id) => root.copyPublicKeysRequested(id)
        }

        TransferPanel {
            id: transferPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            publicAccountModel: root.publicAccountModel
            privateAccountModel: root.privateAccountModel
            transferResult: root.transferResult
            transferResultIsError: root.transferResultIsError
            transferPending: root.transferPending

            onTransferPublicRequested: (fromId, toAddress, amount) => root.transferPublicRequested(fromId, toAddress, amount)
            onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) => root.transferPrivateRequested(fromId, toKeysJsonOrAddress, amount)
            onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) => root.transferPrivateOwnedRequested(fromId, toAccountId, amount)
            onTransferShieldedRequested: (fromId, toKeysJsonOrAddress, amount) => root.transferShieldedRequested(fromId, toKeysJsonOrAddress, amount)
            onTransferShieldedOwnedRequested: (fromId, toAccountId, amount) => root.transferShieldedOwnedRequested(fromId, toAccountId, amount)
            onTransferDeshieldedRequested: (fromId, toAccountId, amount) => root.transferDeshieldedRequested(fromId, toAccountId, amount)
            onCopyRequested: (copyText) => root.copyRequested(copyText)
        }
    }
}
