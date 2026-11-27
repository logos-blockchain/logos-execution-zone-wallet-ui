import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import "views"
import "popups"

Rectangle {
    id: root

    readonly property var backend: logos.module("lez_wallet_ui")
    readonly property var accountModel: logos.model("lez_wallet_ui", "accountModel")
    readonly property var publicAccountModel: logos.model("lez_wallet_ui", "filteredAccountModel")
    readonly property var privateAccountModel: logos.model("lez_wallet_ui", "privateAccountModel")
    property bool ready: false

    Connections {
        target: logos
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName === "lez_wallet_ui")
                root.ready = isReady && root.backend !== null
        }
    }

    // Map wallet FFI error codes to user-facing strings. Matches lssa/core-ffi FfiOperationError enum.
    QtObject {
        id: ffiErrors
        readonly property var codeToMessage: ({
            0: qsTr("Success"),
            1: qsTr("Invalid argument (null pointer)"),
            2: qsTr("Invalid UTF-8 string"),
            3: qsTr("Invalid argument (malformed or unappiable)"),
            4: qsTr("Sequencer not initialized"),
            5: qsTr("Wallet not initialized"),
            6: qsTr("Configuration error"),
            7: qsTr("Storage or persistence error"),
            8: qsTr("Network or RPC error"),
            9: qsTr("Query failed"),
            10: qsTr("Account not found"),
            11: qsTr("Key not found for account"),
            12: qsTr("Insufficient funds"),
            13: qsTr("Invalid account ID format"),
            14: qsTr("Runtime error"),
            15: qsTr("Password required but not provided"),
            16: qsTr("Block synchronization error"),
            17: qsTr("Serialization error"),
            18: qsTr("Invalid type conversion"),
            19: qsTr("Invalid key value"),
            20: qsTr("Invalid program bytecode"),
            // Fee-admission refusal: distinct from 9, which is the transfer amount check.
            21: qsTr("Insufficient balance to cover the transaction fee"),
            22: qsTr("Not supported"),
            23: qsTr("Response too big"),
            24: qsTr("Message not found"),
            25: qsTr("Wrong password, does not open the wallet storage, or the storage is corrupted"),
            26: qsTr("Would revert"),
            99: qsTr("Internal error")
        })
        function format(errorMessage) {
            if (!errorMessage || typeof errorMessage !== "string")
                return errorMessage || ""
            var match = errorMessage.match(/wallet FFI error (\d+)/)
            if (match) {
                var code = match[1]
                var msg = codeToMessage[code]
                if (msg)
                    return msg
                return qsTr("Wallet error (code %1)").arg(code)
            }
            return errorMessage
        }

        // Parse a transfer result JSON string and write to dashboardView.
        function applyTransferResult(dashboardView, raw) {
            var msg = raw || ""
            var isError = false
            try {
                var obj = JSON.parse(raw)
                if (obj.success) {
                    msg = obj.tx_hash ? qsTr("Success. Tx: %1").arg(obj.tx_hash) : qsTr("Success.")
                } else if (obj.error) {
                    msg = ffiErrors.format(obj.error)
                    isError = true
                }
            } catch (e) {
                if (msg.length > 0) isError = true
            }
            dashboardView.transferResult = msg
            dashboardView.transferResultIsError = isError
            dashboardView.transferTxHash = (obj && obj.tx_hash) ? obj.tx_hash : ""
        }
    }

    QtObject {
        id: d
        readonly property bool isWalletOpen: backend && backend.isWalletOpen
        // Until this is true the backend has not finished deciding whether there
        // is a wallet to open, so "not open" carries no information yet.
        readonly property bool isStartupResolved: backend !== null && backend.isStartupResolved
        // A saved wallet waits for its password before it can open.
        readonly property bool needsPassword: backend !== null && backend.needsPassword

        onIsStartupResolvedChanged: if (root.ready) updateStack(isWalletOpen)

        property var currentComponent: null

        function updateStack(walletOpen) {
            const target = !isStartupResolved ? loadingView
                         : (walletOpen ? mainView : onboardingView)
            if (currentComponent === target)
                return
            currentComponent = target
            stackView.replace(target)
        }

        property string noticeMessage: ""
        property int noticeSeverity: LogosNotice.Error
        function showNotice(severity, message) {
            if (!message || message.length === 0) {
                noticeMessage = ""
                bottomNotice.shown = false
                return
            }
            noticeSeverity = severity
            noticeMessage = message
            bottomNotice.show()
        }
    }

    // A notice raised at startup (saved files gone, a wallet that can't be read) can come before
    // the view is connected: show what the backend holds once it is ready.
    onReadyChanged: {
        if (!ready) return
        d.updateStack(d.isWalletOpen)
        d.showNotice(LogosNotice.Error, root.backend.notice)
    }

    Component.onCompleted: {
        root.ready = root.backend !== null
            && logos.isViewModuleReady("lez_wallet_ui")
        if (root.ready) d.updateStack(d.isWalletOpen)
        if (root.backend)
            d.showNotice(LogosNotice.Error, root.backend.notice)
    }

    Connections {
        target: backend
        enabled: backend !== null
        function onNoticeChanged() {
            d.showNotice(LogosNotice.Error, backend.notice)
        }
    }

    color: Theme.palette.background

    // One send at a time: simulate it, let the user review and adjust the fee,
    // then send it with exactly the overrides that were reviewed.
    QtObject {
        id: sendFlow

        property var dashboard: null
        // The backend slot and its (from, to, amount) arguments.
        property string slot: ""
        property var args: []
        // Whether the real send generates a proof, which takes a while.
        property bool proves: false
        // Bumped per send, so a late result of an earlier one is dropped.
        property int generation: 0

        function begin(dashboardView, slotName, slotArgs, generatesProof) {
            if (!backend) return
            dashboard = dashboardView
            slot = slotName
            args = slotArgs
            proves = generatesProof
            generation += 1
            if (!dashboardView.previewFee) {
                send("")
                return
            }
            feeDialog.reset()
            feeDialog.gasLimitEditable = !generatesProof
            feeDialog.open()
            simulate("")
        }

        function call(feeParamsJson, dryRun, onResult) {
            logos.watch(backend[slot](args[0], args[1], args[2], feeParamsJson, dryRun),
                onResult,
                function(error) { onResult(JSON.stringify({ success: false, error: qsTr("Error: %1").arg(error) })) })
        }

        function simulate(feeParamsJson) {
            feeDialog.busy = true
            feeDialog.errorText = ""
            const asked = generation
            call(feeParamsJson, true, function(raw) {
                if (asked !== generation) return
                feeDialog.busy = false
                var obj = null
                try { obj = JSON.parse(raw) } catch (e) {}
                if (obj && obj.success && obj.is_dry_run) {
                    feeDialog.simulatedParams = feeParamsJson
                    feeDialog.report = obj
                } else {
                    feeDialog.report = null
                    feeDialog.errorText = ffiErrors.format(obj && obj.error ? obj.error : raw)
                }
            })
        }

        function send(feeParamsJson) {
            feeDialog.close()
            dashboard.transferPending = proves
            call(feeParamsJson, false, function(raw) {
                dashboard.transferPending = false
                ffiErrors.applyTransferResult(dashboard, raw)
            })
        }
    }

    FeeConfirmDialog {
        id: feeDialog
        onSimulateRequested: (feeParamsJson) => sendFlow.simulate(feeParamsJson)
        onSendRequested: (feeParamsJson) => sendFlow.send(feeParamsJson)
    }

    SetLabelDialog {
        id: setLabelDialog

        onCheckAvailabilityRequested: (label) => {
            if (!backend) return
            logos.watch(backend.checkLabelAvailable(label),
                function(available) {
                    // The user may have kept typing while this round-trip was in
                    // flight — only apply the result if it still matches the
                    // current text, otherwise it's stale.
                    if (label === setLabelDialog.trimmedText) {
                        setLabelDialog.checkingAvailability = false
                        setLabelDialog.labelAvailable = available
                    }
                },
                function(error) {
                    console.warn("checkLabelAvailable failed:", error)
                    if (label === setLabelDialog.trimmedText) {
                        setLabelDialog.checkingAvailability = false
                        // Fail open — addLabel() itself still validates on submit.
                        setLabelDialog.labelAvailable = true
                    }
                })
        }

        onSaveRequested: (accountId, isPublic, label) => {
            if (!backend) {
                setLabelDialog.reportSaveError(qsTr("Wallet backend unavailable."))
                return
            }
            logos.watch(backend.addLabel(label, accountId, isPublic),
                function(errorMessage) {
                    // The dialog may have been reopened for a different account while
                    // this round-trip was in flight — only apply the result if it's
                    // still about the same account, otherwise it's stale.
                    if (setLabelDialog.accountId !== accountId || setLabelDialog.isPublic !== isPublic)
                        return
                    if (errorMessage)
                        setLabelDialog.reportSaveError(ffiErrors.format(errorMessage))
                    else
                        setLabelDialog.closeOnSaveSuccess()
                },
                function(error) {
                    if (setLabelDialog.accountId !== accountId || setLabelDialog.isPublic !== isPublic)
                        return
                    setLabelDialog.reportSaveError(error)
                })
        }
    }

    LogosToast {
        id: bottomNotice
        objectName: "lezNotice"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacing.large
        z: 10
        severity: d.noticeSeverity
        message: d.noticeMessage
        duration: 8000
        onDismissed: d.noticeMessage = ""
    }

    StackView {
        id: stackView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Component {
            id: loadingView
            LoadingView {}
        }

        Component {
            id: onboardingView
            OnboardingView {
                id: onboarding

                testnetUrl: backend ? backend.testnetUrl : ""
                localhostUrl: backend ? backend.localhostUrl : ""
                // A saved wallet: the home screen asks for its password; "I already have a
                // wallet" starts from its paths.
                savedWallet: d.needsPassword
                savedConfigPath: backend ? backend.configPath : ""
                savedStoragePath: backend ? backend.storagePath : ""

                onUnlockWallet: function(password) {
                    if (!backend) return
                    onboarding.unlockBusy = true
                    // "" on success, the reason otherwise; a wrong password stays on the home screen.
                    logos.watch(backend.unlockSaved(password),
                        function(errorMessage) {
                            onboarding.unlockBusy = false
                            if (errorMessage) onboarding.unlockFailed(errorMessage)
                            else d.updateStack(d.isWalletOpen)
                        },
                        function(error) {
                            onboarding.unlockBusy = false
                            onboarding.unlockFailed(qsTr("Error opening wallet: %1").arg(error))
                        }
                    )
                }
                onDefaultPathsWanted: {
                    if (!backend) return
                    logos.watch(backend.defaultWalletFiles(),
                        function(files) {
                            if (files && files.length === 2) onboarding.offerDefaultPaths(files[0], files[1])
                        },
                        function(error) {})
                }

                onCreateWallet: function(password, sequencerUrl) {
                    if (!backend) return
                    onboarding.createError = ""
                    onboarding.busyMessage = qsTr("Creating your wallet…")
                    onboarding.busy = true
                    logos.watch(backend.createNew(password, sequencerUrl),
                        function(raw) {
                            onboarding.busy = false
                            var result = {}
                            try {
                                result = JSON.parse(raw)
                            } catch (e) {
                                onboarding.createError = qsTr("Unexpected response while creating wallet.")
                                d.updateStack(d.isWalletOpen)
                                return
                            }
                            if (!result.success) {
                                onboarding.createError = result.error || qsTr("Failed to create wallet.")
                                d.updateStack(d.isWalletOpen)
                                return
                            }
                            onboarding.showRecoveryPhrase(result.mnemonic || "")
                        },
                        function(error) {
                            onboarding.busy = false
                            onboarding.createError = qsTr("Error creating wallet: %1").arg(error)
                            d.updateStack(d.isWalletOpen)
                        }
                    )
                }

                onOpenWallet: function(configPath, storagePath, password) {
                    if (!backend) return
                    onboarding.openError = ""
                    onboarding.busyMessage = qsTr("Opening your wallet…")
                    onboarding.busy = true
                    // Empty string on success, human-readable message otherwise.
                    logos.watch(backend.openExisting(configPath, storagePath, password),
                        function(errorMessage) {
                            onboarding.busy = false
                            if (errorMessage)
                                onboarding.openError = errorMessage
                            else
                                d.updateStack(d.isWalletOpen)
                        },
                        function(error) {
                            onboarding.busy = false
                            onboarding.openError = qsTr("Error opening wallet: %1").arg(error)
                        }
                    )
                }

                onMnemonicAcknowledged: d.updateStack(d.isWalletOpen)
            }
        }

        Component {
            id: mainView
            DashboardView {
                id: dashboardView
                accountModel: root.accountModel
                publicAccountModel: root.publicAccountModel
                privateAccountModel: root.privateAccountModel
                lastSyncedBlock: backend ? backend.lastSyncedBlock : 0
                currentBlockHeight: backend ? backend.currentBlockHeight : 0

                onCreatePublicAccountRequested: {
                    if (!backend) { console.warn("backend is null"); return }
                    // accountModel updates via NOTIFY when the backend's refreshAccounts()
                    // runs after creation.
                    logos.watch(backend.createAccountPublic(),
                        null,
                        function(error) { console.warn("createAccountPublic failed:", error) })
                }
                onCreatePrivateAccountRequested: {
                    if (!backend) { console.warn("backend is null"); return }
                    logos.watch(backend.createAccountPrivate(),
                        null,
                        function(error) { console.warn("createAccountPrivate failed:", error) })
                }
                onFetchBalancesRequested: {
                    if (!backend) { console.warn("backend is null"); return }
                    backend.refreshBalances()  // void slot, fire-and-forget
                }
                onTransferPublicRequested: (fromId, toAddress, amount) =>
                    sendFlow.begin(dashboardView, "transferPublic", [fromId, toAddress, amount], false)
                onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) =>
                    sendFlow.begin(dashboardView, "transferPrivate", [fromId, toKeysJsonOrAddress, amount], true)
                onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) =>
                    sendFlow.begin(dashboardView, "transferPrivateOwned", [fromId, toAccountId, amount], true)
                onTransferShieldedRequested: (fromId, toKeysJsonOrAddress, amount) =>
                    sendFlow.begin(dashboardView, "transferShielded", [fromId, toKeysJsonOrAddress, amount], true)
                onTransferShieldedOwnedRequested: (fromId, toAccountId, amount) =>
                    sendFlow.begin(dashboardView, "transferShieldedOwned", [fromId, toAccountId, amount], true)
                onTransferDeshieldedRequested: (fromId, toAccountId, amount) =>
                    sendFlow.begin(dashboardView, "transferDeshielded", [fromId, toAccountId, amount], true)
                onBridgeWithdrawRequested: (fromId, bedrockAccountPkHex, amount) =>
                    sendFlow.begin(dashboardView, "bridgeWithdraw", [fromId, bedrockAccountPkHex, amount], false)
                onLabelRequested: (accountId, isPublic) => {
                    setLabelDialog.accountId = accountId
                    setLabelDialog.isPublic = isPublic
                    setLabelDialog.open()
                }
            }
        }
    }
}
