import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    // --- Public API: input properties (set by parent / MainView) ---
    property var accountModel: null
    property string transferResult: ""
    property bool transferResultIsError: false

    // --- Public API: output signals (parent connects and calls backend) ---
    signal createPublicAccountRequested()
    signal createPrivateAccountRequested()
    signal fetchBalancesRequested()
    signal transferPublicRequested(string fromAccountId, string toAddress, string amount)
    signal transferPrivateRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferPrivateOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferShieldedRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferShieldedOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal copyRequested(string copyText)

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

            onCreatePublicAccountRequested: root.createPublicAccountRequested()
            onCreatePrivateAccountRequested: root.createPrivateAccountRequested()
            onFetchBalancesRequested: root.fetchBalancesRequested()
            onCopyRequested: (text) => root.copyRequested(text)
        }

        TransferPanel {
            id: transferPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            fromAccountModel: root.accountModel
            transferResult: root.transferResult
            transferResultIsError: root.transferResultIsError

            onTransferPublicRequested: (fromId, toAddress, amount) => root.transferPublicRequested(fromId, toAddress, amount)
            onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) => root.transferPrivateRequested(fromId, toKeysJsonOrAddress, amount)
            onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) => root.transferPrivateOwnedRequested(fromId, toAccountId, amount)
            onTransferShieldedRequested: (fromId, toKeysJsonOrAddress, amount) => root.transferShieldedRequested(fromId, toKeysJsonOrAddress, amount)
            onTransferShieldedOwnedRequested: (fromId, toAccountId, amount) => root.transferShieldedOwnedRequested(fromId, toAccountId, amount)
            onCopyRequested: (copyText) => root.copyRequested(copyText)
        }
    }
}
