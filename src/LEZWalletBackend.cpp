#include "LEZWalletBackend.h"
#include <QAbstractItemModel>
#include <QClipboard>
#include <QDebug>
#include <QGuiApplication>
#include <QJsonArray>
#include <QSettings>
#include <QUrl>

namespace {
    const char SETTINGS_ORG[] = "Logos";
    const char SETTINGS_APP[] = "ExecutionZoneWalletUI";
    const char CONFIG_PATH_KEY[] = "configPath";
    const char STORAGE_PATH_KEY[] = "storagePath";
    const QString WALLET_MODULE_NAME = QStringLiteral("liblogos_execution_zone_wallet_module");
    const int WALLET_FFI_SUCCESS = 0;

    // Convert decimal amount string to 32-char hex (16 bytes little-endian) for transfer_public/transfer_private.
    QString amountToLe16Hex(const QString& amountStr) {
        const QString trimmed = amountStr.trimmed();
        if (trimmed.isEmpty()) return QString();
        bool parseOk = false;
        const quint64 value = trimmed.toULongLong(&parseOk);
        if (!parseOk) return QString();
        uint8_t bytes[16] = {0};
        for (int i = 0; i < 8; ++i)
            bytes[i] = static_cast<uint8_t>((value >> (i * 8)) & 0xff);
        return QByteArray(reinterpret_cast<const char*>(bytes), 16).toHex();
    }
}

LEZWalletBackend::LEZWalletBackend(LogosAPI* logosAPI, QObject* parent)
    : QObject(parent),
      m_isWalletOpen(false),
      m_lastSyncedBlock(0),
      m_currentBlockHeight(0),
      m_accountModel(new LEZWalletAccountModel(this)),
      m_filteredAccountModel(new LEZAccountFilterModel(this)),
      m_logosAPI(nullptr),
      m_walletClient(nullptr)
{
    m_filteredAccountModel->setSourceModel(m_accountModel);

    QSettings s(SETTINGS_ORG, SETTINGS_APP);
    m_configPath = s.value(CONFIG_PATH_KEY).toString();
    m_storagePath = s.value(STORAGE_PATH_KEY).toString();

    if (!logosAPI) {
        logosAPI = new LogosAPI("logos_execution_zone_wallet_ui", this);
    }
    m_logosAPI = logosAPI;
    m_walletClient = m_logosAPI->getClient(WALLET_MODULE_NAME);

    if (!m_walletClient) {
        qWarning() << "LEZWalletBackend: could not get client for" << WALLET_MODULE_NAME;
        return;
    }

    if (!m_configPath.isEmpty() && !m_storagePath.isEmpty()) {
        qDebug() << "LEZWalletBackend: opening wallet with config path" << m_configPath << "and storage path" << m_storagePath;
        QVariant result = m_walletClient->invokeRemoteMethod(
            WALLET_MODULE_NAME, "open", m_configPath, m_storagePath);
        int err = result.isValid() ? result.toInt() : -1;
        if (err == WALLET_FFI_SUCCESS) {
            qWarning() << "LEZWalletBackend: wallet opened successfully";
            setWalletOpen(true);
            refreshAccounts();
            refreshBlockHeights();
            refreshSequencerAddr();
        }
    }

    // Save wallet when app quits; host may not call destroyWidget() so destructor might not run.
    connect(qApp, &QCoreApplication::aboutToQuit, this, [this]() { saveWallet(); }, Qt::DirectConnection);
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
    m_accountModel->replaceFromJsonArray(arr);
    emit accountModelChanged();
    refreshBalances();
}

void LEZWalletBackend::refreshBalances()
{
    if (!m_walletClient || !m_accountModel) return;
    for (int i = 0; i < m_accountModel->count(); ++i) {
        const QModelIndex idx = m_accountModel->index(i, 0);
        const QString addr = m_accountModel->data(idx, LEZWalletAccountModel::AddressRole).toString();
        const bool isPub = m_accountModel->data(idx, LEZWalletAccountModel::IsPublicRole).toBool();
        m_accountModel->setBalanceByAddress(addr, getBalance(addr, isPub));
    }
}

void LEZWalletBackend::fetchAndUpdateBlockHeights()
{
    if (!m_walletClient) return;
    const quint64 lastVal = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_last_synced_block").toULongLong();
    const quint64 currentVal = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_current_block_height").toULongLong();
    if (m_lastSyncedBlock != lastVal) {
        m_lastSyncedBlock = lastVal;
        emit lastSyncedBlockChanged();
    }
    if (m_currentBlockHeight != currentVal) {
        m_currentBlockHeight = currentVal;
        emit currentBlockHeightChanged();
    }
}

void LEZWalletBackend::refreshBlockHeights()
{
    fetchAndUpdateBlockHeights();
    if (m_currentBlockHeight > 0 && m_lastSyncedBlock < m_currentBlockHeight && syncToBlock(m_currentBlockHeight))
        fetchAndUpdateBlockHeights();
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
    return err == WALLET_FFI_SUCCESS;
}

QString LEZWalletBackend::transferPublic(
    const QString& fromHex,
    const QString& toHex,
    const QString& amountLe16Hex)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    const QString amountHex = amountToLe16Hex(amountLe16Hex);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_public", fromHex, toHex, amountHex);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

QString LEZWalletBackend::transferPrivate(
    const QString& fromHex,
    const QString& toHex,
    const QString& amountLe16Hex)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    const QString amountHex = amountToLe16Hex(amountLe16Hex);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");

    QString keysPayload = toHex.trimmed();
    // If "To" is not JSON (e.g. user pasted account id hex), resolve to keys via get_private_account_keys.
    if (!keysPayload.startsWith(QLatin1Char('{'))) {
        qDebug() << "LEZWalletBackend::transferPrivate: keysPayload is not JSON, resolving to keys via get_private_account_keys";
        const QString resolved = getPrivateAccountKeys(keysPayload);
        if (!resolved.isEmpty())
            keysPayload = resolved;
    }

    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_private", fromHex, keysPayload, amountHex);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

bool LEZWalletBackend::createNew(
    const QString& configPath,
    const QString& storagePath,
    const QString& password)
{
    const QString localPath = QUrl::fromUserInput(configPath).toLocalFile();
    if (!m_walletClient) return false;
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "create_new", localPath, storagePath, password);
    int err = result.isValid() ? result.toInt() : -1;
    if (err != WALLET_FFI_SUCCESS) return false;

    setConfigPath(localPath);
    setStoragePath(storagePath);
    setWalletOpen(true);
    refreshAccounts();
    refreshBlockHeights();
    refreshSequencerAddr();
    return true;
}

int LEZWalletBackend::indexOfAddressInModel(QObject* model, const QString& address) const
{
    auto* m = qobject_cast<QAbstractItemModel*>(model);
    if (!m || address.isEmpty())
        return -1;
    const int role = m->roleNames().key("address", -1);
    if (role < 0)
        return -1;
    for (int i = 0; i < m->rowCount(); ++i) {
        if (m->data(m->index(i, 0), role).toString() == address)
            return i;
    }
    return -1;
}

void LEZWalletBackend::copyToClipboard(const QString& text)
{
    if (QGuiApplication::clipboard())
        QGuiApplication::clipboard()->setText(text);
}
