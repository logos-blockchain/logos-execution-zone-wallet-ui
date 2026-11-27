import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import Logos.Icons

// The landing: the name over the photograph. With a wallet saved here, its password and Open
// wallet come first, and setting up another stays one step away (nothing is forgotten by it).
// With none, one way in: Set up your wallet.
Item {
    id: root

    property bool savedWallet: false
    property string storagePath: ""
    property string errorMessage: ""
    property bool busy: false

    signal setupRequested()
    signal unlockRequested(string password)

    // An empty password is sent too: a wallet created without one opens with it, and the
    // wallet module answers for an encrypted one. The field never keeps what was typed.
    function submit() {
        if (root.busy)
            return
        const password = passwordField.text
        passwordField.text = ""
        root.errorMessage = ""
        root.unlockRequested(password)
    }
    // A refused password: the field empties for another try, the reason stays.
    function unlockFailed(message) {
        root.errorMessage = message
        passwordField.forceActiveFocus()
    }

    Image {
        anchors.fill: parent
        source: LogosIcons.onboardingBackdrop
        fillMode: Image.PreserveAspectCrop
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
    }

    // The unlock form sits on a solid card: over the photo, hover tints and dim text need a
    // plain surface to read.
    Rectangle {
        objectName: "lezUnlockCard"
        visible: root.savedWallet
        anchors.centerIn: column
        width: column.width + 2 * Theme.spacing.xlarge
        height: column.height + 2 * Theme.spacing.xlarge
        radius: Theme.spacing.radiusXlarge
        color: Theme.palette.backgroundElevated
        border.color: Theme.palette.border
        border.width: 1
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.min(root.width - 80, 360)
        spacing: Theme.spacing.medium

        LogosText {
            Layout.fillWidth: true
            text: qsTr("LEZ Wallet")
            color: Theme.palette.text
            font.pixelSize: Theme.typography.pageTitleText
            font.weight: Theme.typography.weightBold
            horizontalAlignment: Text.AlignHCenter
            Layout.bottomMargin: Theme.spacing.large
        }

        // ---- A wallet here: unlock the last used ----


        LogosText {
            objectName: "lezUnlockStoragePath"
            Layout.fillWidth: true
            visible: root.savedWallet && root.storagePath.length > 0
            text: root.storagePath
            color: Theme.palette.textSecondary
            font.pixelSize: Theme.typography.secondaryText
            elide: Text.ElideMiddle
        }

        LogosTextField {
            id: passwordField
            objectName: "lezUnlockPasswordField"
            Layout.fillWidth: true
            visible: root.savedWallet
            placeholderText: qsTr("Password")
            echoMode: TextInput.Password
            focus: root.savedWallet
            onTextChanged: if (text.length > 0) root.errorMessage = ""
            Keys.onReturnPressed: root.submit()
            Keys.onEnterPressed: root.submit()
        }

        LogosNotice {
            objectName: "lezUnlockError"
            Layout.fillWidth: true
            // Only with a reason to show: an explicit `visible` must not override `shown`.
            visible: root.savedWallet && message.length > 0
            severity: LogosNotice.Error
            message: root.errorMessage
            shown: message.length > 0
        }

        LogosButton {
            objectName: "lezUnlockButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            visible: root.savedWallet
            variant: LogosButton.Variant.Primary
            font.pixelSize: Theme.typography.primaryText
            font.weight: Theme.typography.weightMedium
            // Always pressable (a disabled primary over the photo reads as broken); an empty
            // field is answered in words instead.
            enabled: !root.busy
            text: root.busy ? qsTr("Unlocking…") : qsTr("Unlock")
            onClicked: root.submit()
        }


        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            Layout.bottomMargin: Theme.spacing.small
            visible: root.savedWallet
            implicitHeight: 1
            color: Theme.palette.textSecondary
            opacity: 0.4
        }

        // ---- Set up: the only way in without a wallet; secondary with one ----

        LogosButton {
            objectName: "lezSetUpWalletButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            variant: root.savedWallet ? LogosButton.Variant.Secondary : LogosButton.Variant.Primary
            font.pixelSize: Theme.typography.primaryText
            font.weight: Theme.typography.weightMedium
            enabled: !root.busy
            text: root.savedWallet ? qsTr("Open another wallet") : qsTr("Set up your wallet")
            onClicked: {
                passwordField.text = ""
                root.errorMessage = ""
                root.setupRequested()
            }
        }
    }
}
