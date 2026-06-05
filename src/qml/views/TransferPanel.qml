import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

Rectangle {
    id: root

    // --- Public API: data in ---
    property var fromAccountModel: null
    property string transferResult: ""
    property bool transferResultIsError: false

    // --- Public API: signals out (match backend: transfer_public, transfer_private, transfer_private_owned) ---
    signal transferPublicRequested(string fromAccountId, string toAddress, string amount)
    signal transferPrivateRequested(string fromAccountId, string toKeysJsonOrAddress, string amount)
    signal transferPrivateOwnedRequested(string fromAccountId, string toAccountId, string amount)
    signal copyRequested(string copyText)

    readonly property int fromFilterCount: fromCombo.count

    QtObject {
        id: d
        property bool useOwnedAccountForTo: false
        readonly property bool isPrivateTab: transferTypeBar.currentIndex === 1
        readonly property bool toAddressValid: isPrivateTab && useOwnedAccountForTo
            ? (fromFilterCount > 0 && toCombo.currentIndex >= 0)
            : (toField && toField.text.trim().length > 0)
        readonly property bool sendEnabled: amountField && manualFromField
                                            && amountField.text.length > 0 && d.toAddressValid
                                            && ((fromFilterCount > 0 && fromCombo.currentIndex >= 0)
                                                || (fromFilterCount === 0 && manualFromField.text.trim().length > 0))
    }

    radius: Theme.spacing.radiusXlarge
    color: Theme.palette.backgroundSecondary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Transfer")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        // Transfer type toggle
        TabBar {
            id: transferTypeBar
            Layout.preferredWidth: 200
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
                placeholderText: qsTr("Paste or type from address")
                visible: fromFilterCount === 0
            }

            AccountComboBox {
                id: fromCombo
                Layout.fillWidth: true
                model: fromAccountModel
                visible: fromFilterCount > 0
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

            CheckBox {
                id: useOwnedToCheck
                visible: d.isPrivateTab
                checked: d.useOwnedAccountForTo
                onCheckedChanged: d.useOwnedAccountForTo = checked
                text: qsTr("Use owned account")
                font.pixelSize: Theme.typography.secondaryText
                palette.text: Theme.palette.text
            }

            LogosTextField {
                id: toField
                Layout.fillWidth: true
                placeholderText: qsTr("Recipient public key")
                visible: !d.isPrivateTab || !d.useOwnedAccountForTo
            }

            AccountComboBox {
                id: toCombo
                Layout.fillWidth: true
                model: fromAccountModel
                visible: d.isPrivateTab && d.useOwnedAccountForTo && fromFilterCount > 0
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
                var fromId = fromFilterCount > 0 && fromCombo.currentIndex >= 0
                        ? (fromCombo.currentValue ?? "")
                        : manualFromField.text.trim()
                var toAddress = d.useOwnedAccountForTo && toCombo.currentIndex >= 0
                        ? (toCombo.currentValue ?? "")
                        : toField.text.trim()
                var amount = amountField.text.trim()
                if (fromId.length > 0 && toAddress.length > 0 && amount.length > 0) {
                    if (transferTypeBar.currentIndex === 0)
                        root.transferPublicRequested(fromId, toAddress, amount)
                    else if (d.useOwnedAccountForTo)
                        root.transferPrivateOwnedRequested(fromId, toAddress, amount)
                    else
                        root.transferPrivateRequested(fromId, toAddress, amount)
                }
            }
        }

        // Result label
        RowLayout {
            Layout.fillWidth: true
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
                onCopyText: root.copyRequested(root.transferResult)
                visible: resultText.text
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
