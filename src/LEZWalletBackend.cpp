#include "LEZWalletBackend.h"

#include <QAbstractItemModel>
#include <QClipboard>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QTimer>
#include <QUrl>

#include "logos_api.h"
#include "logos_api_client.h"
#include "logos_sdk.h"

namespace {
    const char SETTINGS_ORG[] = "Logos";
    const char SETTINGS_APP[] = "ExecutionZoneWalletUI";
    const char CONFIG_PATH_KEY[] = "configPath";
    const char STORAGE_PATH_KEY[] = "storagePath";
    const char LEZ_MODULE[] = "logos_execution_zone";
    const int WALLET_FFI_SUCCESS = 0;
    // Proof generation time is unbounded on commodity hardware.
    // Timeout(-1) means "wait indefinitely", matching Qt's own convention
    // for infinite waits (e.g. QRemoteObjectPendingCall::waitForFinished(-1)).
    const Timeout NO_TIMEOUT{-1};

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
      m_privateAccountModel(new LEZAccountFilterModel(this)),
      m_logosAPI(logosAPI ? logosAPI : new LogosAPI("lez_wallet_ui", this)),
      m_logos(new LogosModules(m_logosAPI))
{
    m_filteredAccountModel->setSourceModel(m_accountModel);
    m_privateAccountModel->setFilterByPublic(false);
    m_privateAccountModel->setSourceModel(m_accountModel);

    // Initialise PROP defaults via the generated setters.
    setIsWalletOpen(false);
    setLastSyncedBlock(0);
    setCurrentBlockHeight(0);

    // Load persisted config/storage paths.
    QSettings s(SETTINGS_ORG, SETTINGS_APP);
    setConfigPath(s.value(CONFIG_PATH_KEY).toString());
    setStoragePath(s.value(STORAGE_PATH_KEY).toString());

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
    delete m_logos;
}

void LEZWalletBackend::saveWallet()
{
    if (isWalletOpen()) {
        m_logos->logos_execution_zone.save();
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
    if (configPath().isEmpty() || storagePath().isEmpty()) return;

    qDebug() << "LEZWalletBackend: opening wallet with config" << configPath()
             << "storage" << storagePath();
    int err = m_logos->logos_execution_zone.open(configPath(), storagePath());
    if (err == WALLET_FFI_SUCCESS) {
        qDebug() << "LEZWalletBackend: wallet opened successfully";
        setIsWalletOpen(true);
        QJsonArray arr = m_logos->logos_execution_zone.list_accounts();
        m_accountModel->replaceFromJsonArray(arr);
        fetchAndUpdateBlockHeights();
        startChunkedSync();
        refreshSequencerAddr();
    } else {
        qWarning() << "LEZWalletBackend: failed to open wallet, error" << err
                   << "config:" << configPath() << "storage:" << storagePath();
    }
}

void LEZWalletBackend::refreshAccounts()
{
    QJsonArray arr = m_logos->logos_execution_zone.list_accounts();
    m_accountModel->replaceFromJsonArray(arr);
    fetchAndUpdateBlockHeights();
    if (!m_syncing)
        startChunkedSync();
}

void LEZWalletBackend::refreshBalances()
{
    fetchAndUpdateBlockHeights();
    if (!m_syncing)
        startChunkedSync();
}

void LEZWalletBackend::startChunkedSync()
{
    m_syncTarget = static_cast<quint64>(currentBlockHeight());
    if (m_syncTarget == 0 || static_cast<quint64>(lastSyncedBlock()) >= m_syncTarget) {
        updateBalances();
        return;
    }
    m_syncing = true;
    syncNextChunk();
}

void LEZWalletBackend::syncNextChunk()
{
    const quint64 synced = static_cast<quint64>(lastSyncedBlock());
    if (synced >= m_syncTarget) {
        m_syncing = false;
        fetchAndUpdateBlockHeights();
        updateBalances();
        return;
    }
    const quint64 next = qMin(synced + SYNC_CHUNK_SIZE, m_syncTarget);
    m_logos->logos_execution_zone.sync_to_block(next);
    // Only read lastSyncedBlock between chunks — avoids a sequencer network
    // call (get_current_block_height) on every iteration.
    const int lastVal = m_logos->logos_execution_zone.get_last_synced_block();
    if (lastSyncedBlock() != lastVal)
        setLastSyncedBlock(lastVal);
    QTimer::singleShot(0, this, &LEZWalletBackend::syncNextChunk);
}

void LEZWalletBackend::updateBalances()
{
    if (!m_accountModel) return;
    bool anyFailed = false;
    for (int i = 0; i < m_accountModel->count(); ++i) {
        const QModelIndex idx = m_accountModel->index(i, 0);
        const QString addr = m_accountModel->data(idx, LEZWalletAccountModel::AccountIdRole).toString();
        const bool isPub = m_accountModel->data(idx, LEZWalletAccountModel::IsPublicRole).toBool();
        const QString bal = getBalance(addr, isPub);
        if (!bal.isEmpty())
            m_accountModel->setBalanceByAccountId(addr, bal);
        else
            anyFailed = true;
    }
    if (anyFailed)
        QTimer::singleShot(3000, this, &LEZWalletBackend::updateBalances);
    else
        saveWallet();
}

void LEZWalletBackend::fetchAndUpdateBlockHeights()
{
    const int lastVal = m_logos->logos_execution_zone.get_last_synced_block();
    const int currentVal = m_logos->logos_execution_zone.get_current_block_height();
    if (lastSyncedBlock() != lastVal)
        setLastSyncedBlock(lastVal);
    if (currentBlockHeight() != currentVal)
        setCurrentBlockHeight(currentVal);
}


void LEZWalletBackend::refreshSequencerAddr()
{
    const QString addr = m_logos->logos_execution_zone.get_sequencer_addr();
    if (sequencerAddr() != addr)
        setSequencerAddr(addr);
}

QString LEZWalletBackend::createAccountPublic()
{
    QString result = m_logos->logos_execution_zone.create_account_public();
    if (!result.isEmpty())
        refreshAccounts();
    return result;
}

QString LEZWalletBackend::createAccountPrivate()
{
    QString result = m_logos->logos_execution_zone.create_account_private();
    if (!result.isEmpty())
        refreshAccounts();
    return result;
}

QString LEZWalletBackend::getBalance(QString accountIdHex, bool isPublic)
{
    return m_logos->logos_execution_zone.get_balance(accountIdHex, isPublic);
}

QString LEZWalletBackend::getPublicAccountKey(QString accountIdHex)
{
    return m_logos->logos_execution_zone.get_public_account_key(accountIdHex);
}

QString LEZWalletBackend::getPrivateAccountKeys(QString accountIdHex)
{
    return m_logos->logos_execution_zone.get_private_account_keys(accountIdHex);
}

bool LEZWalletBackend::syncToBlock(quint64 blockId)
{
    int err = m_logos->logos_execution_zone.sync_to_block(blockId);
    return err == WALLET_FFI_SUCCESS;
}

QString LEZWalletBackend::transferPublic(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logos->logos_execution_zone.transfer_public(fromHex, toHex, amountHex);
}

QString LEZWalletBackend::transferPrivate(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");

    QString keysPayload = toHex.trimmed();
    if (!keysPayload.startsWith(QLatin1Char('{'))) {
        qDebug() << "LEZWalletBackend::transferPrivate: resolving keys via get_private_account_keys";
        const QString resolved = getPrivateAccountKeys(keysPayload);
        if (!resolved.isEmpty())
            keysPayload = resolved;
    }

    return m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethod(
        LEZ_MODULE, "transfer_private",
        QVariantList{fromHex.trimmed(), keysPayload, amountHex},
        NO_TIMEOUT).toString();
}

QString LEZWalletBackend::transferPrivateOwned(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethod(
        LEZ_MODULE, "transfer_private_owned",
        QVariantList{fromHex.trimmed(), toHex.trimmed(), amountHex},
        NO_TIMEOUT).toString();
}

QString LEZWalletBackend::transferShielded(QString fromHex, QString toKeysJson, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");

    QString keysPayload = toKeysJson.trimmed();
    if (!keysPayload.startsWith(QLatin1Char('{'))) {
        qDebug() << "LEZWalletBackend::transferShielded: resolving keys via get_private_account_keys";
        const QString resolved = getPrivateAccountKeys(keysPayload);
        if (!resolved.isEmpty())
            keysPayload = resolved;
    }

    return m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethod(
        LEZ_MODULE, "transfer_shielded",
        QVariantList{fromHex.trimmed(), keysPayload, amountHex},
        NO_TIMEOUT).toString();
}

QString LEZWalletBackend::transferShieldedOwned(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethod(
        LEZ_MODULE, "transfer_shielded_owned",
        QVariantList{fromHex.trimmed(), toHex.trimmed(), amountHex},
        NO_TIMEOUT).toString();
}

QString LEZWalletBackend::transferDeshielded(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethod(
        LEZ_MODULE, "transfer_deshielded",
        QVariantList{fromHex.trimmed(), toHex.trimmed(), amountHex},
        NO_TIMEOUT).toString();
}

void LEZWalletBackend::applySequencerAddrToConfig(const QString& configPath, const QString& sequencerAddr)
{
    QJsonObject obj;
    QFile file(configPath);
    if (file.open(QIODevice::ReadOnly)) {
        obj = QJsonDocument::fromJson(file.readAll()).object();
        file.close();
    } else {
        // Defaults matching WalletConfig::default() in the wallet crate.
        obj[QStringLiteral("seq_poll_timeout")]        = QStringLiteral("30s");
        obj[QStringLiteral("seq_tx_poll_max_blocks")]  = 15;
        obj[QStringLiteral("seq_poll_max_retries")]    = 10;
        obj[QStringLiteral("seq_block_poll_max_amount")] = 100;
    }
    obj[QStringLiteral("sequencer_addr")] = sequencerAddr;

    QDir().mkpath(QFileInfo(configPath).absolutePath());
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
}

bool LEZWalletBackend::createNew(QString configPath, QString storagePath, QString password, QString sequencerAddr)
{
    const QString localConfigPath = toLocalPath(configPath);
    const QString localStoragePath = toLocalPath(storagePath);

    if (!sequencerAddr.isEmpty())
        applySequencerAddrToConfig(localConfigPath, sequencerAddr);

    int err = m_logos->logos_execution_zone.create_new(localConfigPath, localStoragePath, password);
    if (err != WALLET_FFI_SUCCESS) return false;

    persistConfigPath(localConfigPath);
    persistStoragePath(localStoragePath);
    setIsWalletOpen(true);
    refreshAccounts();
    refreshSequencerAddr();
    return true;
}

void LEZWalletBackend::copyToClipboard(QString text)
{
    if (QGuiApplication::clipboard())
        QGuiApplication::clipboard()->setText(text);
}
