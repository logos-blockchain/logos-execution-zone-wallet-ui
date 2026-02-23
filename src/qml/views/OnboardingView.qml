import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Logos.Theme
import Logos.Controls

Control {
    id: root

    property string configPath: ""
    property string storePath: ""
    property string createError: ""

    signal createWallet(string configPath, string storagePath, string password)


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
                placeholderText: qsTr("Add store path")
                text: root.storePath
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
                text: root.configPath
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
        currentFolder: root.configPath ? d.configParentFolderUrl(oot.configPath) : ""
        onAccepted: {
            if (selectedFile) configPathField.text = selectedFile.toString().replace(/^file:\/\//, "")
        }
    }
}
