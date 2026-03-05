import QtQuick
import QtQuick.Controls

import Logos.Theme

Button {
    id: root

    signal copyText()

    implicitWidth: 24
    implicitHeight: 24
    display: AbstractButton.IconOnly
    flat: true

    property string iconSource: "qrc:/lezwallet/icons/copy.svg"

    icon.source: root.iconSource
    icon.width: 24
    icon.height: 24
    icon.color: Theme.palette.textSecondary

    function reset() {
        iconSource = "qrc:/lezwallet/icons/copy.svg"
    }

    Timer {
        id: resetTimer
        interval: 1500
        repeat: false
        onTriggered: root.reset()
    }

    onClicked: {
        root.copyText()
        root.iconSource = "qrc:/lezwallet/icons/checkmark.svg"
        resetTimer.restart()
    }
}
