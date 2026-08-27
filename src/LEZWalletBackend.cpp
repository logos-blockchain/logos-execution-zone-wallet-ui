#include "LEZWalletBackend.h"

#include <algorithm>
#include <QAbstractItemModel>
#include <QCoreApplication>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QTimer>

#include <utility>

#include "logos_api.h"
#include "logos_api_client.h"
#include "logos_call_error.h"
#include "logos_sdk.h"

namespace {
    const char LEZ_MODULE[] = "lez_core";
    const int WALLET_FFI_SUCCESS = 0;
    // Proof generation time is unbounded on commodity hardware.
    // Timeout(-1) means "wait indefinitely", matching Qt's own convention
    // for infinite waits (e.g. QRemoteObjectPendingCall::waitForFinished(-1)).
    const Timeout NO_TIMEOUT{-1};
    // Warm-up retry budget for the shared-core handshake, 50ms x up to 100 attempts
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
    setWalletState(QStringLiteral("closed"));
    setWalletErrorCode(QString());
    setWalletError(QString());
    setLastSyncedBlock(0);
    setCurrentBlockHeight(0);

    WalletStartupFlow::Coordinator::Hooks startupHooks;
    startupHooks.invoke = [this](const QString& method,
                              WalletStartupFlow::Coordinator::CallCompletion completion) {
        invokeCoreAsync(method, {},
            [completion = std::move(completion)](QVariant value, const bool ok) mutable {
                completion(value.toString(), ok);
            });
    };
    startupHooks.schedule = [this](const int delayMs,
                                WalletStartupFlow::Coordinator::Task task) {
        QTimer::singleShot(delayMs, this, std::move(task));
    };
    startupHooks.refreshAccounts = [this](
                                       WalletStartupFlow::Coordinator::RefreshCompletion completion) {
        refreshAccountsForStartup(std::move(completion));
    };
    startupHooks.publish = [this](const WalletStartupFlow::Result& result) {
        applyStartupResult(result);
    };
    m_startup = std::make_unique<WalletStartupFlow::Coordinator>(
        std::move(startupHooks), MODULE_WARMUP_MAX_ATTEMPTS, MODULE_WARMUP_RETRY_MS);

    // ui-host runs our constructor inside initLogos(), synchronously, BEFORE
    // it enables remoting and emits READY. Any blocking RPC here (open,
    // list_accounts, block-height queries, sequencer lookup) would stall
    // ui-host startup past ViewModuleHost's 30s ready watchdog and get the
    // child SIGTERM'd. Defer the whole open+refresh chain to the first
    // event-loop tick so ui-host finishes wiring itself up first.
    QTimer::singleShot(0, this, [this]() { m_startup->start(); });

    // Save wallet when app quits; host may not call destructors so this is best-effort.
    connect(qApp, &QCoreApplication::aboutToQuit, this,
            [this]() { saveWallet(); }, Qt::DirectConnection);
}

LEZWalletBackend::~LEZWalletBackend()
{
    m_startup.reset();
    saveWallet();
    delete m_logos;
}

void LEZWalletBackend::saveWallet()
{
    if (isWalletOpen()) {
        logos::CallError error;
        m_logos->lez_core.save(&error);
    }
}

void LEZWalletBackend::applyStartupResult(const WalletStartupFlow::Result& result)
{
    setWalletState(result.state);
    setWalletErrorCode(result.errorCode);
    setWalletError(result.errorMessage);
    setIsWalletOpen(result.state == QStringLiteral("open"));
    if (result.state == QStringLiteral("open"))
        finishOpeningSharedWallet();
}

void LEZWalletBackend::retryWalletOpen()
{
    m_startup->retry();
}

