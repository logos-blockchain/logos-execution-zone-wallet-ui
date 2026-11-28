import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../Units.js" as Units

// Shows what a simulated send would cost and lets the user override the fee
// before sending it for real. An empty field keeps the wallet's own value,
// which is the one shown above it.
LogosDialog {
    id: root

    // A dry-run result as lez_core returns it: { is_dry_run, dry_run, fee }.
    property var report: null
    property bool busy: false
    property string errorText: ""
    // Off for sends that carry a proof: their gas limit override excludes the
    // proof's verification gas, which the reported limit includes.
    property bool gasLimitEditable: true

    // Both carry lez_core's fee_params_json ("" when nothing is overridden).
    signal simulateRequested(string feeParamsJson)
    signal sendRequested(string feeParamsJson)

    readonly property var fee: report && report.fee ? report.fee : null
    readonly property var dryRun: report && report.dry_run ? report.dry_run : null
    readonly property bool isPublicFee: fee !== null && fee.kind === "public"
    // The sequencer refuses a public maximum fee below this.
    readonly property string minMaxFee: isPublicFee && dryRun ? dryRun.reserve_at_head : ""
    readonly property string typedMaxFee: Units.toLepta(Units.normalizeInput(maxFeeField.text))
    readonly property bool maxFeeTooLow: minMaxFee.length > 0 && typedMaxFee.length > 0
                                         && Units.compareLepta(typedMaxFee, minMaxFee) < 0
    readonly property string revertReason: dryRun && dryRun.revert_reason ? dryRun.revert_reason : ""
    readonly property bool inputValid: gasLimitField.textInput.acceptableInput
                                       && maxFeeField.textInput.acceptableInput
                                       && tipField.textInput.acceptableInput
                                       && headroomField.textInput.acceptableInput
    // The overrides the shown report was simulated with. Send stays off until
    // the fields match them again, so what is sent is what was reviewed.
    property string simulatedParams: ""
    readonly property bool reportIsCurrent: report !== null && feeParamsJson() === simulatedParams

    function reset() {
        report = null
        simulatedParams = ""
        errorText = ""
        gasLimitField.text = ""
        maxFeeField.text = ""
        tipField.text = ""
        headroomField.text = ""
        allowRevertBox.checked = false
    }

    function feeParamsJson(forSend) {
        var params = {}
        if (root.isPublicFee && root.gasLimitEditable && gasLimitField.text.length > 0)
            params.gas_limit = gasLimitField.text
        var maxFee = Units.toLepta(Units.normalizeInput(maxFeeField.text))
        if (root.isPublicFee && maxFee.length > 0)
            params.max_fee = maxFee
        var tip = Units.toLepta(Units.normalizeInput(tipField.text))
        if (tip.length > 0)
            params.tip = tip
        if (headroomField.text.length > 0)
            params.headroom_blocks = headroomField.text
        if (forSend && allowRevertBox.checked)
            params.allow_revert = true
        return Object.keys(params).length > 0 ? JSON.stringify(params) : ""
    }

    modal: true
    dim: true
    padding: Theme.spacing.large
    closePolicy: Popup.CloseOnEscape

    anchors.centerIn: parent

    component ReportRow: RowLayout {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: Theme.spacing.medium
        LogosText {
            text: label
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.textSecondary
        }
        LogosText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: value
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.text
        }
    }

    component FieldLabel: LogosText {
        font.pixelSize: Theme.typography.secondaryText
        color: Theme.palette.textSecondary
    }

    contentItem: ColumnLayout {
        width: 420
        spacing: Theme.spacing.medium

        LogosText {
            text: qsTr("Review fee")
            font.pixelSize: Theme.typography.titleText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        RowLayout {
            visible: root.busy
            spacing: Theme.spacing.small
            LogosSpinner {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                running: root.busy
            }
            LogosText {
                text: qsTr("Simulating…")
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.textSecondary
            }
        }

        LogosText {
            Layout.fillWidth: true
            visible: root.errorText.length > 0
            wrapMode: Text.WordWrap
            text: root.errorText
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.error
        }

        // What the simulation measured and what the send would declare.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.report !== null
            spacing: Theme.spacing.small

            ReportRow {
                label: qsTr("Estimated fee")
                value: root.dryRun ? Units.format(root.dryRun.fee_at_head) : ""
            }
            ReportRow {
                visible: root.isPublicFee
                label: qsTr("Gas limit")
                value: root.isPublicFee ? root.fee.gas_limit : ""
            }
            ReportRow {
                label: root.isPublicFee ? qsTr("Maximum fee") : qsTr("Reserved for the fee")
                value: !root.fee ? "" : Units.format(root.isPublicFee ? root.fee.max_fee : root.fee.reserve)
            }
            ReportRow {
                visible: root.minMaxFee.length > 0
                label: qsTr("Lowest accepted maximum fee")
                value: Units.format(root.minMaxFee)
            }
            ReportRow {
                label: qsTr("Tip")
                value: root.fee ? Units.format(root.fee.tip) : ""
            }
            ReportRow {
                visible: !root.isPublicFee
                label: qsTr("Fee headroom")
                value: root.dryRun ? qsTr("%1 blocks").arg(root.dryRun.headroom_blocks) : ""
            }
            LogosText {
                Layout.fillWidth: true
                visible: root.revertReason.length > 0
                wrapMode: Text.WordWrap
                text: qsTr("This transaction would revert: %1").arg(root.revertReason)
                font.pixelSize: Theme.typography.secondaryText
                color: Theme.palette.error
            }
        }

        LogosText {
            Layout.topMargin: Theme.spacing.small
            text: qsTr("Change the fee (optional)")
            font.pixelSize: Theme.typography.secondaryText
            font.weight: Theme.typography.weightBold
            color: Theme.palette.text
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacing.medium
            rowSpacing: Theme.spacing.small
            enabled: !root.busy

            FieldLabel { visible: root.isPublicFee && root.gasLimitEditable; text: qsTr("Gas limit") }
            LogosTextField {
                id: gasLimitField
                objectName: "feeGasLimitField"
                visible: root.isPublicFee && root.gasLimitEditable
                Layout.fillWidth: true
                validator: RegularExpressionValidator { regularExpression: /^[0-9]*$/ }
            }

            FieldLabel { visible: root.isPublicFee; text: qsTr("Maximum fee (%1)").arg(Units.SYMBOL) }
            LogosTextField {
                id: maxFeeField
                objectName: "feeMaxFeeField"
                visible: root.isPublicFee
                Layout.fillWidth: true
                validator: RegularExpressionValidator { regularExpression: Units.inputRegExp() }
            }

            FieldLabel { text: qsTr("Tip (%1)").arg(Units.SYMBOL) }
            LogosTextField {
                id: tipField
                objectName: "feeTipField"
                Layout.fillWidth: true
                validator: RegularExpressionValidator { regularExpression: Units.inputRegExp() }
            }

            // Prices the fee at the base fees this many blocks of the steepest climb ahead.
            FieldLabel { text: qsTr("Fee headroom (blocks)") }
            LogosTextField {
                id: headroomField
                objectName: "feeHeadroomField"
                Layout.fillWidth: true
                validator: RegularExpressionValidator { regularExpression: /^[0-9]*$/ }
            }
        }

        LogosText {
            Layout.fillWidth: true
            visible: root.maxFeeTooLow
            wrapMode: Text.WordWrap
            text: qsTr("The maximum fee is below the lowest the sequencer accepts.")
            font.pixelSize: Theme.typography.secondaryText
            color: Theme.palette.error
        }

        LogosCheckbox {
            id: allowRevertBox
            visible: root.revertReason.length > 0
            enabled: !root.busy
            text: qsTr("Send anyway (the fee is still charged)")
        }

        RowLayout {
            Layout.topMargin: Theme.spacing.small
            Layout.fillWidth: true
            spacing: Theme.spacing.medium
            LogosButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }
            Item { Layout.fillWidth: true }
            LogosButton {
                text: qsTr("Update estimate")
                enabled: !root.busy && root.inputValid && !root.maxFeeTooLow
                onClicked: root.simulateRequested(root.feeParamsJson())
            }
            LogosButton {
                objectName: "feeSendButton"
                text: qsTr("Send")
                // A send that would revert needs the explicit opt-in.
                enabled: !root.busy && root.inputValid && !root.maxFeeTooLow && root.reportIsCurrent
                         && (root.revertReason.length === 0 || allowRevertBox.checked)
                onClicked: root.sendRequested(root.feeParamsJson(true))
            }
        }
    }
}
