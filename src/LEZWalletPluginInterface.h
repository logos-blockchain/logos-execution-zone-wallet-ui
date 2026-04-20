#ifndef LEZ_WALLET_PLUGIN_INTERFACE_H
#define LEZ_WALLET_PLUGIN_INTERFACE_H

#include <QtPlugin>          // for Q_DECLARE_INTERFACE
#include "interface.h"

// Marker interface used by Qt's plugin loader to identify the LEZ wallet UI
// plugin. The actual API surface (Q_INVOKABLE methods, properties, signals)
// lives in LEZWalletBackend.rep — this header only carries the IID.
class LEZWalletPluginInterface : public PluginInterface
{
public:
    virtual ~LEZWalletPluginInterface() = default;
};

#define LEZWalletPluginInterface_iid "org.logos.LEZWalletPluginInterface"
Q_DECLARE_INTERFACE(LEZWalletPluginInterface, LEZWalletPluginInterface_iid)

#endif // LEZ_WALLET_PLUGIN_INTERFACE_H
