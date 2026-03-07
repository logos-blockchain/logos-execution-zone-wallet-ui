import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import LEZWalletBackend
import Logos.Theme
import Logos.Controls
import "views"

Rectangle {
    id: root

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
    }

    QtObject {
        id: d
        readonly property bool isWalletOpen: backend && backend.isWalletOpen
        onIsWalletOpenChanged: updateStack(isWalletOpen)

        function updateStack(walletOpen) {
            if(walletOpen) {
                stackView.push(mainView)
            } else {
                stackView.push(onboardingView)
            }
        }
    }

    Component.onCompleted: d.updateStack(backend && backend.isWalletOpen)

    color: Theme.palette.background

    StackView {
        id: stackView
        anchors.fill: parent

        Component {
            id: onboardingView
            OnboardingView {
                storePath: backend.storagePath
                configPath: backend.configPath
                onCreateWallet: function(configPath, storagePath, password) {
                    if (!backend || !backend.createNew(configPath, storagePath, password))
                        createError = qsTr("Failed to create wallet. Check paths and try again.")
                }
            }
        }

        Component {
            id: mainView
            DashboardView {
                id: dashboardView
                accountModel: backend ? backend.accountModel : null

                onCreatePublicAccountRequested: {
                    if (!backend) {
                        console.warning("backend is null")
                        return
                    }
                    backend.createAccountPublic()
                }
                onCreatePrivateAccountRequested: {
                    if (!backend) {
                        console.warning("backend is null")
                        return
                    }
                    backend.createAccountPrivate()
                }
                onFetchBalancesRequested: {
                    if (!backend) {
                        console.warning("backend is null")
                        return
                    }
                    backend.refreshBalances()
                }
                onTransferPublicRequested: (fromId, toAddress, amount) => {
                    if (!backend) return
                    var raw = backend.transferPublic(fromId, toAddress, amount)
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
                onTransferPrivateRequested: (fromId, toKeysJsonOrAddress, amount) => {
                    if (!backend) return
                    var raw = backend.transferPrivate(fromId, toKeysJsonOrAddress, amount)
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
                onTransferPrivateOwnedRequested: (fromId, toAccountId, amount) => {
                    if (!backend) return
                    var raw = backend.transferPrivateOwned(fromId, toAccountId, amount)
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
                onCopyRequested: (copyText) => backend.copyToClipboard(copyText)
            }
        }
    }
}
