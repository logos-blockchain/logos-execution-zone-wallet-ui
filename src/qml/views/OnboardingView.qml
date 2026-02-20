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
            CustomTextField {
                id: storagePathField
                placeholderText: qsTr("/Users/you/.lez-wallet/")
            }
            LogosButton {
                text: qsTr("Browse")
                onClicked: storageFolderDialog.open()
            }
        }
        LogosText {
            text: qsTr("Config file (optional)")
            font.pixelSize: Theme.typography.secondaryText
            font.weight: Theme.typography.weightMedium
            color: Theme.palette.text
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            CustomTextField {
                id: configPathField
                placeholderText: qsTr("Use default config")
            }
            LogosButton {
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
        CustomTextField {
            id: passwordField
            placeholderText: qsTr("Password")
            echoMode: TextInput.Password
        }
        CustomTextField {
            id: confirmField
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

        component CustomTextField: Item {
            id: textFieldRoot
            Layout.fillWidth: true
            implicitHeight: 40
            property alias text: input.text
            property string placeholderText: ""
            property int echoMode: TextInput.Normal
            Rectangle {
                anchors.fill: parent
                radius: Theme.spacing.radiusSmall
                color: Theme.palette.backgroundSecondary
                border.width: 1
                border.color: input.activeFocus ? Theme.palette.overlayOrange : Theme.palette.backgroundElevated
            }
            Text {
                id: placeholder
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: textFieldRoot.placeholderText
                color: Theme.palette.textMuted
                font.pixelSize: Theme.typography.secondaryText
                visible: input.text.length === 0
            }
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.text
                echoMode: textFieldRoot.echoMode
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
