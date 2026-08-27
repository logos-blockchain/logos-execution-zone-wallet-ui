#include "LEZWalletBackend.h"

#include <algorithm>
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
#include <QStandardPaths>
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
    const char LEZ_MODULE[] = "lez_core";
    const char TESTNET_URL[] = "https://testnet.lez.logos.co";
    const char LOCALHOST_URL[] = "http://127.0.0.1:3040";
    const int WALLET_FFI_SUCCESS = 0;
    // Proof generation time is unbounded on commodity hardware.
    // Timeout(-1) means "wait indefinitely", matching Qt's own convention
    // for infinite waits (e.g. QRemoteObjectPendingCall::waitForFinished(-1)).
    const Timeout NO_TIMEOUT{-1};
    // Warm-up retry budget for openIfPathsConfigured(), 50ms x up to 100 attempts
    // ~= 5s, matching LogosAPIConsumer's own connect-retry budget.
    const int MODULE_WARMUP_RETRY_MS = 50;
    const int MODULE_WARMUP_MAX_ATTEMPTS = 100;

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
        QString p = path.trimmed();
        if (p.startsWith(QLatin1Char('~')))
            return QDir::homePath() + p.mid(1);
        if (p.startsWith(QLatin1String("file://")))
            return QUrl(p).toLocalFile();
        return p;
    }

    // Last resort when lez_core reports no persistence directory -- see
    // LEZWalletBackend::defaultWalletDir()
    QString fallbackWalletDir() {
        QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
        if (base.isEmpty())
            base = QDir::tempPath();
        return QDir(base).filePath(QStringLiteral("lez_wallet"));
    }

    // lez_core has no UI-facing concept of a statistics file; derive one deterministically
    // next to the storage file so onboarding doesn't need a third path picker.
    QString statisticsPathFor(const QString& localStoragePath) {
        const QFileInfo info(localStoragePath);
        return info.absolutePath() + QStringLiteral("/statistics.json");
    }

    // An account is uninitialized until some program claims it (program_owner goes
    // from all-zero to that program's ID) — see DEFAULT_PROGRAM_ID in the execution
    // zone's state machine. Accounts this wallet creates are only ever claimed by the
    // authenticated-transfer program (via an explicit init or as a side effect of
    // receiving a transfer to a still-unclaimed account), so "non-zero owner" is
    // enough to show as initialized without needing that program's ID here.
    bool accountJsonIsInitialized(const QString& accountJson) {
        const QJsonDocument doc = QJsonDocument::fromJson(accountJson.toUtf8());
        if (!doc.isObject())
            return false;
        const QString programOwner = doc.object().value(QStringLiteral("program_owner")).toString();
        return std::any_of(programOwner.cbegin(), programOwner.cend(),
            [](QChar c) { return c != QLatin1Char('0'); });
    }

    // createNew()'s reply shape (see the .rep): the recovery phrase has to reach
    // the view, so success cannot be signalled by an empty string the way the
    // other slots do.
    QString createResult(bool success, const QString& key, const QString& value) {
        QJsonObject obj;
        obj[QStringLiteral("success")] = success;
        obj[key] = value;
        return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
    }
    QString createFailed(const QString& error)    { return createResult(false, QStringLiteral("error"), error); }
    QString createSucceeded(const QString& words) { return createResult(true, QStringLiteral("mnemonic"), words); }
}

