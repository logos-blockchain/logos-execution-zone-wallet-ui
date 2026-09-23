import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

// Step 4: the recovery phrase, and the one step in the wizard that refuses to
// be skipped. create_new returns it exactly once and nothing in the module can
// re-derive or re-export it, so this is the single point in the flow where a
// user can lose something irreplaceable by clicking past it.
ColumnLayout {
    id: root

    property string mnemonic: ""

    readonly property bool acknowledged: savedCheckBox.checked

    readonly property string hint: acknowledged
        ? ""
        : qsTr("Confirm you saved your recovery phrase to continue")

    readonly property var words: {
        const t = mnemonic.trim()
        return t.length > 0 ? t.split(/\s+/) : []
    }

    spacing: Theme.spacing.medium

    LogosText {
        text: qsTr("View and save your keys")
        color: Theme.palette.text
        font.pixelSize: OnboardingText.stepHeading
        font.weight: Theme.typography.weightBold
    }

    LogosNotice {
        objectName: "lezPhraseShownOnceNotice"
        Layout.fillWidth: true
        shown: true
        severity: LogosNotice.Warning
        title: qsTr("Shown once, and only here")
        message: qsTr("These words are the only way to recover this wallet. They will not be "
                      + "shown again, nothing can reissue them, and anyone who has them can "
                      + "spend your funds. Write them down and keep them somewhere safe.")
    }

    LogosFrame {
        Layout.fillWidth: true

        GridLayout {
            columns: 4
            columnSpacing: Theme.spacing.medium
            rowSpacing: Theme.spacing.small

            Repeater {
                model: root.words
                delegate: RowLayout {
                    id: wordRow

                    required property int index
                    required property string modelData

                    spacing: Theme.spacing.small

                    LogosText {
                        text: (wordRow.index + 1) + "."
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.textSecondary
                    }
                    LogosText {
                        text: wordRow.modelData
                        font.pixelSize: Theme.typography.secondaryText
                        font.weight: Theme.typography.weightMedium
                        color: Theme.palette.text
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.small

        LogosCopyButton {
            value: root.mnemonic
        }

        LogosText {
            text: qsTr("Copy to clipboard")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
        }

        Item { Layout.fillWidth: true }
    }

    LogosCheckbox {
        id: savedCheckBox
        objectName: "lezPhraseAcknowledgeCheckbox"
        text: qsTr("I've written down my recovery phrase and stored it safely")
        font.pixelSize: Theme.typography.secondaryText
    }

    Item { Layout.fillHeight: true }
}
