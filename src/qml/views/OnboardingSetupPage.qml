import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

// Step 1: where the wallet comes from. The only question on this screen,
// because the answer changes which screens follow it — create goes on to ask
// for a network and a password, existing has everything it needs right here.
ColumnLayout {
    id: root

    // "create" or "existing"
    property string mode: "create"
    property string errorMessage: ""

    readonly property alias storagePath: storagePicker.path
    readonly property alias configPath: configPicker.path

    readonly property bool valid: mode === "create"
        || (mode === "existing" && storagePicker.path.length > 0
                                && configPicker.path.length > 0)

    // Only the existing route can be incomplete now that create is preselected,
    // so there is no "pick something first" case left to name.
    readonly property string hint: valid ? "" : qsTr("Choose your wallet files to continue")

    signal errorRaised(string message)

    // Both fields set, but set to the same file — caught here rather than sent
    // to the backend, which would answer with a less specific failure.
    function samePathChosen() {
        return storagePicker.path === configPicker.path
    }

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("How do you want to start?")
        color: Theme.palette.text
        font.pixelSize: OnboardingText.stepHeading
        font.weight: Theme.typography.weightBold
    }

    // Stacked, not side by side: these are read before they are chosen between,
    // and a column is the order the eye already follows.
    OnboardingChoiceCard {
        objectName: "lezSetupCreateCard"
        Layout.fillWidth: true
        title: qsTr("Create a new wallet")
        badge: qsTr("Recommended")
        description: qsTr("Create a fresh wallet and recovery phrase. Best if this is your "
                          + "first wallet.")
        selected: root.mode === "create"
        onPicked: root.mode = "create"
    }

    OnboardingChoiceCard {
        objectName: "lezSetupExistingCard"
        Layout.fillWidth: true
        title: qsTr("I already have a wallet")
        description: qsTr("Point at the wallet files you already have (e.g. moving to a new "
                          + "machine). Nothing in them is rewritten.")
        selected: root.mode === "existing"
        onPicked: root.mode = "existing"
    }

    // Only the existing route needs paths, and asking for them before the route
    // is chosen would put two unrelated questions on one screen.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        visible: root.mode === "existing"
        spacing: Theme.spacing.small

        LogosText {
            text: qsTr("Point to your files")
            color: Theme.palette.text
            font.pixelSize: Theme.typography.secondaryText
            font.weight: Theme.typography.weightMedium
        }

        FilePathPicker {
            id: storagePicker
            Layout.fillWidth: true
            label: qsTr("Storage file")
            placeholder: qsTr("Path to storage file")
            fieldObjectName: "lezOpenStorageField"
            onPathEdited: if (root.errorMessage.length > 0) root.errorRaised("")
        }

        FilePathPicker {
            id: configPicker
            Layout.fillWidth: true
            label: qsTr("Config file")
            placeholder: qsTr("Path to config file")
            fieldObjectName: "lezOpenConfigField"
            onPathEdited: if (root.errorMessage.length > 0) root.errorRaised("")
        }

        LogosText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: qsTr("Your recovery phrase stays where it is — opening a wallet never "
                       + "shows it again.")
            color: Theme.palette.textTertiary
            font.pixelSize: OnboardingText.fieldHint
            wrapMode: Text.WordWrap
        }
    }

    LogosNotice {
        objectName: "lezOpenError"
        Layout.fillWidth: true
        severity: LogosNotice.Error
        message: root.errorMessage
        shown: message.length > 0
    }

    Item { Layout.fillHeight: true }
}
