import QtQuick

import Logos.Theme
import Logos.Controls

// LogosTabButton customized for use as a segment inside a PillTabBar.
//
// The bar owns the selected-segment pill, so the button only carries the label
// treatment: white and bold when selected, subtle grey otherwise. Keyboard
// focus draws a pill outline rather than LogosTabButton's underline, which
// would cut across the bar's rounded container. The segment always reserves
// the width of its bold label, so switching selection slides the pill without
// re-laying out the row.
//
// Public API (in addition to LogosTabButton's):
//     badgeCount     count shown in a filled badge after the label. 0 hides the
//                    badge; anything over 99 shows "99+" so a large count can't
//                    stretch the segment. (default: 0)
//
// Inherited from LogosTabButton, with wallet defaults:
//     activeColor    label color when selected   (default: Theme.palette.text)
//     inactiveColor  label color when unselected (default: Theme.palette.textSubtle)
//
// Read-only inspection aliases (in addition to LogosTabButton's):
//     focusRingItem, badgeItem
LogosTabButton {
    id: root

    property int badgeCount: 0

    readonly property alias focusRingItem: focusRing
    readonly property alias badgeItem: badge

    activeColor: Theme.palette.text
    inactiveColor: Theme.palette.textSubtle

    leftPadding: Theme.spacing.large
    rightPadding: Theme.spacing.large

    font.weight: root.checked ? Theme.typography.weightBold
                              : Theme.typography.weightMedium

    background: Rectangle {
        id: focusRing
        radius: Theme.spacing.radiusPill
        color: "transparent"
        border.width: 1
        border.color: root.visualFocus && !root.checked ? Theme.palette.overlayOrange
                                                        : "transparent"
    }

    contentItem: Item {
        implicitWidth: boldMetrics.width
                       + (badge.visible ? row.spacing + badge.implicitWidth : 0)
        implicitHeight: Math.max(label.implicitHeight,
                                 badge.visible ? badge.implicitHeight : 0)

        TextMetrics {
            id: boldMetrics
            font.family: root.font.family
            font.pixelSize: root.font.pixelSize
            font.weight: Theme.typography.weightBold
            text: root.text
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.spacing.small

            LogosText {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font: root.font
                color: root.checked ? root.activeColor : root.inactiveColor
            }

            LogosBadge {
                id: badge
                anchors.verticalCenter: parent.verticalCenter
                visible: root.badgeCount > 0
                text: root.badgeCount > 99 ? qsTr("99+") : String(root.badgeCount)
                color: Theme.palette.background
                backgroundColor: Theme.palette.primary
                borderWidth: 0
                radius: Theme.spacing.radiusPill
            }
        }
    }
}
