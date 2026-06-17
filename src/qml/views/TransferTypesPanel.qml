import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"
import "../Base58.js" as Base58

Item {
    id: root

    // --- Public API: data in ---
    property var publicAccountModel: null
    property var privateAccountModel: null
    property bool transferPending: false

    // --- Public API: signals out (match backend: transfer_public, transfer_private, transfer_private_owned, transfer_shielded, transfer_shielded_owned, transfer_deshielded) ---
    signal transferPublicRequested(string fromAccountId, string toAddress, string amount)
    signal transferPrivateRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferPrivateOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferShieldedRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferShieldedOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal transferDeshieldedRequested(string fromAccountId, string toAccountId, string amount)
    signal copyRequested(string copyText)

    readonly property int fromFilterCount: fromCombo.count
    readonly property int toFilterCount: toCombo.count

    QtObject {
        id: d
        property bool useOwnedAccountForTo: false
        readonly property bool isPublicTab: transferTypeBar.currentIndex === 0
        readonly property bool isPrivateTab: transferTypeBar.currentIndex === 1
        readonly property bool isShieldedTab: transferTypeBar.currentIndex === 2
        readonly property bool isDeshieldedTab: transferTypeBar.currentIndex === 3
        readonly property bool needsKeysJson: !useOwnedAccountForTo && (isPrivateTab || isShieldedTab)
        readonly property bool toAddressValid: useOwnedAccountForTo
            ? (root.toFilterCount > 0 && toCombo.currentIndex >= 0)
            : (needsKeysJson
               ? d.isValidKeysJson(toField && toField.text)
               : (toField && toField.text.trim().length > 0))
        readonly property bool needsProof: isPrivateTab || isShieldedTab || isDeshieldedTab
        readonly property bool sendEnabled: !root.transferPending
                                            && amountField && manualFromField
                                            && amountField.text.length > 0 && d.toAddressValid
                                            && ((root.fromFilterCount > 0 && fromCombo.currentIndex >= 0)
                                                || (root.fromFilterCount === 0 && manualFromField.text.trim().length > 0))

        // Private/shielded transfers (when not sending to an owned account) require the
        // recipient's {nullifier_public_key, viewing_public_key} JSON — the same JSON the
        // section-header copy button produces — not a bare account ID.
        function isValidKeysJson(text) {
            var trimmed = (text || "").trim()
            if (trimmed.length === 0) return false
            var obj
            try {
                obj = JSON.parse(trimmed)
            } catch (e) {
                return false
            }
            return !!obj && typeof obj === "object" && !Array.isArray(obj)
                && typeof obj.nullifier_public_key === "string" && obj.nullifier_public_key.length > 0
                && typeof obj.viewing_public_key === "string" && obj.viewing_public_key.length > 0
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacing.large

        // Transfer type toggle
        TabBar {
            id: transferTypeBar
            Layout.fillWidth: true
            spacing: Theme.spacing.small
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

            LogosTabButton {
                text: qsTr("Shielded")
            }

            LogosTabButton {
                text: qsTr("Deshielded")
            }
        }

        // From: dropdown when accounts exist, or manual entry when list is empty
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
                model: (d.isPrivateTab || d.isDeshieldedTab) ? root.privateAccountModel : root.publicAccountModel
                visible: root.fromFilterCount > 0
                onCopyRequested: (text) => root.copyRequested(text)
            }
        }

        // To field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("To")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosCheckbox {
                id: useOwnedToCheck
                checked: d.useOwnedAccountForTo
                onCheckedChanged: d.useOwnedAccountForTo = checked
                text: qsTr("Use owned account")
            }

            LogosTextField {
                id: toField
                Layout.fillWidth: true
                placeholderText: (d.isPublicTab || d.isDeshieldedTab) ? qsTr("Recipient account ID") : qsTr("Recipient public keys (JSON)")
                visible: !d.useOwnedAccountForTo
            }

            LogosText {
                Layout.fillWidth: true
                visible: d.needsKeysJson && toField.text.trim().length > 0 && !d.toAddressValid
                text: qsTr("Enter the recipient's public keys as JSON with nullifier_public_key and viewing_public_key.")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.error
                wrapMode: Text.WordWrap
            }

            AccountComboBox {
                id: toCombo
                Layout.fillWidth: true
                model: (d.isPublicTab || d.isDeshieldedTab) ? root.publicAccountModel : root.privateAccountModel
                visible: d.useOwnedAccountForTo && root.toFilterCount > 0
                onCopyRequested: (text) => root.copyRequested(text)
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

        // Send button
        LogosButton {
            Layout.fillWidth: true
            text: qsTr("Send")
            font.pixelSize: Theme.typography.secondaryText
            enabled: d.sendEnabled
            onClicked: {
                var fromId = root.fromFilterCount > 0 && fromCombo.currentIndex >= 0
                        ? (fromCombo.currentValue ?? "")
                        : Base58.decode(manualFromField.text.trim())
                var rawTo = toField.text.trim()
                var toAddress = (d.useOwnedAccountForTo && toCombo.currentIndex >= 0)
                        ? (toCombo.currentValue ?? "")
                        : (d.needsKeysJson ? rawTo : Base58.decode(rawTo))
                var amount = amountField.text.trim()
                if (fromId.length > 0 && toAddress.length > 0 && amount.length > 0) {
                    if (d.isPublicTab)
                        root.transferPublicRequested(fromId, toAddress, amount)
                    else if (d.isPrivateTab) {
                        if (d.useOwnedAccountForTo)
                            root.transferPrivateOwnedRequested(fromId, toAddress, amount)
                        else
                            root.transferPrivateRequested(fromId, toAddress, amount)
                    } else if (d.isShieldedTab) {
                        if (d.useOwnedAccountForTo)
                            root.transferShieldedOwnedRequested(fromId, toAddress, amount)
                        else
                            root.transferShieldedRequested(fromId, toAddress, amount)
                    } else if (d.isDeshieldedTab) {
                        root.transferDeshieldedRequested(fromId, toAddress, amount)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
