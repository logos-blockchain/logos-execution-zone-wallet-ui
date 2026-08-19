import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Logos.Theme
import Logos.Controls

import "../controls"

Control {
    id: root

    property string testnetUrl: ""
    property string localhostUrl: ""
    property string createError: ""
    property string openError: ""
    property bool busy: false
    property string busyMessage: ""

    signal createWallet(string password, string sequencerUrl)
    signal openWallet(string configPath, string storagePath)
    signal mnemonicAcknowledged()

    // Called by ExecutionZoneWalletView once createNew() comes back with a phrase.
    function showRecoveryPhrase(mnemonic) {
        stack.push(recoveryPhrasePage, { mnemonic: mnemonic })
    }

    onBusyChanged: {
        if (busy)
            stack.push(busyPage)
        else
            stack.pop()
    }

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: createWalletPage
    }

    Component {
        id: busyPage
        LoadingView {
            message: root.busyMessage
        }
    }

    Component {
        id: createWalletPage
        CreateWalletPage {
            testnetUrl: root.testnetUrl
            localhostUrl: root.localhostUrl
            createError: root.createError
            onCreateWallet: (password, sequencerUrl) => root.createWallet(password, sequencerUrl)
            onErrorRaised: (message) => root.createError = message
            onOpenExistingRequested: {
                root.openError = ""
                stack.push(openWalletPage)
            }
        }
    }

    Component {
        id: openWalletPage
        OpenWalletPage {
            openError: root.openError
            onOpenWallet: (configPath, storagePath) => root.openWallet(configPath, storagePath)
            onErrorRaised: (message) => root.openError = message
            onBack: {
                root.openError = ""
                stack.pop()
            }
        }
    }

    Component {
        id: recoveryPhrasePage
        RecoveryPhrasePage {
            onAcknowledged: root.mnemonicAcknowledged()
        }
    }
}
