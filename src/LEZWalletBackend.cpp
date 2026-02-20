#include "LEZWalletBackend.h"
#include <QDebug>
#include <QSettings>
#include <QUrl>

namespace {
    const char SETTINGS_ORG[] = "Logos";
    const char SETTINGS_APP[] = "ExecutionZoneWalletUI";
    const char CONFIG_PATH_KEY[] = "configPath";
    const char STORAGE_PATH_KEY[] = "storagePath";
    const QString WALLET_MODULE_NAME = QStringLiteral("liblogos_execution_zone_wallet_module");
    const int WALLET_FFI_SUCCESS = 0;
}

LEZWalletBackend::LEZWalletBackend(LogosAPI* logosAPI, QObject* parent)
    : QObject(parent),
      m_isWalletOpen(false),
      m_lastSyncedBlock(0),
      m_currentBlockHeight(0),
      m_logosAPI(nullptr),
      m_walletClient(nullptr)
{
    QSettings s(SETTINGS_ORG, SETTINGS_APP);
    m_configPath = s.value(CONFIG_PATH_KEY).toString();
    m_storagePath = s.value(STORAGE_PATH_KEY).toString();

    if (!logosAPI) {
        logosAPI = new LogosAPI("execution_zone_wallet_ui", this);
    }
    m_logosAPI = logosAPI;
    m_walletClient = m_logosAPI->getClient(WALLET_MODULE_NAME);

    if (!m_walletClient) {
        qWarning() << "LEZWalletBackend: could not get client for" << WALLET_MODULE_NAME;
        return;
    }

    if (!m_configPath.isEmpty() && !m_storagePath.isEmpty()) {
        QVariant result = m_walletClient->invokeRemoteMethod(
            WALLET_MODULE_NAME, "open", m_configPath, m_storagePath);
        int err = result.isValid() ? result.toInt() : -1;
        if (err == WALLET_FFI_SUCCESS) {
            setWalletOpen(true);
            refreshAccounts();
            refreshBlockHeights();
            refreshSequencerAddr();
        }
    }
}

LEZWalletBackend::~LEZWalletBackend()
{
    saveWallet();
}

void LEZWalletBackend::saveWallet()
{
    if (m_walletClient && m_isWalletOpen) {
        m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "save");
    }
}

void LEZWalletBackend::setWalletOpen(bool open)
{
    if (m_isWalletOpen != open) {
        m_isWalletOpen = open;
        emit isWalletOpenChanged();
    }
}

void LEZWalletBackend::setConfigPath(const QString& path)
{
    QString localPath = path;
    if (path.startsWith("file://") || path.contains("/")) {
        localPath = QUrl::fromUserInput(path).toLocalFile();
    }
    if (m_configPath != localPath) {
        m_configPath = localPath;
        QSettings s(SETTINGS_ORG, SETTINGS_APP);
        s.setValue(CONFIG_PATH_KEY, m_configPath);
        emit configPathChanged();
    }
}

void LEZWalletBackend::setStoragePath(const QString& path)
{
    QString localPath = path;
    if (path.startsWith("file://") || path.contains("/")) {
        localPath = QUrl::fromUserInput(path).toLocalFile();
    }
    if (m_storagePath != localPath) {
        m_storagePath = localPath;
        QSettings s(SETTINGS_ORG, SETTINGS_APP);
        s.setValue(STORAGE_PATH_KEY, m_storagePath);
        emit storagePathChanged();
    }
}

void LEZWalletBackend::refreshAccounts()
{
    if (!m_walletClient) return;
    QVariant result = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "list_accounts");
    QJsonArray arr;
    if (result.isValid() && result.canConvert<QJsonArray>()) {
        arr = result.toJsonArray();
    }
    if (m_accounts != arr) {
        m_accounts = std::move(arr);
        emit accountsChanged();
    }
}

void LEZWalletBackend::refreshBlockHeights()
{
    if (!m_walletClient) return;
    QVariant last = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_last_synced_block");
    QVariant current = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_current_block_height");
    quint64 lastVal = last.isValid() ? last.toULongLong() : 0;
    quint64 currentVal = current.isValid() ? current.toULongLong() : 0;
    if (m_lastSyncedBlock != lastVal) {
        m_lastSyncedBlock = lastVal;
        emit lastSyncedBlockChanged();
    }
    if (m_currentBlockHeight != currentVal) {
        m_currentBlockHeight = currentVal;
        emit currentBlockHeightChanged();
    }
}

void LEZWalletBackend::refreshSequencerAddr()
{
    if (!m_walletClient) return;
    QVariant result = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_sequencer_addr");
    QString addr = result.isValid() ? result.toString() : QString();
    if (m_sequencerAddr != addr) {
        m_sequencerAddr = std::move(addr);
        emit sequencerAddrChanged();
    }
}

QString LEZWalletBackend::createAccountPublic()
{
    if (!m_walletClient) return QString();
    QVariant result = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "create_account_public");
    if (result.isValid()) {
        refreshAccounts();
        return result.toString();
    }
    return QString();
}

QString LEZWalletBackend::createAccountPrivate()
{
    if (!m_walletClient) return QString();
    QVariant result = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "create_account_private");
    if (result.isValid()) {
        refreshAccounts();
        return result.toString();
    }
    return QString();
}

QString LEZWalletBackend::getBalance(const QString& accountIdHex, bool isPublic)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "get_balance", accountIdHex, isPublic);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

QString LEZWalletBackend::getPublicAccountKey(const QString& accountIdHex)
{
    if (!m_walletClient) return QString();
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "get_public_account_key", accountIdHex);
    return result.isValid() ? result.toString() : QString();
}

QString LEZWalletBackend::getPrivateAccountKeys(const QString& accountIdHex)
{
    if (!m_walletClient) return QString();
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "get_private_account_keys", accountIdHex);
    return result.isValid() ? result.toString() : QString();
}

bool LEZWalletBackend::syncToBlock(quint64 blockId)
{
    if (!m_walletClient) return false;
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "sync_to_block", blockId);
    int err = result.isValid() ? result.toInt() : -1;
    if (err == WALLET_FFI_SUCCESS) {
        refreshBlockHeights();
        return true;
    }
    return false;
}

QString LEZWalletBackend::transferPublic(
    const QString& fromHex,
    const QString& toHex,
    const QString& amountLe16Hex)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_public", fromHex, toHex, amountLe16Hex);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

QString LEZWalletBackend::transferPrivate(
    const QString& fromHex,
    const QString& toKeysJson,
    const QString& amountLe16Hex)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_private", fromHex, toKeysJson, amountLe16Hex);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

bool LEZWalletBackend::createNew(
    const QString& configPath,
    const QString& storagePath,
    const QString& password)
{
    if (!m_walletClient) return false;
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "create_new", configPath, storagePath, password);
    int err = result.isValid() ? result.toInt() : -1;
    if (err != WALLET_FFI_SUCCESS) return false;

    setConfigPath(configPath);
    setStoragePath(storagePath);
    setWalletOpen(true);
    refreshAccounts();
    refreshBlockHeights();
    refreshSequencerAddr();
    return true;
}
