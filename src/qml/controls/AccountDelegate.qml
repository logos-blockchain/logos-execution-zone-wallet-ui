import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import "../Base58.js" as Base58
import "../Format.js" as Format

ItemDelegate {
    id: root

    // Emitted when the user clicks "Initialize" on an uninitialized account. The
    // parent wires this to backend.initializeAccount(...) — AccountDelegate doesn't
    // reach into the global QML scope for `backend` since it now lives behind the
    // logos.module() bridge in the parent view. Public-only: public account
    // initialization requires
    // authorization, so it requires a manual init signed by the owner. Private
    // accounts don't need authorization to initialize, so they never need this button.
    signal initializeRequested(string accountId)

    // Emitted when the user clicks "Add label", so the parent can open
    // SetLabelDialog for this account. Only reachable for unlabeled accounts —
    // the wallet core has no way to rename or remove a label once added.
    signal labelRequested(string accountId, bool isPublic)

    // Set by the parent while this account's initializeAccount() call is in flight,
    // so the button can show it took the click instead of appearing to do nothing.
    property bool initializing: false

    leftPadding: Theme.spacing.medium
    rightPadding: Theme.spacing.medium
    topPadding: Theme.spacing.medium
    bottomPadding: Theme.spacing.medium
    hoverEnabled: false

    background: Rectangle {
        color: root.highlighted || root.hovered ?
                   Theme.palette.backgroundSecondary :
                   Theme.palette.backgroundTertiary
        radius: Theme.spacing.radiusLarge
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacing.small
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            LogosText {
                text: model.name || ("Account " + Format.shortenHead(Base58.encode(model.accountId ?? "")))
                font.pixelSize: Theme.typography.secondaryText
                font.bold: true
            }

            LogosText {
                // The wallet core only supports adding a label, never renaming or
                // removing one — so once an account has one, there's nothing left
                // to offer here.
                text: qsTr("Add label")
                visible: !model.name
                font.pixelSize: Theme.typography.secondaryText
                font.underline: labelLinkArea.containsMouse
                color: Theme.palette.textMuted

                MouseArea {
                    id: labelLinkArea
                    anchors.fill: parent
                    anchors.margins: -Theme.spacing.small
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.labelRequested(model.accountId ?? "", model.isPublic ?? true)
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
            spacing: Theme.spacing.small

            LogosBadge {
                text: model.isPublic ? qsTr("Public") : qsTr("Private")
                color: Theme.palette.textSecondary
            }

            LogosBadge {
                text: model.isInitialized ? qsTr("Initialized") : qsTr("Uninitialized")
                color: model.isInitialized ? Theme.palette.success : Theme.palette.warning
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing:0
            LogosCopyableText {
                id: addressLabel
                Layout.fillWidth: true
                text: Format.shortenMiddle(Base58.encode(model.accountId ?? ""))
                copyText: Base58.encode(model.accountId ?? "")
                textColor: Theme.palette.textMuted
                visible: copyText.length > 0
            }
        }

        LogosButton {
            Layout.fillWidth: true
            visible: (model.isPublic ?? true) && !model.isInitialized
            enabled: !root.initializing
            text: root.initializing ? qsTr("Initializing…") : qsTr("Initialize")
            onClicked: root.initializeRequested(model.accountId ?? "")
        }
    }
}
