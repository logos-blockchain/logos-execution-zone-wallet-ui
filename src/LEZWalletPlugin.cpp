#include "LEZWalletPlugin.h"
#include "LEZWalletBackend.h"

#include <QDebug>

LEZWalletPlugin::LEZWalletPlugin(QObject* parent)
    : QObject(parent)
{
}

LEZWalletPlugin::~LEZWalletPlugin() = default;

void LEZWalletPlugin::initLogos(LogosAPI* api)
{
    if (m_backend) return;
    m_backend = new LEZWalletBackend(api, this);
    setBackend(m_backend);
    qDebug() << "LEZWalletPlugin: backend initialized";
}