LEZWalletBackend::LEZWalletBackend(LogosAPI* logosAPI, QObject* parent)
    : LEZWalletBackendSimpleSource(parent),
      m_accountModel(new LEZWalletAccountModel(this)),
      m_filteredAccountModel(new LEZAccountFilterModel(this)),
      m_privateAccountModel(new LEZAccountFilterModel(this)),
      m_claimableAccountModel(new LEZClaimableAccountFilterModel(this)),
      m_logosAPI(logosAPI ? logosAPI : new LogosAPI("lez_wallet_ui", this)),
      m_logos(new LogosModules(m_logosAPI))
{
    // Both feed the transfer/withdraw "from"/"to" account-picker combo boxes, where an
    // uninitialized account isn't a usable sender or recipient — unlike m_accountModel
    // (unfiltered), which AccountsPanel needs to keep showing them on for initialization.
    m_filteredAccountModel->setOnlyInitialized(true);
    m_filteredAccountModel->setSourceModel(m_accountModel);
    m_privateAccountModel->setFilterByPublic(false);
    m_privateAccountModel->setOnlyInitialized(true);
    m_privateAccountModel->setSourceModel(m_accountModel);
    m_claimableAccountModel->setSourceModel(m_accountModel);

    // Initialise PROP defaults via the generated setters.
    setIsWalletOpen(false);
    setLastSyncedBlock(0);
    setCurrentBlockHeight(0);
    setTestnetUrl(QString::fromLatin1(TESTNET_URL));
    setLocalhostUrl(QString::fromLatin1(LOCALHOST_URL));

    // Load persisted config/storage paths.
    QSettings s(SETTINGS_ORG, SETTINGS_APP);
    setConfigPath(s.value(CONFIG_PATH_KEY).toString());
    setStoragePath(s.value(STORAGE_PATH_KEY).toString());
    setIsStartupResolved(configPath().isEmpty() || storagePath().isEmpty());

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
    if (!isWalletOpen())
        return;

    const qint64 err = m_logos->lez_core.save();
    if (err == WALLET_FFI_SUCCESS)
        return;

    qWarning() << "LEZWalletBackend: failed to save wallet, error" << err
               << "storage:" << storagePath();
    reportNotice(tr("Could not save your wallet to %1 (error %2). Recent changes "
                         "may be lost if you quit.")
                          .arg(storagePath(), QString::number(err)));
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

QString LEZWalletBackend::defaultWalletDir()
{
    const QString fromModule = m_logos->lez_core.wallet_dir();

    if (fromModule.isEmpty()) {
        qWarning() << "LEZWalletBackend: lez_core did not answer wallet_dir();"
                   << "not guessing a wallet location.";
        return QString();
    }

    // Reachable, but running without host-provisioned persistence -- a bare
    // logoscore, say. The fallback is unmanaged, so say so loudly.
    if (fromModule == QLatin1String("-")) {
        qWarning() << "LEZWalletBackend: lez_core has no persistence directory;"
                   << "falling back to" << fallbackWalletDir();
        return fallbackWalletDir();
    }

    return fromModule;
}

// Blank the value first so a failure that repeats verbatim still emits a change.
// Without this a second identical save failure would set the same string, QtRO
// would see no change, and the notice would never reach the view -- which is the
// only reason this ever needed a clear-from-the-view slot.
void LEZWalletBackend::reportNotice(const QString& message)
{
    setNotice(QString());
    setNotice(message);
}

void LEZWalletBackend::clearSavedPaths()
{
    QSettings s(SETTINGS_ORG, SETTINGS_APP);
    s.remove(CONFIG_PATH_KEY);
    s.remove(STORAGE_PATH_KEY);
    setConfigPath(QString());
    setStoragePath(QString());
}

void LEZWalletBackend::finishStartup()
{
    setIsStartupResolved(true);
}

void LEZWalletBackend::openIfPathsConfigured(int attempt)
{
    if (configPath().isEmpty() || storagePath().isEmpty()) {
        finishStartup();
        return;
    }

    if (!QFile::exists(configPath()) || !QFile::exists(storagePath())) {
        qWarning() << "LEZWalletBackend: saved wallet files missing, clearing saved paths."
                   << "config:" << configPath() << "storage:" << storagePath();
        reportNotice(tr("Your saved wallet files were not found, so they have been "
                            "forgotten.\nConfig: %1\nStorage: %2")
                             .arg(configPath(), storagePath()));
        clearSavedPaths();
        finishStartup();
        return;
    }

    // The first cross-process call this module makes to lez_core can race
    // the inter-module capability/auth-token handshake: if it goes out before the
    // target has been informed of our token, ModuleProxy rejects it and the call
    // resolves to a default-constructed return value -- 0 for open()'s int64_t, which
    // is indistinguishable from WALLET_FFI_SUCCESS. Warm up with a harmless,
    // wallet-state-free call first: version() defaults to "" on that same rejection,
    // which IS distinguishable from its real non-empty value, so we can retry here
    // until the handshake has settled before trusting open()'s result. Once any call
    // to lez_core succeeds, its token is cached for the rest of the
    // session, so open() itself won't hit this race afterwards.
    if (m_logos->lez_core.version().isEmpty() && attempt < MODULE_WARMUP_MAX_ATTEMPTS) {
        QTimer::singleShot(MODULE_WARMUP_RETRY_MS, this,
            [this, attempt]() { openIfPathsConfigured(attempt + 1); });
        return;
    }

    qDebug() << "LEZWalletBackend: opening wallet with config" << configPath()
             << "storage" << storagePath();
    const qint64 err = openWalletAt(configPath(), storagePath());
    if (err == WALLET_FFI_SUCCESS) {
        qDebug() << "LEZWalletBackend: wallet opened successfully";
        finishOpeningWallet();
        finishStartup();
        return;
    }

    qWarning() << "LEZWalletBackend: failed to open saved wallet, error" << err
               << "config:" << configPath() << "storage:" << storagePath();
    reportNotice(tr("Your saved wallet could not be opened (error %1), so the saved "
                        "location has been forgotten.\nConfig: %2\nStorage: %3")
                         .arg(QString::number(err), configPath(), storagePath()));
    clearSavedPaths();
    finishStartup();
}

qint64 LEZWalletBackend::openWalletAt(const QString& localConfigPath, const QString& localStoragePath)
{
    return m_logos->lez_core.open(localConfigPath, localStoragePath,
                                  statisticsPathFor(localStoragePath));
}

// Tags each private account with the NPK of the key group it belongs to (plus that
// group's {nullifier_public_key, viewing_public_key} JSON), so the model can section
// accounts by key group instead of listing them flat. Public accounts are untouched.
QVariantList LEZWalletBackend::buildEnrichedAccountList()
{
    QVariantList raw = m_logos->lez_core.list_accounts();
    QVariantList enriched;
    enriched.reserve(raw.size());
    for (const QVariant& v : raw) {
        QVariantMap map = v.toMap();
        const QString accountId = map.value(QStringLiteral("account_id")).toString();
        const bool isPublic = map.value(QStringLiteral("is_public"), true).toBool();
        if (!isPublic) {
            const QString keysJson = getPrivateAccountKeys(accountId);
            const QJsonDocument doc = QJsonDocument::fromJson(keysJson.toUtf8());
            if (doc.isObject()) {
                map[QStringLiteral("npk")] = doc.object().value(QStringLiteral("nullifier_public_key")).toString();
                map[QStringLiteral("keys_json")] = keysJson;
            }
        }
        const QString accountJson = isPublic
            ? m_logos->lez_core.get_account_public(accountId)
            : m_logos->lez_core.get_account_private(accountId);
        map[QStringLiteral("is_initialized")] = accountJsonIsInitialized(accountJson);
        const QStringList labels = m_logos->lez_core.get_all_labels_for_account(accountId, !isPublic);
        if (!labels.isEmpty())
            map[QStringLiteral("name")] = labels.join(QStringLiteral(", "));
        enriched.append(map);
    }
    return enriched;
}

void LEZWalletBackend::finishOpeningWallet()
{
    setIsWalletOpen(true);
    QTimer::singleShot(0, this, [this]() {
        m_accountModel->replaceFromVariantList(buildEnrichedAccountList());
        fetchAndUpdateBlockHeights();
        startChunkedSync();
        refreshSequencerAddr();
    });
}

void LEZWalletBackend::refreshAccounts()
{
    m_accountModel->replaceFromVariantList(buildEnrichedAccountList());
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
        // Sync may have discovered new private accounts (e.g. shielded transfers to a
        // foreign NPK/VPK); re-list so the model picks them up without a restart.
        m_accountModel->replaceFromVariantList(buildEnrichedAccountList());
        fetchAndUpdateBlockHeights();
        updateBalances();
        return;
    }
    const quint64 next = qMin(synced + SYNC_CHUNK_SIZE, m_syncTarget);
    m_logos->lez_core.sync_to_block(next);
    // Only read lastSyncedBlock between chunks — avoids a sequencer network
    // call (get_current_block_height) on every iteration.
    const int lastVal = m_logos->lez_core.get_last_synced_block();

    if (static_cast<quint64>(lastVal) <= synced) {
        qWarning() << "LEZWalletBackend: sync made no progress at block" << synced
                   << "(target" << m_syncTarget << "), stopping.";
        m_syncing = false;
        updateBalances();
        return;
    }

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

        // Initialization is one-way (program_owner never reverts to zero), so once an
        // account is known initialized there's no need to keep re-checking it here.
        // Pending accounts get re-checked on every balance refresh so the "Initialize"
        // tag catches up once the registration tx lands in a block, without requiring
        // another manual Initialize click.
        const bool alreadyInitialized = m_accountModel->data(idx, LEZWalletAccountModel::IsInitializedRole).toBool();
        if (!alreadyInitialized) {
            const QString accountJson = isPub
                ? m_logos->lez_core.get_account_public(addr)
                : m_logos->lez_core.get_account_private(addr);
            if (accountJsonIsInitialized(accountJson))
                m_accountModel->setInitializedByAccountId(addr, true);
        }
    }
    if (anyFailed)
        QTimer::singleShot(3000, this, &LEZWalletBackend::updateBalances);
    else
        saveWallet();
}

