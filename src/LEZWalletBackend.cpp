#include "LEZWalletBackend.h"

#include <QAbstractItemModel>
#include <QClipboard>
#include <QCoreApplication>
#include <QDebug>
#include <QGuiApplication>
#include <QJsonArray>
#include <QSettings>
#include <QTimer>
#include <QUrl>

#include "logos_api.h"
#include "logos_api_client.h"

namespace {
    const char SETTINGS_ORG[] = "Logos";
    const char SETTINGS_APP[] = "ExecutionZoneWalletUI";
    const char CONFIG_PATH_KEY[] = "configPath";
    const char STORAGE_PATH_KEY[] = "storagePath";
    const QString WALLET_MODULE_NAME = QStringLiteral("lez_wallet_module");
    const int WALLET_FFI_SUCCESS = 0;

    // Convert a decimal amount string to 32-char hex (16 bytes little-endian)
    // for transfer_public/transfer_private/transfer_private_owned.
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

    // Normalise file:// URLs and OS paths to a plain local path.
    QString toLocalPath(const QString& path) {
        if (path.startsWith("file://") || path.contains("/"))
            return QUrl::fromUserInput(path).toLocalFile();
        return path;
    }
}

LEZWalletBackend::LEZWalletBackend(LogosAPI* logosAPI, QObject* parent)
    : LEZWalletBackendSimpleSource(parent),
      m_accountModel(new LEZWalletAccountModel(this)),
      m_filteredAccountModel(new LEZAccountFilterModel(this)),
      m_logosAPI(logosAPI ? logosAPI : new LogosAPI("lez_wallet_ui", this)),
      m_walletClient(nullptr)
{
    m_filteredAccountModel->setSourceModel(m_accountModel);

    // Initialise PROP defaults via the generated setters.
    setIsWalletOpen(false);
    setLastSyncedBlock(0);
    setCurrentBlockHeight(0);

    // Load persisted config/storage paths.
    QSettings s(SETTINGS_ORG, SETTINGS_APP);
    setConfigPath(s.value(CONFIG_PATH_KEY).toString());
    setStoragePath(s.value(STORAGE_PATH_KEY).toString());

    m_walletClient = m_logosAPI->getClient(WALLET_MODULE_NAME);
    if (!m_walletClient) {
        qWarning() << "LEZWalletBackend: could not get client for" << WALLET_MODULE_NAME;
        return;
    }

    // ui-host runs our constructor inside initLogos(), synchronously, BEFORE
    // it enables remoting and emits READY. Any blocking RPC here (open,
    // list_accounts, block-height queries, sequencer lookup) would stall
    // ui-host startup past ViewModuleHost's 30s ready watchdog and get the
    // child SIGTERM'd. Defer the whole open+refresh chain to the first
    // event-loop tick so ui-host finishes wiring itself up first.
    QTimer::singleShot(0, this, [this]() { openIfPathsConfigured(); });

    // Save wallet when app quits; host may not call destructors so this is best-effort.
    connect(qApp, &QCoreApplication::aboutToQuit, this,
            [this]() { saveWallet(); }, Qt::DirectConnection);
}

LEZWalletBackend::~LEZWalletBackend()
{
    saveWallet();
}

void LEZWalletBackend::saveWallet()
{
    if (m_walletClient && isWalletOpen()) {
        m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "save");
    }
}

void LEZWalletBackend::persistConfigPath(const QString& path)
{
    const QString localPath = toLocalPath(path);
    setConfigPath(localPath);
    QSettings(SETTINGS_ORG, SETTINGS_APP).setValue(CONFIG_PATH_KEY, localPath);
}

void LEZWalletBackend::persistStoragePath(const QString& path)
{
    const QString localPath = toLocalPath(path);
    setStoragePath(localPath);
    QSettings(SETTINGS_ORG, SETTINGS_APP).setValue(STORAGE_PATH_KEY, localPath);
}

void LEZWalletBackend::openIfPathsConfigured()
{
    if (!m_walletClient) return;
    if (configPath().isEmpty() || storagePath().isEmpty()) return;

    qDebug() << "LEZWalletBackend: opening wallet with config" << configPath()
             << "storage" << storagePath();
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "open", configPath(), storagePath());
    int err = result.isValid() ? result.toInt() : -1;
    if (err == WALLET_FFI_SUCCESS) {
        qDebug() << "LEZWalletBackend: wallet opened successfully";
        setIsWalletOpen(true);
        refreshAccounts();
        refreshBlockHeights();
        refreshSequencerAddr();
    }
}

