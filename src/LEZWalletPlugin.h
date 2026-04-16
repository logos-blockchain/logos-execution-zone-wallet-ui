#ifndef LEZ_WALLET_PLUGIN_H
#define LEZ_WALLET_PLUGIN_H

#include <QObject>
#include <QString>
#include <QtPlugin>          // for Q_PLUGIN_METADATA, Q_INTERFACES
#include "LEZWalletPluginInterface.h"
#include "LogosViewPluginBase.h"

class LogosAPI;
class LEZWalletBackend;

// Thin plugin entry point. Holds an LEZWalletBackend and lets the
// generated view-plugin base expose it to ui-host.
class LEZWalletPlugin : public QObject,
                       public LEZWalletPluginInterface,
                       public LEZWalletBackendViewPluginBase
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID LEZWalletPluginInterface_iid FILE "../metadata.json")
    Q_INTERFACES(LEZWalletPluginInterface)

public:
    explicit LEZWalletPlugin(QObject* parent = nullptr);
    ~LEZWalletPlugin() override;

    QString name()    const override { return "logos_execution_zone_wallet_ui"; }
    QString version() const override { return "1.0.0"; }

    // Called by ui-host after plugin load. Creates the backend and wires
    // it up with the provided LogosAPI.
    Q_INVOKABLE void initLogos(LogosAPI* api);

private:
    LEZWalletBackend* m_backend = nullptr;
};

#endif // LEZ_WALLET_PLUGIN_H
