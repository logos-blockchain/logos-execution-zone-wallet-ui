import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls


Control {
    id: root

    property string createError: ""
    property string testnetUrl: ""
    property string localhostUrl: ""

    signal createWallet(string password, string sequencerUrl)
    signal openExistingRequested()
    signal errorRaised(string message)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.xlarge
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Create your LEZ Wallet")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }
        LogosText {
            text: qsTr("Choose a password and a network. Your wallet files are stored for you.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.topMargin: -Theme.spacing.small
        }

        LogosText {
            text: qsTr("Network")
            font.pixelSize: Theme.typography.secondaryText
            font.weight: Theme.typography.weightMedium
            color: Theme.palette.text
            Layout.topMargin: Theme.spacing.medium
        }
        LogosTextField {
            id: sequencerUrlField
            objectName: "lezCreateSequencerField"
            Layout.fillWidth: true
            placeholderText: qsTr("Sequencer URL")
            text: root.testnetUrl
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small
            LogosButton {
                text: qsTr("Testnet")
                opacity: sequencerUrlField.text === root.testnetUrl ? 1.0 : 0.4
                onClicked: sequencerUrlField.text = root.testnetUrl
            }
            LogosButton {
                text: qsTr("Localhost")
                opacity: sequencerUrlField.text === root.localhostUrl ? 1.0 : 0.4
                onClicked: sequencerUrlField.text = root.localhostUrl
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
            objectName: "lezCreatePasswordField"
            Layout.fillWidth: true
            placeholderText: qsTr("Password")
            echoMode: TextInput.Password
            onTextChanged: root.errorRaised("")
        }
        LogosTextField {
            id: confirmField
            objectName: "lezCreateConfirmField"
            Layout.fillWidth: true
            placeholderText: qsTr("Confirm")
            echoMode: TextInput.Password
            onTextChanged: root.errorRaised("")
        }

        LogosNotice {
            objectName: "lezCreateError"
            Layout.fillWidth: true
            severity: LogosNotice.Error
            message: root.createError
            shown: message.length > 0
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            LogosLink {
                objectName: "lezOpenInsteadLink"
                text: qsTr("Open wallet instead")
                underline: false
                onActivated: root.openExistingRequested()
            }

            Item { Layout.fillWidth: true }

            LogosButton {
                text: qsTr("Create Wallet")
                font.pixelSize: Theme.typography.secondaryText
                onClicked: {
                    if (passwordField.text.length === 0) {
                        root.errorRaised(qsTr("Password cannot be empty."))
                    } else if (passwordField.text !== confirmField.text) {
                        root.errorRaised(qsTr("Passwords do not match."))
                    } else {
                        root.errorRaised("")
                        root.createWallet(passwordField.text, sequencerUrlField.text)
                    }
                }
            }
        }
    }
}
