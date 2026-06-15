import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import "../Base58.js" as Base58

ItemDelegate {
    id: root

    // Emitted when the user clicks the copy icon. The parent connects this
    // to backend.copyToClipboard(...) — AccountDelegate doesn't reach into
    // the global QML scope for `backend` since it now lives behind the
    // logos.module() bridge in the parent view.
    signal copyRequested(string text)
    signal copyPublicKeysRequested(string accountIdHex)

    leftPadding: Theme.spacing.medium
    rightPadding: Theme.spacing.medium
    topPadding: Theme.spacing.medium
    bottomPadding: Theme.spacing.medium

    background: Rectangle {
        color: root.highlighted || root.hovered ?
                   Theme.palette.backgroundMuted :
                   Theme.palette.backgroundTertiary
        radius: Theme.spacing.radiusLarge
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: model.name || ("Account " + Base58.encode(model.accountId ?? "").slice(0, 4))
                font.pixelSize: Theme.typography.secondaryText
                font.bold: true
            }

            Rectangle {
                Layout.preferredWidth: tagLabel.implicitWidth + Theme.spacing.small * 2
                Layout.preferredHeight: tagLabel.implicitHeight + 4
                radius: 4
                color: Theme.palette.backgroundSecondary

                LogosText {
                    id: tagLabel
                    anchors.centerIn: parent
                    text: model.isPublic ? qsTr("Public") : qsTr("Private")
                    font.pixelSize: Theme.typography.secondaryText
                    color: Theme.palette.textSecondary
                }
            }

            Item { Layout.fillWidth: true }

            LogosText {
                text: model.balance && model.balance.length > 0 ? model.balance : "—"
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing:0
            LogosText {
                id: addressLabel
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                text: Base58.encode(model.accountId ?? "")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textMuted
                elide: Text.ElideMiddle
            }
            LogosCopyButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                onCopyText: model.isPublic
                    ? root.copyRequested(Base58.encode(model.accountId ?? ""))
                    : root.copyPublicKeysRequested(model.accountId ?? "")
                visible: addressLabel.text
                icon.color: Theme.palette.textMuted
            }
        }
    }
}
