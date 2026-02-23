#pragma once

#include <QObject>
#include <QString>
#include "LEZAccountFilterModel.h"
#include "LEZWalletAccountModel.h"
#include "logos_api.h"
#include "logos_api_client.h"

class QAbstractItemModel;

class LEZWalletBackend : public QObject {
    Q_OBJECT

public:
    Q_PROPERTY(bool isWalletOpen READ isWalletOpen NOTIFY isWalletOpenChanged)
    Q_PROPERTY(QString configPath READ configPath WRITE setConfigPath NOTIFY configPathChanged)
    Q_PROPERTY(QString storagePath READ storagePath WRITE setStoragePath NOTIFY storagePathChanged)
    Q_PROPERTY(LEZWalletAccountModel* accountModel READ accountModel NOTIFY accountModelChanged)
    Q_PROPERTY(LEZAccountFilterModel* filteredAccountModel READ filteredAccountModel NOTIFY filteredAccountModelChanged)
    Q_PROPERTY(quint64 lastSyncedBlock READ lastSyncedBlock NOTIFY lastSyncedBlockChanged)
    Q_PROPERTY(quint64 currentBlockHeight READ currentBlockHeight NOTIFY currentBlockHeightChanged)
    Q_PROPERTY(QString sequencerAddr READ sequencerAddr NOTIFY sequencerAddrChanged)

    explicit LEZWalletBackend(LogosAPI* logosAPI = nullptr, QObject* parent = nullptr);
    ~LEZWalletBackend();

    bool isWalletOpen() const { return m_isWalletOpen; }
    QString configPath() const { return m_configPath; }
    QString storagePath() const { return m_storagePath; }
    LEZWalletAccountModel* accountModel() const { return m_accountModel; }
    LEZAccountFilterModel* filteredAccountModel() const { return m_filteredAccountModel; }
    quint64 lastSyncedBlock() const { return m_lastSyncedBlock; }
    quint64 currentBlockHeight() const { return m_currentBlockHeight; }
    QString sequencerAddr() const { return m_sequencerAddr; }

    void setConfigPath(const QString& path);
    void setStoragePath(const QString& path);

    Q_INVOKABLE QString createAccountPublic();
    Q_INVOKABLE QString createAccountPrivate();
    Q_INVOKABLE void refreshAccounts();
    Q_INVOKABLE QString getBalance(const QString& accountIdHex, bool isPublic);
    Q_INVOKABLE void refreshBalances();
    Q_INVOKABLE QString getPublicAccountKey(const QString& accountIdHex);
    Q_INVOKABLE QString getPrivateAccountKeys(const QString& accountIdHex);
    Q_INVOKABLE bool syncToBlock(quint64 blockId);
    Q_INVOKABLE QString transferPublic(
        const QString& fromHex,
        const QString& toHex,
        const QString& amountLe16Hex);
    Q_INVOKABLE QString transferPrivate(
        const QString& fromHex,
        const QString& toKeysJson,
        const QString& amountLe16Hex);
    Q_INVOKABLE bool createNew(
        const QString& configPath,
        const QString& storagePath,
        const QString& password);
    Q_INVOKABLE int indexOfAddressInModel(QObject* model, const QString& address) const;

signals:
    void isWalletOpenChanged();
    void configPathChanged();
    void storagePathChanged();
    void accountModelChanged();
    void filteredAccountModelChanged();
    void lastSyncedBlockChanged();
    void currentBlockHeightChanged();
    void sequencerAddrChanged();

private:
    void setWalletOpen(bool open);
    void refreshBlockHeights();
    void refreshSequencerAddr();
    void saveWallet();

    bool m_isWalletOpen;
    QString m_configPath;
    QString m_storagePath;
    LEZWalletAccountModel* m_accountModel;
    LEZAccountFilterModel* m_filteredAccountModel;
    quint64 m_lastSyncedBlock;
    quint64 m_currentBlockHeight;
    QString m_sequencerAddr;

    LogosAPI* m_logosAPI;
    LogosAPIClient* m_walletClient;
};
