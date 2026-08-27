#ifndef LEZ_WALLET_BACKEND_H
#define LEZ_WALLET_BACKEND_H

#include <QObject>
#include <QString>

#include "rep_LEZWalletBackend_source.h"

#include "LEZAccountFilterModel.h"
#include "LEZClaimableAccountFilterModel.h"
#include "LEZWalletAccountModel.h"

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
    QString createNew(QString password, QString sequencerAddr) override;
    QString openExisting(QString configPath, QString storagePath) override;
    void copyToClipboard(QString text) override;
    bool checkLabelAvailable(QString label) override;
    QString addLabel(QString label, QString accountIdHex, bool isPublic) override;

private slots:
    void syncNextChunk();

private:
    void persistConfigPath(const QString& path);
    void persistStoragePath(const QString& path);
    void clearSavedPaths();
    void reportNotice(const QString& message);
    QString defaultWalletDir();
    void applySequencerAddrToConfig(const QString& configPath, const QString& sequencerAddr);
    qint64 openWalletAt(const QString& localConfigPath, const QString& localStoragePath);
    void fetchAndUpdateBlockHeights();
    void startChunkedSync();
    QVariantList buildEnrichedAccountList();

    void updateBalances();
    QString getVaultBalance(const QString& accountIdHex);
    void refreshSequencerAddr();
    void saveWallet();
    void openIfPathsConfigured(int attempt = 0);
    void finishOpeningWallet();
    void finishStartup();

    bool m_syncing = false;
    quint64 m_syncTarget = 0;
    static constexpr quint64 SYNC_CHUNK_SIZE = 100;

    LEZWalletAccountModel* m_accountModel;
    LEZAccountFilterModel* m_filteredAccountModel;
    LEZAccountFilterModel* m_privateAccountModel;
    LEZClaimableAccountFilterModel* m_claimableAccountModel;

    LogosAPI* m_logosAPI;
    LogosModules* m_logos;
};

#endif // LEZ_WALLET_BACKEND_H
