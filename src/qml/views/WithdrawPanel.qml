import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"
import "../Base58.js" as Base58

Item {
    id: root

    // --- Public API: data in ---
    property var publicAccountModel: null
    property bool transferPending: false

    // --- Public API: signals out (match backend: bridge_withdraw) ---
    signal bridgeWithdrawRequested(string fromAccountId, string bedrockAccountPkHex, string amount)
    signal copyRequested(string copyText)

    readonly property int fromFilterCount: fromCombo.count

    QtObject {
        id: d
        readonly property bool sendEnabled: !root.transferPending
                                            && amountField && manualFromField && toField
                                            && amountField.text.length > 0
                                            && toField.text.trim().length > 0
                                            && ((root.fromFilterCount > 0 && fromCombo.currentIndex >= 0)
                                                || (root.fromFilterCount === 0 && manualFromField.text.trim().length > 0))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.large

        // From: dropdown when public accounts exist, or manual entry when list is empty.
        // Bridge withdrawals only support public sender accounts.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("From")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosTextField {
                id: manualFromField
                Layout.fillWidth: true
                placeholderText: qsTr("Paste or type from account ID")
                visible: root.fromFilterCount === 0
            }

            AccountComboBox {
                id: fromCombo
                Layout.fillWidth: true
                model: root.publicAccountModel
                visible: root.fromFilterCount > 0
                onCopyRequested: (text) => root.copyRequested(text)
            }
        }

        // Bedrock (L1) recipient public key
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("Bedrock (L1) public key")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosTextField {
                id: toField
                Layout.fillWidth: true
                placeholderText: qsTr("Recipient's Bedrock public key (hex)")
            }
        }

        // Amount field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("Amount")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosTextField {
                id: amountField
                Layout.fillWidth: true
                placeholderText: "0.00"
            }
        }

        // Withdraw button
        LogosButton {
            Layout.fillWidth: true
            text: qsTr("Withdraw")
            font.pixelSize: Theme.typography.secondaryText
            enabled: d.sendEnabled
            onClicked: {
                var fromId = root.fromFilterCount > 0 && fromCombo.currentIndex >= 0
                        ? (fromCombo.currentValue ?? "")
                        : Base58.decode(manualFromField.text.trim())
                var toAddress = toField.text.trim()
                var amount = amountField.text.trim()
                if (fromId.length > 0 && toAddress.length > 0 && amount.length > 0)
                    root.bridgeWithdrawRequested(fromId, toAddress, amount)
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
