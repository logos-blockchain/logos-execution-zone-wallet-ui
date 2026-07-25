import QtQuick

import Logos.Theme
import Logos.Controls

// Drop-in replacement for LogosButton that darkens while pressed. LogosButton's
// own background only reacts to isActive (hover OR press, same color for both),
// so a click on an already-hovered button showed no visible change at all.
LogosButton {
    id: root

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.palette.text
        opacity: root.mouseAreaItem.pressed ? 0.15 : 0
    }
}
