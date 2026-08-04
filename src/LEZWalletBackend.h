#ifndef LEZ_WALLET_BACKEND_H
#define LEZ_WALLET_BACKEND_H

#include <QObject>
#include <QString>
#include <QVariant>

#include <functional>
#include <memory>

#include "rep_LEZWalletBackend_source.h"

#include "LEZAccountFilterModel.h"
#include "LEZClaimableAccountFilterModel.h"
#include "LEZWalletAccountModel.h"
#include "WalletStartupFlow.h"

class LogosAPI;
struct LogosModules;

// Source-side implementation of the LEZWalletBackend .rep interface.
// Inheriting from LEZWalletBackendSimpleSource gives us the generated PROPs
// and SLOTs from LEZWalletBackend.rep — all the simple ones flow over QtRO.
class LEZWalletBackend : public LEZWalletBackendSimpleSource {
    Q_OBJECT
    Q_PROPERTY(LEZWalletAccountModel* accountModel READ accountModel CONSTANT)
    Q_PROPERTY(LEZAccountFilterModel* filteredAccountModel READ filteredAccountModel CONSTANT)
    Q_PROPERTY(LEZAccountFilterModel* privateAccountModel READ privateAccountModel CONSTANT)
    Q_PROPERTY(LEZClaimableAccountFilterModel* claimableAccountModel READ claimableAccountModel CONSTANT)

public:
    explicit LEZWalletBackend(LogosAPI* logosAPI = nullptr, QObject* parent = nullptr);
    ~LEZWalletBackend() override;

    LEZWalletAccountModel* accountModel() const { return m_accountModel; }
    LEZAccountFilterModel* filteredAccountModel() const { return m_filteredAccountModel; }
    LEZAccountFilterModel* privateAccountModel() const { return m_privateAccountModel; }
    LEZClaimableAccountFilterModel* claimableAccountModel() const { return m_claimableAccountModel; }

public slots:
    // Overrides of the pure-virtual slots generated from the .rep.
    QString createAccountPublic() override;
    QString createAccountPrivate() override;
    void refreshAccounts() override;
    QString getBalance(QString accountIdHex, bool isPublic) override;
    void refreshBalances() override;
    QString getPublicAccountKey(QString accountIdHex) override;
    QString getPrivateAccountKeys(QString accountIdHex) override;
    QString initializeAccount(QString accountIdHex) override;
    bool syncToBlock(quint64 blockId) override;
    QString transferPublic(QString fromHex, QString toHex, QString amountStr) override;
    QString transferPrivate(QString fromHex, QString toHex, QString amountStr) override;
    QString transferPrivateOwned(QString fromHex, QString toHex, QString amountStr) override;
    QString transferShielded(QString fromHex, QString toKeysJson, QString amountStr) override;
    QString transferShieldedOwned(QString fromHex, QString toHex, QString amountStr) override;
    QString transferDeshielded(QString fromHex, QString toHex, QString amountStr) override;
    QString bridgeWithdraw(QString fromHex, QString bedrockAccountPkHex, quint64 amount) override;
    void refreshVaultBalances() override;
    QString vaultClaim(QString fromHex, bool isPublic, QString amountStr) override;
    void retryWalletOpen() override;
    bool checkLabelAvailable(QString label) override;
    QString addLabel(QString label, QString accountIdHex, bool isPublic) override;

private slots:
    void syncNextChunk();

private:
    using VariantCompletion = std::function<void(QVariant, bool)>;

    void fetchAndUpdateBlockHeights();
    void startChunkedSync();
    QVariantList buildEnrichedAccountList(const QVariantList& raw, bool* success);
    bool replaceAccountsFromCore();
    void invokeCoreAsync(
        const QString& method,
        const QVariantList& arguments,
        VariantCompletion completion
    );
    void refreshAccountsForStartup(WalletStartupFlow::Coordinator::RefreshCompletion completion);
    void enrichAccountsForStartup(
        QVariantList raw,
        int index,
        QVariantList enriched,
        WalletStartupFlow::Coordinator::RefreshCompletion completion
    );
    void enrichAccountDetailsForStartup(
        QVariantList raw,
        int index,
        QVariantList enriched,
        QVariantMap account,
        bool isPublic,
        WalletStartupFlow::Coordinator::RefreshCompletion completion
    );

    void updateBalances();
    QString getVaultBalance(const QString& accountIdHex);
    void refreshSequencerAddr();
    void saveWallet();
    void applyStartupResult(const WalletStartupFlow::Result& result);
    void finishOpeningSharedWallet();

    bool m_syncing = false;
    quint64 m_syncTarget = 0;
    static constexpr quint64 SYNC_CHUNK_SIZE = 100;

    LEZWalletAccountModel* m_accountModel;
    LEZAccountFilterModel* m_filteredAccountModel;
    LEZAccountFilterModel* m_privateAccountModel;
    LEZClaimableAccountFilterModel* m_claimableAccountModel;

    LogosAPI* m_logosAPI;
    LogosModules* m_logos;
    std::unique_ptr<WalletStartupFlow::Coordinator> m_startup;
};

#endif // LEZ_WALLET_BACKEND_H
