import QtQuick
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import Logos.Icons

// First-run landing: the name over the photograph and one way in
Item {
    id: root

    signal setupRequested()

    Image {
        anchors.fill: parent
        source: LogosIcons.onboardingBackdrop
        fillMode: Image.PreserveAspectCrop
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 80, 360)
        spacing: Theme.spacing.medium

        LogosText {
            Layout.fillWidth: true
            text: qsTr("LEZ Wallet")
            color: Theme.palette.text
            font.pixelSize: Theme.typography.pageTitleText
            font.weight: Theme.typography.weightBold
            horizontalAlignment: Text.AlignHCenter
        }

        LogosButton {
            objectName: "lezSetUpWalletButton"
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            variant: LogosButton.Variant.Primary
            font.pixelSize: Theme.typography.primaryText
            font.weight: Theme.typography.weightMedium
            text: qsTr("Set up your wallet")
            onClicked: root.setupRequested()
        }
    }
}
