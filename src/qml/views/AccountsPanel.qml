import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
// TODO: remove relative paths and use qmldir instead
import "../controls"
import "../popups"

Rectangle {
    id: root

    // --- Public API: data in ---
    property var accountModel: null

    // --- Public API: signals out ---
    signal createPublicAccountRequested()
    signal createPrivateAccountRequested()
    signal fetchBalancesRequested()

    radius: Theme.spacing.radiusXlarge
    color: Theme.palette.backgroundSecondary

    CreateAccountDialog {
        id: createAccountDialog
        onCreatePublicRequested: root.createPublicAccountRequested()
        onCreatePrivateRequested: root.createPrivateAccountRequested()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        spacing: Theme.spacing.medium

        // Header row
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacing.medium

            LogosText {
                text: qsTr("Accounts")
                font.pixelSize: Theme.typography.titleText
                font.weight: Theme.typography.weightBold
                color: Theme.palette.text
            }

            Item { Layout.fillWidth: true }

            LogosButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 80
                text: qsTr("+ Create")
                onClicked: createAccountDialog.open()
            }
        }

        // Empty state (when no real model and we don't show showcase)
        LogosText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing.xlarge
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Add a new account to get started")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            visible: !listView.visible
        }

        // Account ListView (real model when set and non-empty; otherwise showcase so delegate is visible)
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: (accountModel && accountModel.count > 0) || !accountModel
            clip: true
            spacing: Theme.spacing.small
            model: accountModel && accountModel.count > 0 ? root.accountModel: null

            delegate: AccountDelegate {
                width: listView.width
            }
        }

        // Footer: Fetch / Refresh Balances
        LogosButton {
            Layout.fillWidth: true
            text: qsTr("Refresh Balances")
            onClicked: root.fetchBalancesRequested()
            visible: listView.visible
        }
    }
}