void LEZWalletBackend::refreshAccounts()
{
    if (!m_walletClient) return;
    QVariant result = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "list_accounts");
    QJsonArray arr;
    if (result.isValid() && result.canConvert<QJsonArray>())
        arr = result.toJsonArray();
    m_accountModel->replaceFromJsonArray(arr);
    refreshBalances();
}

void LEZWalletBackend::refreshBalances()
{
    refreshBlockHeights();
    syncToBlock(currentBlockHeight());
    if (!m_walletClient || !m_accountModel) return;
    for (int i = 0; i < m_accountModel->count(); ++i) {
        const QModelIndex idx = m_accountModel->index(i, 0);
        const QString addr = m_accountModel->data(idx, LEZWalletAccountModel::AddressRole).toString();
        const bool isPub = m_accountModel->data(idx, LEZWalletAccountModel::IsPublicRole).toBool();
        m_accountModel->setBalanceByAddress(addr, getBalance(addr, isPub));
    }
    saveWallet();
}

void LEZWalletBackend::fetchAndUpdateBlockHeights()
{
    if (!m_walletClient) return;
    const int lastVal = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_last_synced_block").toInt();
    const int currentVal = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_current_block_height").toInt();
    if (lastSyncedBlock() != lastVal)
        setLastSyncedBlock(lastVal);
    if (currentBlockHeight() != currentVal)
        setCurrentBlockHeight(currentVal);
}

void LEZWalletBackend::refreshBlockHeights()
{
    fetchAndUpdateBlockHeights();
    if (currentBlockHeight() > 0
        && lastSyncedBlock() < currentBlockHeight()
        && syncToBlock(currentBlockHeight()))
    {
        fetchAndUpdateBlockHeights();
    }
}

void LEZWalletBackend::refreshSequencerAddr()
{
    if (!m_walletClient) return;
    QVariant result = m_walletClient->invokeRemoteMethod(WALLET_MODULE_NAME, "get_sequencer_addr");
    const QString addr = result.isValid() ? result.toString() : QString();
    if (sequencerAddr() != addr)
        setSequencerAddr(addr);
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

QString LEZWalletBackend::getBalance(QString accountIdHex, bool isPublic)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "get_balance", accountIdHex, isPublic);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

QString LEZWalletBackend::getPublicAccountKey(QString accountIdHex)
{
    if (!m_walletClient) return QString();
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "get_public_account_key", accountIdHex);
    return result.isValid() ? result.toString() : QString();
}

QString LEZWalletBackend::getPrivateAccountKeys(QString accountIdHex)
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

QString LEZWalletBackend::transferPublic(QString fromHex, QString toHex, QString amountStr)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_public", fromHex, toHex, amountHex);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

QString LEZWalletBackend::transferPrivate(QString fromHex, QString toHex, QString amountStr)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");

    QString keysPayload = toHex.trimmed();
    // If "To" is not JSON (e.g. user pasted account id hex), resolve to keys.
    if (!keysPayload.startsWith(QLatin1Char('{'))) {
        qDebug() << "LEZWalletBackend::transferPrivate: keysPayload is not JSON, resolving via get_private_account_keys";
        const QString resolved = getPrivateAccountKeys(keysPayload);
        if (!resolved.isEmpty())
            keysPayload = resolved;
    }

    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_private",
        fromHex, keysPayload, amountHex,
        Timeout(6 * 60 * 1000)); // 6 minute timeout
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

QString LEZWalletBackend::transferPrivateOwned(QString fromHex, QString toHex, QString amountStr)
{
    if (!m_walletClient) return QStringLiteral("Error: Module not initialized.");
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "transfer_private_owned", fromHex, toHex.trimmed(), amountHex);
    return result.isValid() ? result.toString() : QStringLiteral("Error: Call failed.");
}

bool LEZWalletBackend::createNew(QString configPath, QString storagePath, QString password)
{
    if (!m_walletClient) return false;
    const QString localPath = toLocalPath(configPath);
    QVariant result = m_walletClient->invokeRemoteMethod(
        WALLET_MODULE_NAME, "create_new", localPath, storagePath, password);
    int err = result.isValid() ? result.toInt() : -1;
    if (err != WALLET_FFI_SUCCESS) return false;

    persistConfigPath(localPath);
    persistStoragePath(storagePath);
    setIsWalletOpen(true);
    refreshAccounts();
    refreshBlockHeights();
    refreshSequencerAddr();
    return true;
}

void LEZWalletBackend::copyToClipboard(QString text)
{
    if (QGuiApplication::clipboard())
        QGuiApplication::clipboard()->setText(text);
}