void LEZWalletBackend::fetchAndUpdateBlockHeights()
{
    const int lastVal = m_logos->lez_core.get_last_synced_block();
    const int currentVal = m_logos->lez_core.get_current_block_height();
    if (lastSyncedBlock() != lastVal)
        setLastSyncedBlock(lastVal);
    if (currentBlockHeight() != currentVal)
        setCurrentBlockHeight(currentVal);
}


void LEZWalletBackend::refreshSequencerAddr()
{
    const QString addr = m_logos->lez_core.get_sequencer_addr();
    if (sequencerAddr() != addr)
        setSequencerAddr(addr);
}

QString LEZWalletBackend::createAccountPublic()
{
    QString result = m_logos->lez_core.create_account_public();
    if (!result.isEmpty())
        refreshAccounts();
    return result;
}

QString LEZWalletBackend::createAccountPrivate()
{
    QString result = m_logos->lez_core.create_account_private();
    if (!result.isEmpty())
        refreshAccounts();
    return result;
}

QString LEZWalletBackend::getBalance(QString accountIdHex, bool isPublic)
{
    return m_logos->lez_core.get_balance(accountIdHex, isPublic);
}

QString LEZWalletBackend::getPublicAccountKey(QString accountIdHex)
{
    return m_logos->lez_core.get_public_account_key(accountIdHex);
}

