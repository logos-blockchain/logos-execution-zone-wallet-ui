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

            // Not "Refresh Balances": this kicks a sync, and a sync that finds
            // new blocks re-lists the accounts too, so the narrower name
            // undersold it.
            LogosButton {
                objectName: "lezRefreshButton"
                compact: true
                radius: Theme.spacing.radiusLarge
                text: qsTr("Refresh")
                onClicked: root.fetchBalancesRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.palette.border
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

        // Only when there is a sync row above it to separate — otherwise this
        // would sit directly under the header divider as a double rule.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            visible: root.syncing || root.justSettled
            color: Theme.palette.border
        }

        // Empty state. Create now lives in the section headers, which are
        // rendered by the list — so with no rows there is no section, and this
        // has to carry the buttons or a fresh wallet has no way to make its
        // first account.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing.xlarge
            visible: !listView.visible
            spacing: Theme.spacing.medium

            LogosText {
                objectName: "lezAccountsEmpty"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.syncing
                    ? qsTr("Looking for your accounts…\nAnything sent to your private keys "
                           + "appears here as the scan reaches it.")
                    : qsTr("Add a new account to get started")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacing.medium

                LogosButton {
                    objectName: "lezCreatePublicEmptyButton"
                    compact: true
                    radius: Theme.spacing.radiusLarge
                    text: qsTr("+ Public account")
                    onClicked: root.createPublicAccountRequested()
                }

                LogosButton {
                    objectName: "lezCreatePrivateEmptyButton"
                    compact: true
                    radius: Theme.spacing.radiusLarge
                    text: qsTr("+ Private account")
                    onClicked: root.createPrivateAccountRequested()
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Account ListView (real model when set and non-empty; otherwise showcase so delegate is visible)
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0 || !root.accountModel
            clip: true
            // Rows carry their own rule, so a gap between them would break it.
            spacing: 0
            model: root.accountModel

            // Each private account's "keysJson"/"sectionKey"/"isFirstInGroup" are plain
            // model roles (replicated like any other row data), so the group header for
            // the section a row starts is rendered inline here rather than via
            // ListView.section — section.delegate only gets the section's string value,
            // with no way back to that row's data once the model is a remote replica.
            delegate: ColumnLayout {
                width: listView.width
                // 0 so each margin below is the gap you see. With a non-zero
                // spacing every number here would be "gap minus 8", which is how
                // the section titles drifted out of step with the rows.
                spacing: 0

                // "Public Accounts" title: the public section is a single group, so this
                // is equivalent to showing it once above the first public row.
                // A banded header, not just bold text: with rows separated by
                // rules of their own, a plain line of text read as another row
                // and the section boundary disappeared.
                Rectangle {
                    Layout.fillWidth: true
                    // No top margin: this is the first thing in the list, so the
                    // panel's column spacing is already the gap under the rule
                    // above it.
                    Layout.bottomMargin: Theme.spacing.medium
                    Layout.preferredHeight: publicHeaderRow.implicitHeight + 2 * Theme.spacing.small
                    visible: (model.isPublic ?? false) && (model.isFirstInGroup ?? false)
                    color: Theme.palette.backgroundTertiary
                    radius: Theme.spacing.radiusSmall

                    RowLayout {
                        id: publicHeaderRow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.medium
                        anchors.rightMargin: Theme.spacing.small
                        spacing: Theme.spacing.small

                        LogosText {
                            text: qsTr("Public Accounts")
                            font.pixelSize: Theme.typography.primaryText
                            font.bold: true
                            color: Theme.palette.text
                        }

                        Item { Layout.fillWidth: true }

                        // Per-section, so the section is the answer to "which
                        // kind?" — no type picker needed.
                        LogosButton {
                            objectName: "lezCreatePublicButton"
                            compact: true
                            radius: Theme.spacing.radiusLarge
                            text: qsTr("+ Create")
                            onClicked: root.createPublicAccountRequested()
                        }
                    }
                }

                // Private header: the section title (once) and the key pair the
                // accounts under it belong to, banded together — the keys are
                // what the section IS, not a footnote sitting under its title.
                Rectangle {
                    id: privateHeader

                    property var groupKeys: {
                        try { return JSON.parse(model.keysJson ?? "{}") } catch (e) { return {} }
                    }

                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.medium
                    Layout.bottomMargin: Theme.spacing.medium
                    Layout.preferredHeight: privateHeaderColumn.implicitHeight + 2 * Theme.spacing.small
                    // One band per key group, so a wallet with several key sets
                    // gets a header for each.
                    visible: !model.isPublic && (model.isFirstInGroup ?? false)
                    color: Theme.palette.backgroundTertiary
                    radius: Theme.spacing.radiusSmall

                    ColumnLayout {
                        id: privateHeaderColumn
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing.medium
                        anchors.rightMargin: Theme.spacing.small
                        anchors.topMargin: Theme.spacing.small
                        anchors.bottomMargin: Theme.spacing.small
                        spacing: Theme.spacing.small

                        // Only above the first group — later groups are still the
                        // same section, so the title would be a lie the second time.
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

                            Item { Layout.fillWidth: true }

                            LogosButton {
                                objectName: "lezCreatePrivateButton"
                                compact: true
                                radius: Theme.spacing.radiusLarge
                                text: qsTr("+ Create")
                                onClicked: root.createPrivateAccountRequested()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                LogosText {
                                    Layout.fillWidth: true
                                    text: qsTr("Accounts under keys")
                                    font.pixelSize: Theme.typography.secondaryText
                                    color: Theme.palette.textSecondary
                                }

                                // Labels share a fixed width (the wider of the two)
                                // so the value column lines up between the rows.
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacing.small

                                    LogosText {
                                        text: "\u2022"
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
                                        text: Format.shortenMiddle(privateHeader.groupKeys.nullifier_public_key)
                                        color: Theme.palette.textSecondary
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacing.small

                                    LogosText {
                                        text: "\u2022"
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
                                        text: Format.shortenMiddle(privateHeader.groupKeys.viewing_public_key)
                                        color: Theme.palette.textSecondary
                                    }
                                }
                            }

                            LogosCopyButton {
                                Layout.alignment: Qt.AlignVCenter
                                value: model.keysJson ?? ""
                            }
                        }
                    }
                }

                AccountDelegate {
                    Layout.fillWidth: true
                    onLabelRequested: (accountId, isPublic) => root.labelRequested(accountId, isPublic)
                }
            }
        }
    }
}
