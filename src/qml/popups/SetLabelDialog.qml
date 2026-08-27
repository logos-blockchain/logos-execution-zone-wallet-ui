import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls


LogosDialog {
    id: root

    // Context set by the parent right before open(). Only ever opened for an
    // unlabeled account — the wallet core has no way to rename or remove a label
    // once added, so there's no "current label" to prefill or compare against.
    property string accountId: ""
    property bool isPublic: true

    // Debounced availability-check result. The parent owns the backend connection,
    // so it drives these two properties in response to checkAvailabilityRequested.
    property bool checkingAvailability: false
    property bool labelAvailable: true

    // Save round-trip state, likewise driven by the parent: saving stays true and the
    // popup stays open until the parent reports success (closeOnSaveSuccess) or failure
    // (reportSaveError) — so a failed save isn't silently swallowed by an immediate close.
    property bool saving: false
    property string saveError: ""

    signal checkAvailabilityRequested(string label)
    signal saveRequested(string accountId, bool isPublic, string label)

    function closeOnSaveSuccess() {
        root.saving = false
        root.close()
    }

    function reportSaveError(message) {
        root.saving = false
        root.saveError = message
    }

    readonly property string trimmedText: labelField.text.trim()
    readonly property bool saveEnabled: trimmedText.length > 0
                                         && root.labelAvailable && !root.checkingAvailability

    modal: true
    dim: true
    padding: Theme.spacing.large
    // No dismissal while a save is in flight — mirrors the disabled Cancel/Save
    // buttons below, so a stale response can't land on a dialog the user thinks
    // they already closed.
    closePolicy: root.saving ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    anchors.centerIn: parent


    onOpened: {
        labelField.text = ""
        root.labelAvailable = true
        root.checkingAvailability = false
        root.saving = false
        root.saveError = ""
        labelField.forceActiveFocus()
        labelField.selectAll()
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: {
            if (root.trimmedText.length > 0) {
                root.checkingAvailability = true
                root.checkAvailabilityRequested(root.trimmedText)
            } else {
                root.checkingAvailability = false
            }
        }
    }

    contentItem: ColumnLayout {
        width: 320
        spacing: Theme.spacing.large

        LogosText {
            text: qsTr("Add label")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        LogosTextField {
            id: labelField
            Layout.fillWidth: true
            enabled: !root.saving
            onTextChanged: {
                root.saveError = ""
                // Mark as checking immediately so saveEnabled can't go true on stale
                // (or no) availability data during the debounce window — the Timer
                // below only confirms/updates the result once typing settles.
                root.checkingAvailability = root.trimmedText.length > 0
                debounce.restart()
            }
        }

        LogosText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.error
            visible: root.trimmedText.length > 0 && !root.checkingAvailability && !root.labelAvailable
            text: qsTr("That label is already in use.")
        }

        LogosSelectableText {
            Layout.fillWidth: true
            wrapMode: TextEdit.WordWrap
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.error
            visible: root.saveError.length > 0
            text: root.saveError
        }

        RowLayout {
            Layout.topMargin: Theme.spacing.medium
            spacing: Theme.spacing.medium
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            LogosButton {
                text: qsTr("Cancel")
                enabled: !root.saving
                onClicked: root.close()
            }
            LogosButton {
                text: root.saving ? qsTr("Saving…") : qsTr("Save")
                enabled: root.saveEnabled && !root.saving
                onClicked: {
                    root.saving = true
                    root.saveError = ""
                    root.saveRequested(root.accountId, root.isPublic, root.trimmedText)
                }
            }
        }
    }
}
