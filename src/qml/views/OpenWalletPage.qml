import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

Control {
    id: root

    property string openError: ""

    signal openWallet(string configPath, string storagePath)
    signal back()
    signal errorRaised(string message)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.xlarge
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Open an existing wallet")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }
        LogosText {
            text: qsTr("Select the storage and config files of a wallet you already have.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.topMargin: -Theme.spacing.small
        }

        FilePathPicker {
            id: storagePicker
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.medium
            label: qsTr("Storage file")
            placeholder: qsTr("Path to storage file")
            fieldObjectName: "lezOpenStorageField"
            onPathEdited: if (root.openError.length > 0) root.errorRaised("")
        }

        FilePathPicker {
            id: configPicker
            Layout.fillWidth: true
            label: qsTr("Config file")
            placeholder: qsTr("Path to config file")
            fieldObjectName: "lezOpenConfigField"
            onPathEdited: if (root.openError.length > 0) root.errorRaised("")
        }

        LogosNotice {
            objectName: "lezOpenError"
            Layout.fillWidth: true
            severity: LogosNotice.Error
            message: root.openError
            shown: message.length > 0
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            LogosButton {
                text: qsTr("Back")
                font.pixelSize: Theme.typography.secondaryText
                onClicked: root.back()
            }

            Item { Layout.fillWidth: true }

            LogosButton {
                text: qsTr("Open Wallet")
                font.pixelSize: Theme.typography.secondaryText
                onClicked: {
                    if (storagePicker.path.length === 0 || configPicker.path.length === 0) {
                        root.errorRaised(qsTr("Select both a storage file and a config file."))
                        return
                    }
                    if (storagePicker.path === configPicker.path) {
                        root.errorRaised(qsTr("The storage and config fields point at the same file."))
                        return
                    }
                    root.errorRaised("")
                    root.openWallet(configPicker.path, storagePicker.path)
                }
            }
        }
    }
}
