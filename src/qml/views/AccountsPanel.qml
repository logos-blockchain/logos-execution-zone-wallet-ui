import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
// TODO: remove relative paths and use qmldir instead
import "../controls"
import "../popups"
import "../Format.js" as Format

Rectangle {
    id: root

    // --- Public API: data in ---
    property var accountModel: null
    property int lastSyncedBlock: 0
    property int currentBlockHeight: 0
    readonly property bool syncing: currentBlockHeight > 0
                                 && lastSyncedBlock < currentBlockHeight
    property bool justSettled: false
    property int syncStartBlock: 0

    onSyncingChanged: {
        if (syncing) {
            syncStartBlock = lastSyncedBlock
            justSettled = false
            settledTimer.stop()
        } else if (currentBlockHeight > 0) {
            justSettled = true
            settledTimer.restart()
        }
    }

    Timer {
        id: settledTimer
        interval: 4000
        onTriggered: root.justSettled = false
    }

    // --- Public API: signals out ---
    signal createPublicAccountRequested()
    signal createPrivateAccountRequested()
    signal fetchBalancesRequested()
    signal labelRequested(string accountId, bool isPublic)

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

        ColumnLayout {
            objectName: "lezSyncProgress"
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            visible: root.syncing

            RowLayout {
                Layout.fillWidth: true
                LogosText {
                    text: qsTr("Syncing")
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                }
                Item { Layout.fillWidth: true }
                LogosText {
                    text: root.lastSyncedBlock + " / " + root.currentBlockHeight
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                }
            }
            LogosProgressBar {
                Layout.fillWidth: true
                from: root.syncStartBlock
                to: Math.max(root.currentBlockHeight, root.syncStartBlock + 1)
                value: root.lastSyncedBlock
                trackColor: Theme.palette.backgroundElevated
            }
            LogosText {
                objectName: "lezSyncConsequence"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: qsTr("Private accounts are found by scanning blocks. Accounts and "
                           + "balances may be missing until this finishes.")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textTertiary
                wrapMode: Text.WordWrap
            }
        }

        // The one moment this list is known to be the whole answer.
        LogosText {
            objectName: "lezSyncSettled"
            Layout.fillWidth: true
            visible: root.justSettled
            text: qsTr("Up to date · block %1").arg(root.currentBlockHeight)
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
        }

        LogosText {
            objectName: "lezAccountsEmpty"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing.xlarge
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.syncing
                ? qsTr("Looking for your accounts…\nAnything sent to your private keys "
                       + "appears here as the scan reaches it.")
                : qsTr("Add a new account to get started")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            visible: !listView.visible
        }

        // Account ListView (real model when set and non-empty; otherwise showcase so delegate is visible)
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0 || !root.accountModel
            clip: true
            spacing: Theme.spacing.small
            model: root.accountModel

            // Each private account's "keysJson"/"sectionKey"/"isFirstInGroup" are plain
            // model roles (replicated like any other row data), so the group header for
            // the section a row starts is rendered inline here rather than via
            // ListView.section — section.delegate only gets the section's string value,
            // with no way back to that row's data once the model is a remote replica.
            delegate: ColumnLayout {
                width: listView.width
                spacing: Theme.spacing.small

                // "Public Accounts" title: the public section is a single group, so this
                // is equivalent to showing it once above the first public row.
                RowLayout {
                    Layout.fillWidth: true
                    visible: (model.isPublic ?? false) && (model.isFirstInGroup ?? false)
                    spacing: Theme.spacing.small

                    LogosText {
                        text: qsTr("Public Accounts")
                        font.pixelSize: Theme.typography.primaryText
                        font.bold: true
                        color: Theme.palette.text
                    }
                }

                // "Private Accounts" title: shown once above the whole private section,
                // unlike the per-key-set row below which repeats for every private key
                // group. Wrapped the same way as the "Public Accounts" title above so
                // both line up identically.
                RowLayout {
                    Layout.fillWidth: true
                    visible: model.isFirstPrivate ?? false
                    spacing: Theme.spacing.small

                    LogosText {
                        text: qsTr("Private Accounts")
                        font.pixelSize: Theme.typography.primaryText
                        font.bold: true
                        color: Theme.palette.text
                    }
                }

                // Per-key-set row: separates each private key group within the Private
                // section, naming the group by its Npk/Vpk pair, and holds the copy
                // button for that pair.
                RowLayout {
                    id: keyGroupHeader
                    Layout.fillWidth: true
                    visible: !model.isPublic && (model.isFirstInGroup ?? false)
                    spacing: Theme.spacing.small

                    property var groupKeys: {
                        try { return JSON.parse(model.keysJson ?? "{}") } catch (e) { return {} }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        LogosText {
                            Layout.fillWidth: true
                            text: qsTr("Accounts under keys")
                            font.pixelSize: Theme.typography.secondaryText
                            color: Theme.palette.textSecondary
                        }

                        // Each of Npk/Vpk gets its own bullet, aligned with "Private
                        // Accounts"/"Accounts under keys" above. Labels share a fixed
                        // width (the wider of the two) so the value column still lines
                        // up between the two rows.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            LogosText {
                                text: "•"
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.textSecondary
                            }
                            LogosText {
                                id: npkLabel
                                Layout.preferredWidth: Math.max(npkLabel.implicitWidth, vpkLabel.implicitWidth)
                                text: qsTr("Npk:")
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.textSecondary
                            }
                            LogosSelectableText {
                                Layout.fillWidth: true
                                text: Format.shortenMiddle(keyGroupHeader.groupKeys.nullifier_public_key)
                                color: Theme.palette.textSecondary
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            LogosText {
                                text: "•"
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.textSecondary
                            }
                            LogosText {
                                id: vpkLabel
                                Layout.preferredWidth: Math.max(npkLabel.implicitWidth, vpkLabel.implicitWidth)
                                text: qsTr("Vpk:")
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.textSecondary
                            }
                            LogosSelectableText {
                                Layout.fillWidth: true
                                text: Format.shortenMiddle(keyGroupHeader.groupKeys.viewing_public_key)
                                color: Theme.palette.textSecondary
                            }
                        }
                    }

                    LogosCopyButton {
                        Layout.alignment: Qt.AlignVCenter
                        value: model.keysJson ?? ""
                    }
                }

                AccountDelegate {
                    Layout.fillWidth: true
                    onLabelRequested: (accountId, isPublic) => root.labelRequested(accountId, isPublic)
                }
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
