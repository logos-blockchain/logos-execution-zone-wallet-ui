import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme

import "../controls"

Item {
    id: root

    // --- Public API: data in ---
    property var publicAccountModel: null
    property bool transferPending: false

    // --- Public API: signals out ---
    signal bridgeWithdrawRequested(string fromAccountId, string bedrockAccountPkHex, string amount)

    WithdrawPanel {
        anchors.fill: parent
        publicAccountModel: root.publicAccountModel
        transferPending: root.transferPending

        onBridgeWithdrawRequested: (fromId, bedrockAccountPkHex, amount) => root.bridgeWithdrawRequested(fromId, bedrockAccountPkHex, amount)
    }
}
