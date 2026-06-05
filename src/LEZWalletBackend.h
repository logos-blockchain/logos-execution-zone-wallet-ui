#ifndef LEZ_WALLET_BACKEND_H
#define LEZ_WALLET_BACKEND_H

#include <QObject>
#include <QString>

#include "rep_LEZWalletBackend_source.h"

#include "LEZAccountFilterModel.h"
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

public:
    explicit LEZWalletBackend(LogosAPI* logosAPI = nullptr, QObject* parent = nullptr);
    ~LEZWalletBackend() override;

    LEZWalletAccountModel* accountModel() const { return m_accountModel; }
    LEZAccountFilterModel* filteredAccountModel() const { return m_filteredAccountModel; }

public slots:
    // Overrides of the pure-virtual slots generated from the .rep.
    QString createAccountPublic() override;
    QString createAccountPrivate() override;
    void refreshAccounts() override;
    QString getBalance(QString accountIdHex, bool isPublic) override;
    void refreshBalances() override;
    QString getPublicAccountKey(QString accountIdHex) override;
    QString getPrivateAccountKeys(QString accountIdHex) override;
    bool syncToBlock(quint64 blockId) override;
    QString transferPublic(QString fromHex, QString toHex, QString amountStr) override;
    QString transferPrivate(QString fromHex, QString toHex, QString amountStr) override;
    QString transferPrivateOwned(QString fromHex, QString toHex, QString amountStr) override;
    QString transferShielded(QString fromHex, QString toKeysJson, QString amountStr) override;
    QString transferShieldedOwned(QString fromHex, QString toHex, QString amountStr) override;
    bool createNew(QString configPath, QString storagePath, QString password) override;
    void copyToClipboard(QString text) override;

private:
    void persistConfigPath(const QString& path);
    void persistStoragePath(const QString& path);
    void refreshBlockHeights();
    void refreshSequencerAddr();
    void saveWallet();
    void fetchAndUpdateBlockHeights();
    void openIfPathsConfigured();

    LEZWalletAccountModel* m_accountModel;
    LEZAccountFilterModel* m_filteredAccountModel;

    LogosAPI* m_logosAPI;
    LogosModules* m_logos;
};

#endif // LEZ_WALLET_BACKEND_H
