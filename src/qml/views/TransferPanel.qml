import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    // --- Public API: data in ---
    property var fromAccountModel: null  // LEZAccountFilterModel from backend (filtered by public/private)
    property string transferResult: ""

    // --- Public API: signals out ---
    signal transferRequested(bool isPublic, string fromAccountId, string toAddress, string amount)

    readonly property int fromFilterCount: fromAccountModel ? fromAccountModel.count : 0

    QtObject {
        id: d
        readonly property bool sendEnabled: toField && amountField && manualFromField
                                            && toField.text.length > 0 && amountField.text.length > 0
                                            && ((fromFilterCount > 0 && fromCombo.currentIndex >= 0)
                                                || (fromFilterCount === 0 && manualFromField.text.trim().length > 0))
    }

    Binding {
        target: fromAccountModel
        property: "filterByPublic"
        value: transferTypeBar.currentIndex === 0
        when: fromAccountModel != null
    }

    radius: Theme.spacing.radiusXlarge
    color: Theme.palette.backgroundSecondary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing.large
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Transfer")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        // Transfer type toggle
        TabBar {
            id: transferTypeBar
            Layout.preferredWidth: 200
            currentIndex: 0

            background: Rectangle {
                color: Theme.palette.backgroundSecondary
                radius: Theme.spacing.radiusSmall
            }

            LogosTabButton {
                text: qsTr("Public")
            }

            LogosTabButton {
                text: qsTr("Private")
            }
        }

        // From: dropdown when accounts exist, or manual entry when list is empty
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("From")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosTextField {
                id: manualFromField
                Layout.fillWidth: true
                placeholderText: qsTr("Paste or type from address")
                visible: fromFilterCount === 0
            }

            ComboBox {
                id: fromCombo
                Layout.fillWidth: true
                leftPadding: 12
                rightPadding: 12
                implicitHeight: 40
                model: fromAccountModel
                textRole: "name"
                valueRole: "address"
                visible: fromFilterCount > 0

                background: Rectangle {
                    radius: Theme.spacing.radiusSmall
                    color: Theme.palette.backgroundSecondary
                    border.width: 1
                    border.color: fromCombo.popup.visible ? Theme.palette.overlayOrange : Theme.palette.backgroundElevated
                }

                indicator: LogosText {
                    id: indicatorText
                    text: "▼"
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                    x: fromCombo.width - width - 12
                    y: (fromCombo.height - height) / 2
                    visible: fromCombo.count > 0
                }

                contentItem: TextInput {
                    readOnly: true
                    selectByMouse: true
                    width: fromCombo.width - indicatorText.width - 12
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.text
                    text: fromCombo.currentValue ?? ""
                    verticalAlignment: Text.AlignVCenter
                    clip: true
                }

                delegate: ItemDelegate {
                    id: delegate
                    width: fromCombo.width
                    leftPadding: 12
                    rightPadding: 12
                    contentItem: LogosText {
                        width: parent.width - parent.leftPadding - parent.rightPadding
                        font.pixelSize: Theme.typography.secondaryText
                        color: Theme.palette.text
                        text: model.name
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: delegate.highlighted
                               ? Theme.palette.backgroundElevated
                               : Theme.palette.backgroundSecondary
                    }
                    highlighted: fromCombo.highlightedIndex === index
                }

                popup: Popup {
                    y: fromCombo.height - 1
                    width: fromCombo.width
                    height: Math.min(contentItem.implicitHeight + 8, 300)
                    padding: 0

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: fromCombo.popup.visible ? fromCombo.delegateModel : null
                        ScrollIndicator.vertical: ScrollIndicator { }
                        highlightFollowsCurrentItem: false
                    }

                    background: Rectangle {
                        color: Theme.palette.backgroundSecondary
                        border.width: 1
                        border.color: Theme.palette.backgroundElevated
                        radius: Theme.spacing.radiusSmall
                    }
                }
            }
        }

        // To field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("To")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosTextField {
                id: toField
                Layout.fillWidth: true
                placeholderText: qsTr("Recipient public key")
            }
        }

        // Amount field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: qsTr("Amount")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }

            LogosTextField {
                id: amountField
                Layout.fillWidth: true
                placeholderText: "0.00"
            }
        }

        // Send button
        LogosButton {
            Layout.fillWidth: true
            text: qsTr("Send")
            font.pixelSize: Theme.typography.secondaryText
            enabled: d.sendEnabled
            onClicked: {
                var fromId = fromFilterCount > 0 && fromCombo.currentIndex >= 0
                        ? (fromCombo.currentValue ?? "")
                        : manualFromField.text.trim()
                if (fromId.length > 0)
                    root.transferRequested(transferTypeBar.currentIndex === 0, fromId, toField.text.trim(), amountField.text.trim())
            }
        }

        // Result label
        LogosText {
            Layout.fillWidth: true
            text: root.transferResult
            font.pixelSize: Theme.typography.secondaryText
            color: root.transferResult.length > 0 ? Theme.palette.textSecondary : "transparent"
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
