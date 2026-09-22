pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

// First-run setup: the welcome screen, then a stepped wizard
ColumnLayout {
    id: root

    property string testnetUrl: ""
    property string localhostUrl: ""
    property string createError: ""
    property string openError: ""
    property bool busy: false
    property string busyMessage: ""

    signal createWallet(string password, string sequencerUrl)
    signal openWallet(string configPath, string storagePath)
    signal mnemonicAcknowledged()

    function showRecoveryPhrase(mnemonic) {
        keysStep.mnemonic = mnemonic
        d.goTo("keys")
    }

    spacing: 0

    QtObject {
        id: d

        readonly property var steps: setupStep.mode === "existing"
            ? ["setup"]
            : ["setup", "network", "password", "keys"]

        property int stepIndex: -1

        readonly property string step: (stepIndex >= 0 && stepIndex < steps.length)
            ? steps[stepIndex]
            : "welcome"

        readonly property var stepNames: steps.map(function (name) {
            switch (name) {
            case "setup":    return qsTr("Setup")
            case "network":  return qsTr("Network")
            case "password": return qsTr("Password")
            case "keys":     return qsTr("Keys")
            default:         return name
            }
        })

        function indexOf(name) {
            for (var i = 0; i < steps.length; ++i) {
                if (steps[i] === name)
                    return i
            }
            return -1
        }

        function goTo(name) {
            const at = indexOf(name)
            if (at >= 0)
                stepIndex = at
        }

        function next() {
            if (stepIndex < steps.length - 1)
                stepIndex += 1
        }

        function back() {
            if (stepIndex > -1)
                stepIndex -= 1
        }

        function advance() {
            switch (step) {
            case "setup":
                if (setupStep.mode === "existing") {
                    if (setupStep.samePathChosen()) {
                        root.openError = qsTr("The storage and config fields point at the "
                                              + "same file.")
                        return
                    }
                    root.openError = ""
                    root.openWallet(setupStep.configPath, setupStep.storagePath)
                } else {
                    next()
                }
                break
            case "network":
                next()
                break
            case "password":
                passwordStep.submit()
                break
            case "keys":
                root.mnemonicAcknowledged()
                break
            }
        }

        readonly property bool canAdvance: {
            if (root.busy)
                return false
            switch (step) {
            case "setup":    return setupStep.valid
            case "password": return true
            case "network":  return networkStep.valid
            case "keys":     return keysStep.acknowledged
            default:         return true
            }
        }

        readonly property string advanceHint: {
            if (root.busy || canAdvance)
                return ""
            switch (step) {
            case "setup":   return setupStep.hint
            case "network": return networkStep.hint
            case "keys":    return keysStep.hint
            default:        return ""
            }
        }

        readonly property string advanceText: {
            if (root.busy)
                return root.busyMessage.length > 0 ? root.busyMessage : qsTr("Working…")
            switch (step) {
            case "setup":    return setupStep.mode === "existing" ? qsTr("Open Wallet")
                                                                  : qsTr("Continue")
            case "password": return qsTr("Create Wallet")
            case "keys":     return qsTr("Open wallet")
            default:         return qsTr("Continue")
            }
        }
    }

    // ---- Welcome -----------------------------------------------------------

    OnboardingWelcomePage {
        objectName: "lezOnboardingWelcome"
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: d.step === "welcome"
        onSetupRequested: {
            root.createError = ""
            root.openError = ""
            d.stepIndex = 0
        }
    }

    // ---- Stepper chrome ----------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacing.xlarge
        Layout.rightMargin: Theme.spacing.xlarge
        Layout.topMargin: Theme.spacing.xlarge
        visible: d.step !== "welcome"
        spacing: Theme.spacing.large

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            LogosText {
                objectName: "lezOnboardingStepTitle"
                text: qsTr("Set up your wallet")
                color: Theme.palette.text
                font.pixelSize: Theme.typography.titleText
                font.weight: Theme.typography.weightBold
            }

            LogosText {
                objectName: "lezOnboardingStepSubtitle"
                text: setupStep.mode === "existing"
                    ? qsTr("Open a wallet you already have.")
                    : qsTr("Create and secure your new wallet.")
                color: Theme.palette.textSecondary
                font.pixelSize: Theme.typography.secondaryText
            }
        }

        RowLayout {
            objectName: "lezOnboardingStepRail"
            Layout.fillWidth: true
            visible: d.steps.length > 1
            spacing: Theme.spacing.small

            Repeater {
                model: d.stepNames

                delegate: ColumnLayout {
                    id: railStep
                    required property int index
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: railStep.index <= d.stepIndex ? Theme.palette.primary
                                                             : Theme.palette.border
                    }

                    LogosText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: (railStep.index + 1) + ". " + railStep.modelData
                        color: railStep.index === d.stepIndex ? Theme.palette.text
                                                              : Theme.palette.textTertiary
                        font.pixelSize: OnboardingText.fieldHint
                        font.weight: railStep.index === d.stepIndex
                            ? Theme.typography.weightBold
                            : Theme.typography.weightRegular
                    }
                }
            }
        }
    }

    // ---- Steps -------------------------------------------------------------

    LogosScrollView {
        id: stepScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: Theme.spacing.xlarge
        Layout.rightMargin: Theme.spacing.xlarge
        Layout.topMargin: Theme.spacing.large
        visible: d.step !== "welcome"
        contentWidth: availableWidth

        StackLayout {
            width: stepScroll.availableWidth
            height: Math.max(stepScroll.availableHeight, implicitHeight)

            currentIndex: {
                switch (d.step) {
                case "setup":    return 0
                case "network":  return 1
                case "password": return 2
                case "keys":     return 3
                default:         return 0
                }
            }

            OnboardingSetupPage {
                id: setupStep
                objectName: "lezOnboardingSetupStep"
                errorMessage: d.step === "setup" ? root.openError : ""
                onErrorRaised: (message) => root.openError = message
            }

            OnboardingNetworkPage {
                id: networkStep
                objectName: "lezOnboardingNetworkStep"
                testnetUrl: root.testnetUrl
                localhostUrl: root.localhostUrl
            }

            OnboardingPasswordPage {
                id: passwordStep
                objectName: "lezOnboardingPasswordStep"
                errorMessage: d.step === "password" ? root.createError : ""
                onErrorRaised: (message) => root.createError = message
                onSubmitted: (password) => root.createWallet(password, networkStep.sequencerUrl)
            }

            RecoveryPhrasePage {
                id: keysStep
                objectName: "lezOnboardingKeysStep"
            }
        }
    }

    // ---- Footer ------------------------------------------------------------

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Theme.spacing.xlarge
        visible: d.step !== "welcome"
        spacing: Theme.spacing.medium

        // Not on the keys step: the wallet already exists by then, so there is
        // nothing behind it to go back to.
        LogosButton {
            objectName: "lezOnboardingBackButton"
            visible: d.step !== "keys"
            enabled: !root.busy
            text: qsTr("Back")
            font.pixelSize: Theme.typography.secondaryText
            onClicked: d.back()
        }

        Item { Layout.fillWidth: true }

        // The one thing a disabled button cannot say for itself.
        LogosText {
            objectName: "lezOnboardingAdvanceHint"
            visible: d.advanceHint.length > 0
            text: d.advanceHint
            color: Theme.palette.textTertiary
            font.pixelSize: Theme.typography.secondaryText
        }

        LogosButton {
            objectName: "lezOnboardingAdvanceButton"
            variant: LogosButton.Variant.Primary
            Layout.preferredHeight: 44
            Layout.minimumWidth: 160
            enabled: d.canAdvance
            text: d.advanceText
            font.pixelSize: Theme.typography.secondaryText
            onClicked: d.advance()
        }
    }
}