// Tags each private account with the NPK of the key group it belongs to (plus that
// group's {nullifier_public_key, viewing_public_key} JSON), so the model can section
// accounts by key group instead of listing them flat. Public accounts are untouched.
QVariantList LEZWalletBackend::buildEnrichedAccountList(const QVariantList& raw, bool* success)
{
    *success = false;
    QVariantList enriched;
    enriched.reserve(raw.size());
    for (const QVariant& v : raw) {
        QVariantMap map = v.toMap();
        const QString accountId = map.value(QStringLiteral("account_id")).toString();
        const bool isPublic = map.value(QStringLiteral("is_public"), true).toBool();
        if (!isPublic) {
            logos::CallError error;
            const QString keysJson = m_logos->lez_core.get_private_account_keys(accountId, &error);
            if (!error.ok())
                return {};
            const QJsonDocument doc = QJsonDocument::fromJson(keysJson.toUtf8());
            if (doc.isObject()) {
                map[QStringLiteral("npk")] = doc.object().value(QStringLiteral("nullifier_public_key")).toString();
                map[QStringLiteral("keys_json")] = keysJson;
            }
        }
        logos::CallError accountError;
        const QString accountJson = isPublic
            ? m_logos->lez_core.get_account_public(accountId, &accountError)
            : m_logos->lez_core.get_account_private(accountId, &accountError);
        if (!accountError.ok())
            return {};
        map[QStringLiteral("is_initialized")] = accountJsonIsInitialized(accountJson);
        logos::CallError labelsError;
        const QStringList labels =
            m_logos->lez_core.get_all_labels_for_account(accountId, !isPublic, &labelsError);
        if (!labelsError.ok())
            return {};
        if (!labels.isEmpty())
            map[QStringLiteral("name")] = labels.join(QStringLiteral(", "));
        enriched.append(map);
    }
    *success = true;
    return enriched;
}

bool LEZWalletBackend::replaceAccountsFromCore()
{
    logos::CallError error;
    const QVariantList raw = m_logos->lez_core.list_accounts(&error);
    if (!error.ok())
        return false;

    bool success = false;
    const QVariantList enriched = buildEnrichedAccountList(raw, &success);
    if (!success)
        return false;
    m_accountModel->replaceFromVariantList(enriched);
    return true;
}

void LEZWalletBackend::invokeCoreAsync(
    const QString& method,
    const QVariantList& arguments,
    VariantCompletion completion)
{
    const QPointer<LEZWalletBackend> self(this);
    m_logosAPI->getClient(LEZ_MODULE)->invokeRemoteMethodAsync(
        LEZ_MODULE,
        method,
        arguments,
        LogosAPIClient::AsyncResultErrorCallback(
            [self, completion = std::move(completion)](
                QVariant value, const logos::CallError& error) mutable {
                if (!self)
                    return;
                // Transport detail may contain private paths or provider internals.
                // Discard it here and expose only the typed success bit.
                completion(std::move(value), error.ok());
            }));
}

void LEZWalletBackend::refreshAccountsForStartup(
    WalletStartupFlow::Coordinator::RefreshCompletion completion)
{
    invokeCoreAsync(QStringLiteral("list_accounts"), {},
        [this, completion = std::move(completion)](QVariant value, const bool ok) mutable {
            if (!ok) {
                completion(false);
                return;
            }
            enrichAccountsForStartup(value.toList(), 0, {}, std::move(completion));
        });
}

void LEZWalletBackend::enrichAccountsForStartup(
    QVariantList raw,
    const int index,
    QVariantList enriched,
    WalletStartupFlow::Coordinator::RefreshCompletion completion)
{
    if (index >= raw.size()) {
        m_accountModel->replaceFromVariantList(enriched);
        completion(true);
        return;
    }

    QVariantMap account = raw.at(index).toMap();
    const QString accountId = account.value(QStringLiteral("account_id")).toString();
    const bool isPublic = account.value(QStringLiteral("is_public"), true).toBool();
    if (isPublic) {
        enrichAccountDetailsForStartup(
            std::move(raw), index, std::move(enriched), std::move(account), true,
            std::move(completion));
        return;
    }

    invokeCoreAsync(QStringLiteral("get_private_account_keys"), {accountId},
        [this,
         raw = std::move(raw),
         index,
         enriched = std::move(enriched),
         account = std::move(account),
         completion = std::move(completion)](QVariant value, const bool ok) mutable {
            if (!ok) {
                completion(false);
                return;
            }
            const QString keysJson = value.toString();
            const QJsonDocument document = QJsonDocument::fromJson(keysJson.toUtf8());
            if (document.isObject()) {
                account[QStringLiteral("npk")] =
                    document.object().value(QStringLiteral("nullifier_public_key")).toString();
                account[QStringLiteral("keys_json")] = keysJson;
            }
            enrichAccountDetailsForStartup(
                std::move(raw), index, std::move(enriched), std::move(account), false,
                std::move(completion));
        });
}

