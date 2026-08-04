import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

Control {
    id: root

    property string walletState: "closed"
    property string walletErrorCode: ""
    property string walletError: ""

    signal retryRequested()

    readonly property bool isOpening: walletState === "closed"
    readonly property bool isMissing: walletState === "missing"
    readonly property bool hasError: walletState === "error"

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacing.xlarge * 2, 560)
        spacing: Theme.spacing.large

        LogosText {
            Layout.fillWidth: true
            text: root.isOpening
                ? qsTr("Opening shared wallet")
                : root.isMissing
                    ? qsTr("Shared wallet not set up")
                    : qsTr("Shared wallet unavailable")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: root.isOpening
            visible: running
        }

        LogosText {
            Layout.fillWidth: true
            visible: root.isOpening
            text: qsTr("Connecting to the wallet profile shared by modules in this Basecamp instance…")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        LogosText {
            Layout.fillWidth: true
            visible: root.isMissing
            text: qsTr("This version can open an existing shared wallet, but secure create and restore are not available yet. Existing wallet files and legacy settings have not been moved, changed, or deleted.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        LogosText {
            Layout.fillWidth: true
            visible: root.hasError
            text: root.walletError || qsTr("The shared wallet could not be opened. Try again.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.error
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        LogosText {
            Layout.fillWidth: true
            visible: root.hasError && root.walletErrorCode.length > 0
            text: qsTr("Error code: %1").arg(root.walletErrorCode)
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        FeedbackButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.isMissing || root.hasError
            text: qsTr("Try again")
            onClicked: root.retryRequested()
        }
    }
}
