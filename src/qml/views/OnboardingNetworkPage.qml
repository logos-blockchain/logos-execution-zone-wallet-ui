import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

// Step 2: which sequencer the wallet talks to. Its own screen because the
// answer is written into the wallet's config at creation — after this step it
// is not a preference any more.
ColumnLayout {
    id: root

    property string testnetUrl: ""
    property string localhostUrl: ""

    readonly property alias sequencerUrl: sequencerUrlField.text
    readonly property bool valid: sequencerUrlField.text.trim().length > 0

    readonly property string hint: valid ? "" : qsTr("Enter a sequencer URL to continue")

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("Select your network")
        color: Theme.palette.text
        font.pixelSize: OnboardingText.stepHeading
        font.weight: Theme.typography.weightBold
    }

    LogosText {
        Layout.fillWidth: true
        text: qsTr("Your wallet submits transactions through a sequencer. Pick one of the "
                   + "presets, or enter your own.")
        color: Theme.palette.textSecondary
        font.pixelSize: Theme.typography.secondaryText
        wrapMode: Text.WordWrap
    }

    LogosTextField {
        id: sequencerUrlField
        objectName: "lezCreateSequencerField"
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.small
        placeholderText: qsTr("Sequencer URL")
        text: root.testnetUrl
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.small

        LogosButton {
            objectName: "lezNetworkTestnetButton"
            text: qsTr("Testnet")
            opacity: sequencerUrlField.text === root.testnetUrl ? 1.0 : 0.4
            onClicked: sequencerUrlField.text = root.testnetUrl
        }

        LogosButton {
            objectName: "lezNetworkLocalhostButton"
            text: qsTr("Localhost")
            opacity: sequencerUrlField.text === root.localhostUrl ? 1.0 : 0.4
            onClicked: sequencerUrlField.text = root.localhostUrl
        }
    }

    Item { Layout.fillHeight: true }
}
