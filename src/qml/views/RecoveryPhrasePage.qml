import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

Control {
    id: root

    property string mnemonic: ""

    signal acknowledged()

    readonly property var words: {
        const t = mnemonic.trim()
        return t.length > 0 ? t.split(/\s+/) : []
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.xlarge
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Your recovery phrase")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        LogosText {
            Layout.fillWidth: true
            text: qsTr("Write these words down and keep them somewhere safe. This is the only " +
                       "time they will be shown, and anyone who has them can spend your funds.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            wrapMode: Text.WordWrap
        }

        LogosFrame {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small

            GridLayout {
                columns: 4
                columnSpacing: Theme.spacing.medium
                rowSpacing: Theme.spacing.small

                Repeater {
                    model: root.words
                    delegate: RowLayout {
                        spacing: Theme.spacing.small
                        LogosText {
                            text: (index + 1) + "."
                            font.pixelSize: Theme.typography.secondaryText
                            color: Theme.palette.textSecondary
                        }
                        LogosText {
                            text: modelData
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
        }

        Item { Layout.fillHeight: true }

        FeedbackButton {
            Layout.alignment: Qt.AlignRight
            text: qsTr("I have saved it")
            font.pixelSize: Theme.typography.secondaryText
            onClicked: root.acknowledged()
        }
    }
}
