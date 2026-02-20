import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

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


        // Page 1: Main screen placeholder (AccountsView / SendView added later)
        Component {
            id: mainView
            Rectangle {
                anchors.fill: parent
                color: Theme.palette.background
                LogosText {
                    anchors.centerIn: parent
                    text: qsTr("Wallet")
                    font.pixelSize: Theme.typography.secondaryText
                    font.bold: true
                }
            }
        }
    }
}
