import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls
import "views"

Rectangle {
    id: root

    readonly property var backend: logos.module("lez_wallet_ui")
    readonly property var accountModel: logos.model("lez_wallet_ui", "accountModel")
    property bool ready: false

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
        // Used by all three transfer handlers below.
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
        }
    }

    QtObject {
        id: d
        readonly property bool isWalletOpen: backend && backend.isWalletOpen
        onIsWalletOpenChanged: if (root.ready) updateStack(isWalletOpen)

        function updateStack(walletOpen) {
            stackView.replace(walletOpen ? mainView : onboardingView)
        }
    }

    onReadyChanged: if (ready) d.updateStack(d.isWalletOpen)

    Component.onCompleted: {
        root.ready = root.backend !== null
            && logos.isViewModuleReady("lez_wallet_ui")
        if (root.ready) d.updateStack(d.isWalletOpen)
    }

    color: Theme.palette.background

    // Used as a clipboard helper — TextEdit.copy() works in the GUI process.
    TextEdit {
        id: clipHelper
        visible: false
    }

    StackView {
        id: stackView
        anchors.fill: parent

        Component {
            id: onboardingView
            OnboardingView {
                storePath: backend ? backend.storagePath : ""
                configPath: backend ? backend.configPath : ""
                onCreateWallet: function(configPath, storagePath, password) {
                    if (!backend) return
                    logos.watch(backend.createNew(configPath, storagePath, password),
                        function(ok) {
                            if (!ok)
                                createError = qsTr("Failed to create wallet. Check paths and try again.")
                        },
                        function(error) {
                            createError = qsTr("Error creating wallet: %1").arg(error)
                        }
                    )
                }
            }
        }

        Component {
            id: mainView
            DashboardView {
                id: dashboardView
                accountModel: root.accountModel

                onCreatePublicAccountRequested: {
                    if (!backend) { console.warn("backend is null"); return }
                    // Result not consumed here — accountModel updates via NOTIFY when
                    // the backend's refreshAccounts() runs after creation.
                    logos.watch(backend.createAccountPublic(),
                        function(_id) { /* ignored */ },
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
                        })
                }
                onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) => {
                    if (!backend) return
                    logos.watch(backend.transferPrivate(fromId, toKeysJsonOrAddress, amount),
                        function(raw) { ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                        })
                }
                onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) => {
                    if (!backend) return
                    logos.watch(backend.transferPrivateOwned(fromId, toAccountId, amount),
                        function(raw) { ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                        })
                }
                onTransferShieldedRequested: (fromId, toKeysJsonOrAddress, amount) => {
                    if (!backend) return
                    logos.watch(backend.transferShielded(fromId, toKeysJsonOrAddress, amount),
                        function(raw) { ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                        })
                }
                onTransferShieldedOwnedRequested: (fromId, toAccountId, amount) => {
                    if (!backend) return
                    logos.watch(backend.transferShieldedOwned(fromId, toAccountId, amount),
                        function(raw) { ffiErrors.applyTransferResult(dashboardView, raw) },
                        function(error) {
                            dashboardView.transferResult = qsTr("Error: %1").arg(error)
                            dashboardView.transferResultIsError = true
                        })
                }
                onCopyRequested: (copyText) => {
                    clipHelper.text = copyText
                    clipHelper.selectAll()
                    clipHelper.copy()
                }
            }
        }
    }
}
