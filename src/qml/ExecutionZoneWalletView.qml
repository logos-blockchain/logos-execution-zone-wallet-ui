import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import LEZWalletBackend
import Logos.Theme
import Logos.Controls
import "views"

Rectangle {
    id: root

    color: Theme.palette.background

    StackView {
        anchors.fill: parent
        initialItem: backend && backend.isWalletOpen ? mainView: onboardingView

        Component {
            id: onboardingView
            OnboardingView {
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
                filteredAccountModel: backend ? backend.filteredAccountModel : null

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
                onTransferRequested: function(isPublic, fromId, toAddress, amount) {
                    if (!backend) {
                        console.warning("backend is null")
                        return
                    }
                    dashboardView.transferResult = isPublic
                            ? backend.transferPublic(fromId, toAddress, amount)
                            : backend.transferPrivate(fromId, toAddress, amount)
                }
            }
        }
    }
}
