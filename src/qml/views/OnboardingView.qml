import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

import Logos.Theme
import Logos.Controls

Control {
    id: root

    property string createError: ""

    signal createWallet(string configPath, string storagePath, string password)


    ColumnLayout {
        id: cardColumn

        anchors.fill: parent
        anchors.margins: Theme.spacing.xlarge
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
                placeholderText: qsTr("/Users/you/.lez-wallet/")
            }
            LogosButton {
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
            }
            LogosButton {
                Layout.preferredHeight: configPathField.height
                text: qsTr("Browse")
                onClicked: configFileDialog.open()
            }
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
            id: errorLabel
            Layout.fillWidth: true
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.error
            wrapMode: Text.WordWrap
            visible: text.length > 0
            text: root.createError
        }

        LogosButton {
            Layout.alignment: Qt.AlignRight
            text: qsTr("Create Wallet")
            font.pixelSize: Theme.typography.secondaryText
            onClicked: {
                if (passwordField.text.length === 0) {
                    root.createError = qsTr("Password cannot be empty.")
                } else if (passwordField.text !== confirmField.text) {
                    root.createError = qsTr("Passwords do not match.")
                } else {
                    root.createError = ""
                    root.createWallet(configPathField.text, storagePathField.text, passwordField.text)
                }
            }
        }
    }

    FolderDialog {
        id: storageFolderDialog
        modality: Qt.NonModal
        onAccepted: storagePathField.text = selectedFolder.toString().replace(/^file:\/\//, "")
    }

    FileDialog {
        id: configFileDialog
        modality: Qt.NonModal
        nameFilters: ["YAML files (*.yaml)"]
        onAccepted: {
            if (selectedFile) configPathField.text = selectedFile.toString().replace(/^file:\/\//, "")
        }
    }
}
