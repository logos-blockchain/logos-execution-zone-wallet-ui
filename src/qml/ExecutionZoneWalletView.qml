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
    readonly property var claimableAccountModel: logos.model("lez_wallet_ui", "claimableAccountModel")
    property bool ready: false
    // Maps accountId -> true while that account's initializeAccount() call is in flight,
    // so AccountDelegate can show the click was registered instead of appearing inert.
    property var pendingInitializations: ({})

    Connections {
        target: logos
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName === "lez_wallet_ui")
                root.ready = isReady && root.backend !== null
        }
    }

    // Map wallet FFI error codes to user-facing strings. Matches lssa/wallet-ffi WalletFfiError enum.
    QtObject {
        id: ffiErrors
        readonly property var codeToMessage: ({
            0: qsTr("Success"),
            1: qsTr("Invalid argument (null pointer)"),
            2: qsTr("Invalid UTF-8 string"),
            3: qsTr("Wallet not initialized"),
            4: qsTr("Configuration error"),
            5: qsTr("Storage or persistence error"),
            6: qsTr("Network or RPC error"),
            7: qsTr("Account not found"),
            8: qsTr("Key not found for account"),
            9: qsTr("Insufficient funds"),
            10: qsTr("Invalid account ID format"),
            11: qsTr("Runtime error"),
            12: qsTr("Password required but not provided"),
            13: qsTr("Block synchronization error"),
            14: qsTr("Serialization error"),
            15: qsTr("Invalid type conversion"),
            16: qsTr("Invalid key value"),
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

    onReadyChanged: if (ready) d.updateStack(d.isWalletOpen)

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
        anchors.bottomMargin: bottomNotice.shown
            ? bottomNotice.height + Theme.spacing.large * 2
            : 0

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

                onOpenWallet: function(configPath, storagePath) {
                    if (!backend) return
                    onboarding.openError = ""
                    onboarding.busyMessage = qsTr("Opening your wallet…")
                    onboarding.busy = true
                    // Empty string on success, human-readable message otherwise.
                    logos.watch(backend.openExisting(configPath, storagePath),
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
                claimableAccountModel: root.claimableAccountModel
                lastSyncedBlock: backend ? backend.lastSyncedBlock : 0
                currentBlockHeight: backend ? backend.currentBlockHeight : 0
                pendingInitializations: root.pendingInitializations

                onCreatePublicAccountRequested: (initializeOnCreate) => {
                    if (!backend) { console.warn("backend is null"); return }
                    // accountModel updates via NOTIFY when the backend's refreshAccounts()
                    // runs after creation; the id is only needed to chase it with an
                    // initializeAccount() call when the user asked for that.
                    logos.watch(backend.createAccountPublic(),
                        function(id) {
                            if (initializeOnCreate && id)
                                dashboardView.initializeAccount(id)
                        },
                        function(error) { console.warn("createAccountPublic failed:", error) })
                }
                onCreatePrivateAccountRequested: {
                    if (!backend) { console.warn("backend is null"); return }
                    logos.watch(backend.createAccountPrivate(),
                        function(_id) { /* ignored */ },
                        function(error) { console.warn("createAccountPrivate failed:", error) })
                }
                onFetchBalancesRequested: {
                    if (!backend) { console.warn("backend is null"); return }
                    backend.refreshBalances()  // void slot, fire-and-forget
                }
                onTransferPublicRequested: (fromId, toAddress, amount) => {
                    if (!backend) return
                    logos.watch(backend.transferPublic(fromId, toAddress, amount),
                        function(raw) { ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) => {
                    if (!backend) return
                    dashboardView.transferPending = true
                    logos.watch(backend.transferPrivate(fromId, toKeysJsonOrAddress, amount),
                        function(raw) { dashboardView.transferPending = false; ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferPending = false
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) => {
                    if (!backend) return
                    dashboardView.transferPending = true
                    logos.watch(backend.transferPrivateOwned(fromId, toAccountId, amount),
                        function(raw) { dashboardView.transferPending = false; ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferPending = false
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onTransferShieldedRequested: (fromId, toKeysJsonOrAddress, amount) => {
                    if (!backend) return
                    dashboardView.transferPending = true
                    logos.watch(backend.transferShielded(fromId, toKeysJsonOrAddress, amount),
                        function(raw) { dashboardView.transferPending = false; ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferPending = false
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onTransferShieldedOwnedRequested: (fromId, toAccountId, amount) => {
                    if (!backend) return
                    dashboardView.transferPending = true
                    logos.watch(backend.transferShieldedOwned(fromId, toAccountId, amount),
                        function(raw) { dashboardView.transferPending = false; ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferPending = false
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onTransferDeshieldedRequested: (fromId, toAccountId, amount) => {
                    if (!backend) return
                    dashboardView.transferPending = true
                    logos.watch(backend.transferDeshielded(fromId, toAccountId, amount),
                        function(raw) { dashboardView.transferPending = false; ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferPending = false
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onBridgeWithdrawRequested: (fromId, bedrockAccountPkHex, amount) => {
                    if (!backend) return
                    var parsedAmount = Number(amount)
                    if (!Number.isInteger(parsedAmount) || parsedAmount <= 0) {
                        dashboardView.transferResult = qsTr("Error: Invalid amount.")
                        dashboardView.transferResultIsError = true
                        dashboardView.transferTxHash = ""
                        return
                    }
                    logos.watch(backend.bridgeWithdraw(fromId, bedrockAccountPkHex, parsedAmount),
                        function(raw) { ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onVaultClaimRequested: (fromId, isPublic, amount) => {
                    if (!backend) return
                    dashboardView.transferPending = !isPublic
                    logos.watch(backend.vaultClaim(fromId, isPublic, amount),
                        function(raw) {
                            dashboardView.transferPending = false
                            ffiErrors.applyTransferResult(dashboardView, raw)
                            backend.refreshVaultBalances()
                            backend.refreshBalances()
                        },
                        function(error) {
                            dashboardView.transferPending = false
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
                onRefreshClaimableDepositsRequested: {
                    if (!backend) return
                    backend.refreshVaultBalances()  // void slot, fire-and-forget
                }
                onInitializeAccountRequested: (accountId) => dashboardView.initializeAccount(accountId)
                onLabelRequested: (accountId, isPublic) => {
                    setLabelDialog.accountId = accountId
                    setLabelDialog.isPublic = isPublic
                    setLabelDialog.open()
                }

                // Shared by the manual Initialize button (onInitializeAccountRequested)
                // and initialize-on-create (onCreatePublicAccountRequested above). Public
                // accounts only: initialization requires authorization, so it's always a
                // manual init signed by the owner. Private accounts don't need this.
                function initializeAccount(accountId) {
                    if (!backend) return
                    // Reassign (not mutate) so the pendingInitializations binding
                    // propagated down to each AccountDelegate re-evaluates.
                    var pending = Object.assign({}, root.pendingInitializations)
                    pending[accountId] = true
                    root.pendingInitializations = pending
                    function clearPending() {
                        var updated = Object.assign({}, root.pendingInitializations)
                        delete updated[accountId]
                        root.pendingInitializations = updated
                    }
                    // Same {success, tx_hash, error} shape as the transfer/vaultClaim
                    // slots below, so it gets the same result-panel feedback. The
                    // accountModel's tag updates via NOTIFY once the backend
                    // refreshes accounts after a successful initialization.
                    logos.watch(backend.initializeAccount(accountId),
                        function(raw) {
                            clearPending()
                            ffiErrors.applyTransferResult(dashboardView, raw)
                        },
                        function(error) {
                            clearPending()
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                            dashboardView.transferTxHash = ""
                        })
                }
            }
        }
    }
}
