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
    signal transferRequested(bool isPublic, string fromAccountId, string toAddress, string amount)
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
        }

        TransferPanel {
            id: transferPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            fromAccountModel: root.accountModel
            transferResult: root.transferResult
            transferResultIsError: root.transferResultIsError

            onTransferRequested: function(isPublic, fromId, toAddress, amount) {
                root.transferRequested(isPublic, fromId, toAddress, amount)
            }
            onCopyRequested: (copyText) => root.copyRequested(copyText)
        }
    }
}
