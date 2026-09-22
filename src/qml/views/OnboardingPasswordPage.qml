import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

// Step 3: the password that encrypts the wallet's storage. Validated on submit
// rather than gating the footer, so the user is told which of the two things is
// wrong instead of being left with a dead button.
ColumnLayout {
    id: root

    property string errorMessage: ""

    signal submitted(string password)
    signal errorRaised(string message)

    // Called by the wizard footer.
    function submit() {
        if (passwordField.text.length === 0) {
            root.errorRaised(qsTr("Password cannot be empty."))
            return
        }
        if (passwordField.text !== confirmField.text) {
            root.errorRaised(qsTr("Passwords do not match."))
            return
        }
        root.errorRaised("")
        root.submitted(passwordField.text)
    }

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("Choose a password")
        color: Theme.palette.text
        font.pixelSize: OnboardingText.stepHeading
        font.weight: Theme.typography.weightBold
    }

    LogosText {
        Layout.fillWidth: true
        text: qsTr("This password encrypts your wallet on this machine. It is not your "
                   + "recovery phrase, and nothing can reset it for you.")
        color: Theme.palette.textSecondary
        font.pixelSize: Theme.typography.secondaryText
        wrapMode: Text.WordWrap
    }

    LogosTextField {
        id: passwordField
        objectName: "lezCreatePasswordField"
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
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
        message: root.errorMessage
        shown: message.length > 0
    }

    Item { Layout.fillHeight: true }
}
