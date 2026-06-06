import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import "../Base58.js" as Base58

ComboBox {
    id: root

    // Forwarded from AccountDelegate's copy button — bubble up to the parent
    // view, which calls backend.copyToClipboard().
    signal copyRequested(string text)
    signal copyPublicKeysRequested(string accountIdHex)

    leftPadding: 12
    rightPadding: 12
    implicitHeight: 40
    textRole: "name"
    valueRole: "address"

    background: Rectangle {
        radius: Theme.spacing.radiusSmall
        color: Theme.palette.backgroundSecondary
        border.width: 1
        border.color: root.popup.visible ? Theme.palette.overlayOrange : Theme.palette.backgroundElevated
    }

    indicator: LogosText {
        id: indicatorText
        text: "▼"
        font.pixelSize: Theme.typography.secondaryText
        color: Theme.palette.textSecondary
        x: root.width - width - 12
        y: (root.height - height) / 2
        visible: root.count > 0
    }

    contentItem: Item {
        implicitWidth: 120
        width: root.width - indicatorText.width - 12
        TextInput {
            id: comboContentInput
            anchors.fill: parent
            readOnly: true
            selectByMouse: true
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.text
            text: root.currentValue ? ("Account " + Base58.encode(root.currentValue).substring(0, 6)) : root.displayText
            verticalAlignment: Text.AlignVCenter
            clip: true
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.popup.visible ? root.popup.close() : root.popup.open()
        }
    }

    delegate: AccountDelegate {
        width: root.popup ? (root.popup.width - root.popup.leftPadding - root.popup.rightPadding) : 368
        highlighted: root.highlightedIndex === index
        onCopyRequested: (text) => root.copyRequested(text)
        onCopyPublicKeysRequested: (id) => root.copyPublicKeysRequested(id)
    }

    popup: Popup {
        y: root.height - 1
        width: 400
        height: Math.min(contentItem.implicitHeight + 8, 300)
        padding: Theme.spacing.small

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            ScrollIndicator.vertical: ScrollIndicator { }
            highlightFollowsCurrentItem: false
        }

        background: Rectangle {
            color: Theme.palette.backgroundTertiary
            border.width: 1
            border.color: Theme.palette.backgroundElevated
            radius: Theme.spacing.radiusSmall
        }
    }
}
