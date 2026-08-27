import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

Control {
    id: root

    property string message: qsTr("Opening your wallet…")

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacing.large

        LogosSpinner {
            Layout.alignment: Qt.AlignHCenter
            running: true
        }

        LogosText {
            objectName: "lezLoadingMessage"
            Layout.alignment: Qt.AlignHCenter
            text: root.message
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
        }
    }
}
