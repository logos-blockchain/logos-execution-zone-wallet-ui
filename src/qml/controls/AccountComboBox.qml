import QtQuick

import Logos.Controls
import "../Base58.js" as Base58
import "../Format.js" as Format

LogosComboBox {
    id: root

    textRole: "name"
    valueRole: "accountId"
    displayText: currentValue
                 ? qsTr("Account %1").arg(Format.shortenHead(Base58.encode(currentValue)))
                 : ""

    implicitHeight: 40

    Binding {
        target: root.popupItem
        property: "implicitHeight"
        value: Math.min(root.popupListView.contentHeight + 2, 300)
    }

    delegate: AccountDelegate {
        width: root.popupItem ? root.popupItem.availableWidth : root.width
        highlighted: root.highlightedIndex === index
        hoverEnabled: true
    }
}
