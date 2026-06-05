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
#include "logos_sdk.h"

namespace {
    const char SETTINGS_ORG[] = "Logos";
    const char SETTINGS_APP[] = "ExecutionZoneWalletUI";
    const char CONFIG_PATH_KEY[] = "configPath";
    const char STORAGE_PATH_KEY[] = "storagePath";
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
        refreshAccounts();
        refreshBlockHeights();
        refreshSequencerAddr();
    }
}

void LEZWalletBackend::refreshAccounts()
{
    QJsonArray arr = m_logos->logos_execution_zone.list_accounts();
    m_accountModel->replaceFromJsonArray(arr);
    refreshBalances();
}

void LEZWalletBackend::refreshBalances()
{
    refreshBlockHeights();
    syncToBlock(currentBlockHeight());
    if (!m_accountModel) return;
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
    const int lastVal = m_logos->logos_execution_zone.get_last_synced_block();
    const int currentVal = m_logos->logos_execution_zone.get_current_block_height();
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
    // If "To" is not JSON (e.g. user pasted account id hex), resolve to keys.
    if (!keysPayload.startsWith(QLatin1Char('{'))) {
        qDebug() << "LEZWalletBackend::transferPrivate: resolving keys via get_private_account_keys";
        const QString resolved = getPrivateAccountKeys(keysPayload);
        if (!resolved.isEmpty())
            keysPayload = resolved;
    }

    return m_logos->logos_execution_zone.transfer_private(fromHex, keysPayload, amountHex);
}

QString LEZWalletBackend::transferPrivateOwned(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logos->logos_execution_zone.transfer_private_owned(fromHex, toHex.trimmed(), amountHex);
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

    return m_logos->logos_execution_zone.transfer_shielded(fromHex, keysPayload, amountHex);
}

QString LEZWalletBackend::transferShieldedOwned(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logos->logos_execution_zone.transfer_shielded_owned(fromHex, toHex.trimmed(), amountHex);
}

bool LEZWalletBackend::createNew(QString configPath, QString storagePath, QString password)
{
    const QString localPath = toLocalPath(configPath);
    int err = m_logos->logos_execution_zone.create_new(localPath, storagePath, password);
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
