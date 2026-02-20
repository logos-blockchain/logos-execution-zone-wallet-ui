import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import LEZWalletBackend
import Logos.Theme
import Logos.Controls

Rectangle {
    id: root

    color: Theme.palette.background

    SwipeView {
        id: swipeView
        anchors.fill: parent
        interactive: false
        currentIndex: backend && backend.isWalletOpen ? 1 : 0

        // Page 0: Onboarding placeholder (full OnboardingView added later)
        Item {
            Rectangle {
                anchors.fill: parent
                color: Theme.palette.background
                LogosText {
                    anchors.centerIn: parent
                    text: qsTr("Wallet Setup")
                    font.pixelSize: Theme.typography.secondaryText
                    font.bold: true
                }
            }
        }

        // Page 1: Main screen placeholder (AccountsView / SendView added later)
        Item {
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
