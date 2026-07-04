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

    // Emitted when the user clicks "Initialize" on an uninitialized account. The
    // parent wires this to backend.initializeAccount(...) for the same reason as
    // copyRequested above.
    signal initializeRequested(string accountId, bool isPublic)

    // Set by the parent while this account's initializeAccount() call is in flight,
    // so the button can show it took the click instead of appearing to do nothing.
    property bool initializing: false

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

            Rectangle {
                Layout.preferredWidth: initLabel.implicitWidth + Theme.spacing.small * 2
                Layout.preferredHeight: initLabel.implicitHeight + 4
                radius: 4
                color: Theme.colors.getColor(
                    model.isInitialized ? Theme.palette.success : Theme.palette.warning, 0.18)

                LogosText {
                    id: initLabel
                    anchors.centerIn: parent
                    text: model.isInitialized ? qsTr("Initialized") : qsTr("Uninitialized")
                    font.pixelSize: Theme.typography.secondaryText
                    color: model.isInitialized ? Theme.palette.success : Theme.palette.warning
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
                onCopyText: root.copyRequested(Base58.encode(model.accountId ?? ""))
                visible: addressLabel.text
                icon.color: Theme.palette.textMuted
            }
        }

        FeedbackButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            visible: (model.isPublic ?? true) && !model.isInitialized
            enabled: !root.initializing
            text: root.initializing ? qsTr("Initializing…") : qsTr("Initialize")
            onClicked: root.initializeRequested(model.accountId ?? "", model.isPublic ?? true)
        }
    }
}