void LEZWalletBackend::enrichAccountDetailsForStartup(
    QVariantList raw,
    const int index,
    QVariantList enriched,
    QVariantMap account,
    const bool isPublic,
    WalletStartupFlow::Coordinator::RefreshCompletion completion)
{
    const QString accountId = account.value(QStringLiteral("account_id")).toString();
    invokeCoreAsync(
        isPublic ? QStringLiteral("get_account_public") : QStringLiteral("get_account_private"),
        {accountId},
        [this,
         raw = std::move(raw),
         index,
         enriched = std::move(enriched),
         account = std::move(account),
         accountId,
         isPublic,
         completion = std::move(completion)](QVariant value, const bool ok) mutable {
            if (!ok) {
                completion(false);
                return;
            }
            account[QStringLiteral("is_initialized")] = accountJsonIsInitialized(value.toString());
            invokeCoreAsync(QStringLiteral("get_all_labels_for_account"), {accountId, !isPublic},
                [this,
                 raw = std::move(raw),
                 index,
                 enriched = std::move(enriched),
                 account = std::move(account),
                 completion = std::move(completion)](QVariant value, const bool ok) mutable {
                    if (!ok) {
                        completion(false);
                        return;
                    }
                    const QStringList labels = value.toStringList();
                    if (!labels.isEmpty())
                        account[QStringLiteral("name")] = labels.join(QStringLiteral(", "));
                    enriched.append(account);
                    enrichAccountsForStartup(
                        std::move(raw), index + 1, std::move(enriched), std::move(completion));
                });
        });
}

void LEZWalletBackend::finishOpeningSharedWallet()
{
    fetchAndUpdateBlockHeights();
    startChunkedSync();
    refreshSequencerAddr();
}

void LEZWalletBackend::refreshAccounts()
{
    if (!replaceAccountsFromCore())
        return;
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
        replaceAccountsFromCore();
        fetchAndUpdateBlockHeights();
        updateBalances();
        return;
    }
    const quint64 next = qMin(synced + SYNC_CHUNK_SIZE, m_syncTarget);
    logos::CallError syncError;
    m_logos->lez_core.sync_to_block(next, &syncError);
    if (!syncError.ok()) {
        m_syncing = false;
        return;
    }
    // Only read lastSyncedBlock between chunks — avoids a sequencer network
    // call (get_current_block_height) on every iteration.
    logos::CallError heightError;
    const int lastVal = m_logos->lez_core.get_last_synced_block(&heightError);
    if (!heightError.ok()) {
        m_syncing = false;
        return;
    }
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

        // Initialization is one-way (program_owner never reverts to zero), so once an
        // account is known initialized there's no need to keep re-checking it here.
        // Pending accounts get re-checked on every balance refresh so the "Initialize"
        // tag catches up once the registration tx lands in a block, without requiring
        // another manual Initialize click.
        const bool alreadyInitialized = m_accountModel->data(idx, LEZWalletAccountModel::IsInitializedRole).toBool();
        if (!alreadyInitialized) {
            logos::CallError error;
            const QString accountJson = isPub
                ? m_logos->lez_core.get_account_public(addr, &error)
                : m_logos->lez_core.get_account_private(addr, &error);
            if (error.ok() && accountJsonIsInitialized(accountJson))
                m_accountModel->setInitializedByAccountId(addr, true);
            else if (!error.ok())
                anyFailed = true;
        }
    }
    if (anyFailed)
        QTimer::singleShot(3000, this, &LEZWalletBackend::updateBalances);
    else
        saveWallet();
}

void LEZWalletBackend::fetchAndUpdateBlockHeights()
{
    logos::CallError lastError;
    const int lastVal = m_logos->lez_core.get_last_synced_block(&lastError);
    if (!lastError.ok())
        return;
    logos::CallError currentError;
    const int currentVal = m_logos->lez_core.get_current_block_height(&currentError);
    if (!currentError.ok())
        return;
    if (lastSyncedBlock() != lastVal)
        setLastSyncedBlock(lastVal);
    if (currentBlockHeight() != currentVal)
        setCurrentBlockHeight(currentVal);
}


void LEZWalletBackend::refreshSequencerAddr()
{
    logos::CallError error;
    const QString addr = m_logos->lez_core.get_sequencer_addr(&error);
    if (!error.ok())
        return;
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
    logos::CallError error;
    const QString balance = m_logos->lez_core.get_balance(accountIdHex, isPublic, &error);
    return error.ok() ? balance : QString();
}

QString LEZWalletBackend::getPublicAccountKey(QString accountIdHex)
{
    logos::CallError error;
    const QString key = m_logos->lez_core.get_public_account_key(accountIdHex, &error);
    return error.ok() ? key : QString();
}

QString LEZWalletBackend::getPrivateAccountKeys(QString accountIdHex)
{
    logos::CallError error;
    const QString keys = m_logos->lez_core.get_private_account_keys(accountIdHex, &error);
    return error.ok() ? keys : QString();
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
