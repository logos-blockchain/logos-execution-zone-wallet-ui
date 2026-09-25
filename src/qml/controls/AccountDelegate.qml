import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import "../Base58.js" as Base58
import "../Format.js" as Format

ItemDelegate {
    id: root

    // Emitted when the user clicks the name button, so the parent can open
    // SetLabelDialog for this account. Only offered for unnamed accounts: the
    // wallet core exposes add_label with no rename or remove, and an account's
    // name is every label it carries joined — so a second save would append a
    // name rather than change the first.
    signal labelRequested(string accountId, bool isPublic)

    // No card: a rounded filled box per row read as a container inside a
    // container and squeezed the row's controls. Rows are separated by a rule
    // instead, and the full panel width is theirs.
    leftPadding: 0
    rightPadding: 0
    topPadding: Theme.spacing.medium
    bottomPadding: Theme.spacing.medium
    hoverEnabled: false

    background: Rectangle {
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.palette.border
        }
    }

    // Name and tags on one line, then the address, then the balance — the order
    // from the design. The name is primaryText rather than the design's small
    // caption so it stays the most readable thing in the row, which is what it
    // is for.
    contentItem: ColumnLayout {
        spacing: Theme.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            // fillWidth so it can shrink, maximumWidth so it never grows past
            // its natural size — without both, a long name pushes the badges and
            // the edit button off the row instead of eliding.
            LogosText {
                id: nameLabel
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.maximumWidth: implicitWidth
                elide: Text.ElideRight
                text: model.name || ("Account " + Format.shortenHead(Base58.encode(model.accountId ?? "")))
                font.pixelSize: Theme.typography.secondaryText
                font.bold: true
                color: Theme.palette.textSecondary

                HoverHandler { id: nameHover }

                // Only when there is something the row is not showing.
                LogosToolTip {
                    visible: nameLabel.truncated && nameHover.hovered
                    text: nameLabel.text
                }
            }

            LogosBadge {
                text: model.isPublic ? qsTr("Public") : qsTr("Private")
                color: Theme.palette.textSecondary
                radius: Theme.spacing.radiusPill
                labelItem.font.pixelSize: 9
            }

            LogosBadge {
                // A public account is claimed by its first funded transfer (fees
                // rule out a bare init); private ones initialize on first use.
                text: model.isInitialized ? qsTr("Initialized")
                    : (model.isPublic ?? true) ? qsTr("Unclaimed · fund to claim") : qsTr("Uninitialized")
                color: model.isInitialized ? Theme.palette.success : Theme.palette.warning
                radius: Theme.spacing.radiusPill
                labelItem.font.pixelSize: 9
            }

            Item { Layout.fillWidth: true }

            LogosIconButton {
                objectName: "lezEditNameButton"
                flat: true
                size: 28
                iconSize: 16
                iconSource: Qt.resolvedUrl("../icons/edit.svg")
                iconColor: Theme.palette.textTertiary
                visible: !model.name
                onClicked: root.labelRequested(model.accountId ?? "", model.isPublic ?? true)
            }
        }

        LogosCopyableText {
            id: addressLabel
            Layout.fillWidth: true
            text: Format.shortenMiddle(Base58.encode(model.accountId ?? ""))
            copyText: Base58.encode(model.accountId ?? "")
            textColor: Theme.palette.text
            font.pixelSize: Theme.typography.primaryText
            visible: copyText.length > 0
        }

        LogosText {
            text: model.balance && model.balance.length > 0 ? model.balance : "—"
            font.bold: true
            color: Theme.palette.primary
        }
    }
}
