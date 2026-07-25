import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Logos.Theme
import Logos.Controls

import "../controls"

Control {
    id: root

    property string configPath: ""
    property string storePath: ""
    property string createError: ""
    property bool recoverMode: false
    // Create/restore is a blocking round-trip to the wallet backend (it can take
    // a while, especially restoring), which freezes the UI thread for its
    // duration — this at least shows a message right before that happens
    // instead of the form just going inert with no explanation.
    property bool busy: false

    signal createWallet(string configPath, string storagePath, string password, string sequencerUrl)
    signal recoverWallet(string configPath, string storagePath, string mnemonic, string password, string sequencerUrl)

    readonly property string testnetUrl: "https://testnet.lez.logos.co"
    readonly property string localhostUrl: "http://127.0.0.1:3040"

    onCreateErrorChanged: if (createError.length > 0) root.busy = false

    QtObject {
        id: d
        function configParentFolderUrl(path) {
            if (!path || path.length === 0) return ""
            var p = path
            var i = Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\"))
            if (i <= 0) return ""
            var dir = p.substring(0, i)
            return dir.indexOf("file://") === 0 ? dir : "file://" + dir
        }
    }

    // Fires the actual (blocking) request one tick after the button click, so
    // the "Restoring…"/"Creating…" busy state above has a chance to actually
    // render before the UI thread freezes for the call.
    Timer {
        id: submitTimer
        interval: 50
        onTriggered: {
            if (root.recoverMode) {
                root.recoverWallet(configPathField.text, storagePathField.text, mnemonicField.text.trim(), passwordField.text, sequencerUrlField.text)
            } else {
                root.createWallet(configPathField.text, storagePathField.text, passwordField.text, sequencerUrlField.text)
            }
        }
    }

    // Scrollable so the form stays reachable (including the submit button)
    // when its content is taller than the window, e.g. with the recovery
    // phrase field shown — rather than silently clipping/overflowing.
    LogosScrollView {
        id: scrollView
        anchors.fill: parent

        Item {
            width: scrollView.availableWidth
            implicitHeight: cardColumn.implicitHeight + 2 * Theme.spacing.xlarge

            ColumnLayout {
                id: cardColumn

                x: Theme.spacing.xlarge
                y: Theme.spacing.xlarge
                width: parent.width - 2 * Theme.spacing.xlarge
                spacing: Theme.spacing.large

                LogosText {
                    text: qsTr("Set up LEZ Wallet")
                    font.pixelSize: Theme.typography.titleText
                    font.weight: Theme.typography.weightBold
                    color: Theme.palette.text
                }
                LogosText {
                    text: qsTr("Configure storage and secure with a password.")
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                    Layout.topMargin: -Theme.spacing.small
                }

                LogosTabBar {
                    id: modeTabBar
                    Layout.fillWidth: true
                    currentIndex: root.recoverMode ? 1 : 0
                    onCurrentIndexChanged: {
                        root.recoverMode = currentIndex === 1
                        root.createError = ""
                    }

                    LogosTabButton { text: qsTr("Create New") }
                    LogosTabButton { text: qsTr("Recover from Mnemonic") }
                }

                LogosText {
                    text: qsTr("Storage")
                    font.pixelSize: Theme.typography.secondaryText
                    font.weight: Theme.typography.weightMedium
                    color: Theme.palette.text
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.small
                    LogosTextField {
                        id: storagePathField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Add store path")
                        text: root.storePath
                    }
                    FeedbackButton {
                        text: qsTr("Browse")
                        onClicked: storageFolderDialog.open()
                    }
                }
                LogosText {
                    text: qsTr("Config file")
                    font.pixelSize: Theme.typography.secondaryText
                    font.weight: Theme.typography.weightMedium
                    color: Theme.palette.text
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.small
                    LogosTextField {
                        id: configPathField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Add path to config")
                        text: root.configPath
                    }
                    FeedbackButton {
                        Layout.preferredHeight: configPathField.height
                        text: qsTr("Browse")
                        onClicked: configFileDialog.open()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.medium
                    spacing: Theme.spacing.small
                    LogosText {
                        text: qsTr("Network")
                        font.pixelSize: Theme.typography.secondaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }
                    LogosTextField {
                        id: sequencerUrlField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Sequencer URL")
                        text: root.testnetUrl
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.small
                    FeedbackButton {
                        text: qsTr("Testnet")
                        opacity: sequencerUrlField.text === root.testnetUrl ? 1.0 : 0.4
                        onClicked: sequencerUrlField.text = root.testnetUrl
                    }
                    FeedbackButton {
                        text: qsTr("Localhost")
                        opacity: sequencerUrlField.text === root.localhostUrl ? 1.0 : 0.4
                        onClicked: sequencerUrlField.text = root.localhostUrl
                    }
                }

                LogosText {
                    text: qsTr("Recovery phrase")
                    visible: root.recoverMode
                    font.pixelSize: Theme.typography.secondaryText
                    font.weight: Theme.typography.weightMedium
                    color: Theme.palette.text
                    Layout.topMargin: Theme.spacing.medium
                }
                LogosTextArea {
                    id: mnemonicField
                    visible: root.recoverMode
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    placeholderText: qsTr("Enter your 12 or 24-word recovery phrase")
                }

                LogosText {
                    text: qsTr("Security")
                    font.pixelSize: Theme.typography.secondaryText
                    font.weight: Theme.typography.weightMedium
                    color: Theme.palette.text
                    Layout.topMargin: Theme.spacing.medium
                }
                LogosTextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password")
                    echoMode: TextInput.Password
                }
                LogosTextField {
                    id: confirmField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Confirm")
                    echoMode: TextInput.Password
                }

                LogosText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                    wrapMode: Text.WordWrap
                    visible: root.busy
                    text: root.recoverMode
                        ? qsTr("Restoring your wallet from the recovery phrase… this can take a little while. Please don't close the app.")
                        : qsTr("Creating your wallet…")
                }

                LogosText {
                    id: errorLabel
                    Layout.fillWidth: true
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.error
                    wrapMode: Text.WordWrap
                    visible: !root.busy && text.length > 0
                    text: root.createError
                }

                FeedbackButton {
                    Layout.alignment: Qt.AlignRight
                    enabled: !root.busy
                    text: root.busy
                        ? (root.recoverMode ? qsTr("Restoring…") : qsTr("Creating…"))
                        : (root.recoverMode ? qsTr("Restore Wallet") : qsTr("Create Wallet"))
                    font.pixelSize: Theme.typography.secondaryText
                    onClicked: {
                        if (passwordField.text.length === 0) {
                            root.createError = qsTr("Password cannot be empty.")
                        } else if (passwordField.text !== confirmField.text) {
                            root.createError = qsTr("Passwords do not match.")
                        } else if (root.recoverMode && mnemonicField.text.trim().length === 0) {
                            root.createError = qsTr("Recovery phrase cannot be empty.")
                        } else {
                            root.createError = ""
                            root.busy = true
                            submitTimer.start()
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: storageFolderDialog
        modality: Qt.NonModal
        nameFilters: ["JSON files (*.json)"]
        currentFolder: root.storePath ? d.configParentFolderUrl(root.storePath) : ""
        onAccepted: storagePathField.text = selectedFile.toString().replace(/^file:\/\//, "")
    }

    FileDialog {
        id: configFileDialog
        modality: Qt.NonModal
        nameFilters: ["JSON files (*.json)"]
        currentFolder: root.configPath ? d.configParentFolderUrl(root.configPath) : ""
        onAccepted: {
            if (selectedFile) configPathField.text = selectedFile.toString().replace(/^file:\/\//, "")
        }
    }
}
