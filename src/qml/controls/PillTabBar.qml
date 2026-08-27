import QtQuick

import Logos.Theme
import Logos.Controls

// LogosTabBar customized into a segmented, pill-shaped bar for the *secondary*
// tab row of a panel.
//
// Public API (in addition to LogosTabBar's):
//     pillColor       fill of the selected segment (default: Theme.palette.surface)
//     containerColor  fill behind all segments (default: Theme.palette.surfaceRecessed)
//     pillPadding     inset between the container edge and the segments
//                     (default: Theme.spacing.tiny)
//
// Inherited properties that change meaning here:
//     trackColor      draws the container outline instead of a baseline
//                     (default: Theme.palette.border)
//     indicatorHeight unused — the pill is as tall as a segment
//
// Read-only inspection aliases: pillItem, containerItem
//
// Use with PillTabButton.
//
// Example:
//     PillTabBar {
//         id: bar
//         Layout.fillWidth: true
//         PillTabButton { text: qsTr("Withdraw") }
//         PillTabButton { text: qsTr("Claim Deposit") }
//     }
//
//     StackLayout {
//         currentIndex: bar.currentIndex
//         WithdrawPanel {}
//         ClaimDepositPanel {}
//     }
LogosTabBar {
    id: root

    property color pillColor: Theme.palette.surface
    property color containerColor: Theme.palette.surfaceRecessed
    property int pillPadding: Theme.spacing.tiny

    // Exposed for inspection (e.g., from tests). Read-only.
    readonly property alias pillItem: pill
    readonly property alias containerItem: container

    trackColor: Theme.palette.border

    leftPadding: root.pillPadding
    rightPadding: root.pillPadding
    topPadding: root.pillPadding
    bottomPadding: root.pillPadding

    background: Item {
        clip: true

        Rectangle {
            id: container
            anchors.fill: parent
            radius: Theme.spacing.radiusPill
            color: root.containerColor
            border.width: 1
            border.color: root.trackColor
        }

        Rectangle {
            id: pill

            z: 1
            color: root.pillColor
            radius: Theme.spacing.radiusPill

            property real slideX: 0
            property real slideY: 0
            property real slideWidth: 0
            property real slideHeight: 0

            // Animate only once the first real placement has landed, so the
            // pill doesn't visibly grow out of the left edge on first paint.
            property bool placed: false

            x: slideX
            y: slideY
            width: slideWidth
            height: slideHeight

            Behavior on x {
                enabled: pill.placed
                NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                enabled: pill.placed
                NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
            }

            function refresh() {
                if (!root.currentItem || root.currentItem.width <= 0)
                    return
                const p = root.currentItem.mapToItem(root, 0, 0)
                pill.slideX = p.x
                pill.slideY = p.y
                pill.slideWidth = root.currentItem.width
                pill.slideHeight = root.currentItem.height
                pill.placed = true
            }
        }
    }

    onCurrentItemChanged: Qt.callLater(pill.refresh)
    onWidthChanged: Qt.callLater(pill.refresh)
    onHeightChanged: Qt.callLater(pill.refresh)
    onVisibleChanged: if (visible) Qt.callLater(pill.refresh)
    Component.onCompleted: Qt.callLater(pill.refresh)

    Connections {
        target: root.currentItem
        ignoreUnknownSignals: true
        function onXChanged() { Qt.callLater(pill.refresh) }
        function onWidthChanged() { Qt.callLater(pill.refresh) }
        function onHeightChanged() { Qt.callLater(pill.refresh) }
    }

    Connections {
        target: root.contentItem
        ignoreUnknownSignals: true
        function onContentXChanged() { Qt.callLater(pill.refresh) }
        function onWidthChanged() { Qt.callLater(pill.refresh) }
    }
}
