import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

ItemDelegate {
    id: root

    implicitHeight: 80
    leftPadding: Theme.spacing.medium
    rightPadding: Theme.spacing.medium
    topPadding: Theme.spacing.medium
    bottomPadding: Theme.spacing.medium

    background: Rectangle {
        color: root.highlighted ? Theme.palette.backgroundMuted : "transparent"
        radius: Theme.spacing.radiusSmall
    }

    contentItem: RowLayout {
        spacing: Theme.spacing.small

        LogosText {
            text: model.name
            font.pixelSize: Theme.typography.secondaryText
            font.bold: true
        }

        Rectangle {
            Layout.preferredWidth: tagLabel.implicitWidth + Theme.spacing.small * 2
            Layout.preferredHeight: tagLabel.implicitHeight + 4
            radius: 2
            color: model.isPublic ? Theme.palette.backgroundElevated : Theme.palette.backgroundSecondary

            LogosText {
                id: tagLabel
                anchors.centerIn: parent
                text: model.isPublic ? qsTr("Public") : qsTr("Private")
                font.pixelSize: Theme.typography.captionText
                color: Theme.palette.textSecondary
            }
        }

        Item { Layout.fillWidth: true }

        LogosText {
            text: model.balance && model.balance.length > 0 ? model.balance : "—"
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
        }
    }
}
