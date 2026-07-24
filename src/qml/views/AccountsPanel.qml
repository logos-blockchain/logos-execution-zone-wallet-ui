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
    property int lastSyncedBlock: 0
    property int currentBlockHeight: 0
    // Maps accountId -> true while that account's initializeAccount() call is in flight.
    property var pendingInitializations: ({})

    // --- Public API: signals out ---
    signal createPublicAccountRequested(bool initializeOnCreate)
    signal createPrivateAccountRequested()
    signal fetchBalancesRequested()
    signal copyRequested(string text)
    signal initializeAccountRequested(string accountId, bool isPublic)
    signal labelRequested(string accountId, bool isPublic)

    radius: Theme.spacing.radiusXlarge
    color: Theme.palette.backgroundSecondary

    CreateAccountDialog {
        id: createAccountDialog
        onCreatePublicRequested: (initializeOnCreate) => root.createPublicAccountRequested(initializeOnCreate)
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

            FeedbackButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 80
                text: qsTr("+ Create")
                onClicked: createAccountDialog.open()
            }
        }

        // Sync progress
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            visible: root.currentBlockHeight > 0 && root.lastSyncedBlock < root.currentBlockHeight

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
            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: root.currentBlockHeight
                value: root.lastSyncedBlock

                contentItem: Item {
                    Rectangle {
                        width: parent.width * (root.currentBlockHeight > 0
                               ? root.lastSyncedBlock / root.currentBlockHeight : 0)
                        height: parent.height
                        radius: height / 2
                        color: Theme.palette.overlayOrange
                    }
                }

                background: Rectangle {
                    implicitHeight: 6
                    radius: height / 2
                    color: Theme.palette.backgroundElevated
                }
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

                // keysJson is only ever read inside the copy button's click handler below,
                // never bound to anything visible — so unlike accountId/isPublic/isFirstInGroup
                // (which are warmed up by their visible bindings), the Qt Remote Objects model
                // replica never requests this role from the source process until something
                // actually reads it. Without this binding, the first click reads a not-yet-
                // fetched (empty) value and the real data only arrives in time for the next
                // click. Referencing it here forces the role to be requested as soon as the
                // row is created.
                property string keysJsonWarm: model.keysJson ?? ""

                // "Public Accounts" title: the public section is a single group, so this
                // is equivalent to showing it once above the first public row.
                RowLayout {
                    Layout.fillWidth: true
                    visible: model.isPublic && (model.isFirstInGroup ?? false)
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

                    function shortKey(key) {
                        return key && key.length > 12 ? key.slice(0, 6) + "…" + key.slice(-4) : (key || "")
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
                            LogosText {
                                Layout.fillWidth: true
                                text: keyGroupHeader.shortKey(keyGroupHeader.groupKeys.nullifier_public_key)
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.textSecondary
                                elide: Text.ElideRight
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
                            LogosText {
                                Layout.fillWidth: true
                                text: keyGroupHeader.shortKey(keyGroupHeader.groupKeys.viewing_public_key)
                                font.pixelSize: Theme.typography.secondaryText
                                color: Theme.palette.textSecondary
                                elide: Text.ElideRight
                            }
                        }
                    }

                    LogosCopyButton {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 32
                        icon.color: Theme.palette.textMuted
                        onCopyText: root.copyRequested(model.keysJson ?? "")
                    }
                }

                AccountDelegate {
                    Layout.fillWidth: true
                    initializing: root.pendingInitializations[model.accountId] === true
                    onCopyRequested: (text) => root.copyRequested(text)
                    onInitializeRequested: (accountId, isPublic) => root.initializeAccountRequested(accountId, isPublic)
                    onLabelRequested: (accountId, isPublic) => root.labelRequested(accountId, isPublic)
                }
            }
        }

        // Footer: Fetch / Refresh Balances
        FeedbackButton {
            Layout.fillWidth: true
            text: qsTr("Refresh Balances")
            onClicked: root.fetchBalancesRequested()
            visible: listView.visible
        }
    }
}
