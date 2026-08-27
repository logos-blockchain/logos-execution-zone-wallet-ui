import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Logos.Theme
import Logos.Controls

ColumnLayout {
    id: root

    property string label: ""
    property string placeholder: ""
    property alias path: field.text
    property alias fieldObjectName: field.objectName

    // Exposed for inspection (e.g. from tests). Read-only.
    readonly property alias fieldItem: field
    readonly property alias browseButtonItem: browseButton

    signal pathEdited()

    spacing: Theme.spacing.small

    QtObject {
        id: d

        // Reopen the picker where the user last was, not at some default.
        function parentFolderUrl(path) {
            if (!path || path.length === 0) return ""
            var i = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
            if (i <= 0) return ""
            var dir = path.substring(0, i)
            return dir.indexOf("file://") === 0 ? dir : "file://" + dir
        }
        function toPlainPath(fileUrl) {
            return decodeURIComponent(fileUrl.toString().replace(/^file:\/\//, ""))
        }
    }

    LogosText {
        text: root.label
        font.pixelSize: Theme.typography.secondaryText
        font.weight: Theme.typography.weightMedium
        color: Theme.palette.text
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.small

        LogosTextField {
            id: field
            Layout.fillWidth: true
            placeholderText: root.placeholder
            onTextChanged: root.pathEdited()
        }

        LogosButton {
            id: browseButton
            Layout.preferredHeight: field.height
            text: qsTr("Browse")
            onClicked: dialog.open()
        }
    }

    FileDialog {
        id: dialog
        modality: Qt.NonModal
        nameFilters: ["JSON files (*.json)", "All files (*)"]
        currentFolder: d.parentFolderUrl(field.text)
        onAccepted: field.text = d.toPlainPath(selectedFile)
    }
}