QString LEZWalletBackend::getPrivateAccountKeys(QString accountIdHex)
{
    return m_logos->lez_core.get_private_account_keys(accountIdHex);
}

QString LEZWalletBackend::initializeAccount(QString accountIdHex)
{
    // Public accounts only: public account initialization requires authorization,
    // so it needs a manual init signed by the owner. Private accounts don't require
    // authorization to initialize, so they never go through here. Registration is a
    // plain public tx (like transferPublic, no proof needed), so the generated
    // accessor's default timeout is fine.
    // sendTransaction only waits for mempool acceptance, not block inclusion, so the
    // account is never actually initialized yet by the time this returns — no point
    // triggering a full (blinking) account-list rebuild here. updateBalances() picks
    // up the is_initialized flip later, without a full reset, once the tx confirms.
    return m_logos->lez_core.register_public_account(accountIdHex);
}

bool LEZWalletBackend::syncToBlock(quint64 blockId)
{
    int err = m_logos->lez_core.sync_to_block(blockId);
    return err == WALLET_FFI_SUCCESS;
}

QString LEZWalletBackend::transferPublic(QString fromHex, QString toHex, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    return m_logos->lez_core.transfer_public(fromHex, toHex, amountHex);
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

QString LEZWalletBackend::bridgeWithdraw(QString fromHex, QString bedrockAccountPkHex, quint64 amount)
{
    return m_logos->lez_core.bridge_withdraw(fromHex, bedrockAccountPkHex, amount);
}

QString LEZWalletBackend::getVaultBalance(const QString& accountIdHex)
{
    return m_logos->lez_core.get_vault_balance(accountIdHex);
}

void LEZWalletBackend::refreshVaultBalances()
{
    if (!m_accountModel) return;
    for (int i = 0; i < m_accountModel->count(); ++i) {
        const QModelIndex idx = m_accountModel->index(i, 0);
        const QString addr = m_accountModel->data(idx, LEZWalletAccountModel::AccountIdRole).toString();
        const QString vaultBal = getVaultBalance(addr);
        if (!vaultBal.isEmpty())
            m_accountModel->setVaultBalanceByAccountId(addr, vaultBal);
    }
}

QString LEZWalletBackend::vaultClaim(QString fromHex, bool isPublic, QString amountStr)
{
    const QString amountHex = amountToLe16Hex(amountStr);
    if (amountHex.isEmpty()) return QStringLiteral("Error: Invalid amount.");
    // Don't trust the caller-supplied isPublic — the account model is the source of
    // truth for which accounts the wallet owns and whether each is public or private.
    const bool actuallyPublic = m_accountModel
        ? m_accountModel->isPublicAccount(fromHex, isPublic)
        : isPublic;
    if (actuallyPublic)
        return m_logos->lez_core.vault_claim(fromHex, amountHex);

    // vault_claim_private generates a proof, like transfer_private/transfer_shielded
    // above — go through invokeRemoteMethod with NO_TIMEOUT instead of the generated
    // accessor, which applies the SDK's default 20s Timeout and returns before the
    // proof is actually done and the tx submitted.
    return m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethod(
        LEZ_MODULE, "vault_claim_private",
        QVariantList{fromHex.trimmed(), amountHex},
        NO_TIMEOUT).toString();
}

void LEZWalletBackend::applySequencerAddrToConfig(const QString& configPath, const QString& sequencerAddr)
{
    QJsonObject obj;
    QFile file(configPath);
    if (file.open(QIODevice::ReadOnly)) {
        obj = QJsonDocument::fromJson(file.readAll()).object();
        file.close();
    }

    if (obj.isEmpty()) {
        obj[QStringLiteral("seq_poll_timeout")]          = QStringLiteral("30s");
        obj[QStringLiteral("seq_tx_poll_max_blocks")]    = 15;
        obj[QStringLiteral("seq_poll_max_retries")]      = 10;
        obj[QStringLiteral("seq_block_poll_max_amount")] = 100;
    }

    QJsonObject sequencerEntry;
    sequencerEntry[QStringLiteral("sequencer_addr")] = sequencerAddr;
    sequencerEntry[QStringLiteral("basic_auth")]     = QJsonValue::Null;
    obj[QStringLiteral("sequencers")] = QJsonArray{ sequencerEntry };

    QDir().mkpath(QFileInfo(configPath).absolutePath());
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
}

QString LEZWalletBackend::createNew(QString password, QString sequencerAddr)
{
    const QString walletDir = defaultWalletDir();
    if (walletDir.isEmpty())
        return createFailed(tr("Could not reach the wallet module. Please try again."));

    const QString localConfigPath = QDir(walletDir).filePath(QStringLiteral("config.json"));
    const QString localStoragePath = QDir(walletDir).filePath(QStringLiteral("storage.json"));

    if (QFile::exists(localStoragePath)) {
        qWarning() << "LEZWalletBackend: refusing to create over existing storage at"
                   << localStoragePath;
        return createFailed(tr("A wallet already exists at %1. Move or remove those "
                               "files before creating a new wallet here, or use "
                               "\"Open wallet instead\" to load it.")
                                .arg(localStoragePath));
    }

    if (!QDir().mkpath(walletDir))
        return createFailed(tr("Could not create the wallet folder at %1.").arg(walletDir));

    // create_new reads the sequencer out of this file, so it has to exist first.
    const bool configExisted = QFile::exists(localConfigPath);
    if (!sequencerAddr.isEmpty())
        applySequencerAddrToConfig(localConfigPath, sequencerAddr);

    const QString mnemonic = m_logos->lez_core.create_new(
        localConfigPath, localStoragePath, statisticsPathFor(localStoragePath), password);
    if (mnemonic.isEmpty()) {
        qWarning() << "LEZWalletBackend: create_new returned no mnemonic. config:"
                   << localConfigPath << "storage:" << localStoragePath;
        if (!configExisted)
            QFile::remove(localConfigPath);
        return createFailed(tr("Failed to create the wallet at %1.").arg(walletDir));
    }

    const qint64 saveErr = m_logos->lez_core.save();
    if (saveErr != WALLET_FFI_SUCCESS || !QFile::exists(localStoragePath)) {
        qWarning() << "LEZWalletBackend: wallet created but not persisted. save error"
                   << saveErr << "storage:" << localStoragePath;
        return createFailed(tr("The wallet was created but could not be written to %1. "
                               "Nothing has been saved -- try again.")
                                .arg(localStoragePath));
    }

    persistConfigPath(localConfigPath);
    persistStoragePath(localStoragePath);
    finishOpeningWallet();
    return createSucceeded(mnemonic);
}

QString LEZWalletBackend::openExisting(QString configPath, QString storagePath)
{
    const QString localConfigPath = toLocalPath(configPath);
    const QString localStoragePath = toLocalPath(storagePath);

    if (localConfigPath.isEmpty() || localStoragePath.isEmpty())
        return tr("Select both a config file and a storage file.");

    if (!QFile::exists(localConfigPath))
        return tr("No config file at %1.").arg(localConfigPath);
    if (!QFile::exists(localStoragePath))
        return tr("No storage file at %1.").arg(localStoragePath);

    const qint64 err = openWalletAt(localConfigPath, localStoragePath);
    if (err != WALLET_FFI_SUCCESS) {
        qWarning() << "LEZWalletBackend: openExisting failed, error" << err
                   << "config:" << localConfigPath << "storage:" << localStoragePath;
        return tr("Could not open the wallet at those paths (error %1).").arg(err);
    }

    persistConfigPath(localConfigPath);
    persistStoragePath(localStoragePath);
    finishOpeningWallet();
    return QString();
}

void LEZWalletBackend::copyToClipboard(QString text)
{
    if (QGuiApplication::clipboard())
        QGuiApplication::clipboard()->setText(text);
}

bool LEZWalletBackend::checkLabelAvailable(QString label)
{
    return m_logos->lez_core.check_label_available(label.trimmed());
}

QString LEZWalletBackend::addLabel(QString label, QString accountIdHex, bool isPublic)
{
    const QString trimmedLabel = label.trimmed();
    if (trimmedLabel.isEmpty())
        return QStringLiteral("Error: Label cannot be empty.");

    const int err = m_logos->lez_core.add_label(trimmedLabel, accountIdHex.trimmed(), !isPublic);
    if (err != WALLET_FFI_SUCCESS)
        return QStringLiteral("Error: wallet FFI error %1").arg(err);

    refreshAccounts();
    return QString();
}
