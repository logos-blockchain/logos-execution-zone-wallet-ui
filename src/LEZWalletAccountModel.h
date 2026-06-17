#pragma once

#include <QAbstractListModel>
#include <QVariant>
#include <QString>
#include <QVariantList>

// Public accounts have no key group, so they all share the PublicSectionKey section.
// Private accounts section by NPK (the key group they belong to) — see
// LEZWalletBackend::buildEnrichedAccountList, which attaches "npk"/"keys_json" per entry.
inline const QString PublicSectionKey = QStringLiteral("public");

struct LEZWalletAccountEntry {
    QString name;
    QString accountId;
    QString balance;
    QString vaultBalance; // claimable balance held in this account's bridge vault PDA
    bool isPublic = true;
    QString sectionKey;
    QString keysJson; // {nullifier_public_key, viewing_public_key} shared by the whole section; private only
    bool isFirstInGroup = false; // QML renders the section header above rows where this is true
};

// Note: this model is exposed to QML via Qt Remote Objects model replication (see
// logos.model() in ExecutionZoneWalletView.qml), which only replicates roles — not
// arbitrary Q_PROPERTYs. Anything QML needs must be a role on the row, not a property
// on the model itself.
class LEZWalletAccountModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        AccountIdRole,
        BalanceRole,
        VaultBalanceRole,
        IsPublicRole,
        SectionKeyRole,
        KeysJsonRole,
        IsFirstInGroupRole
    };
    Q_ENUM(Role)

    explicit LEZWalletAccountModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void replaceFromVariantList(const QVariantList& list);
    void setBalanceByAccountId(const QString& accountId, const QString& balance);
    void setVaultBalanceByAccountId(const QString& accountId, const QString& vaultBalance);
    int count() const { return m_entries.size(); }

    // Authoritative isPublic lookup by account ID — used to validate/derive the flag
    // server-side instead of trusting a caller-supplied value, since this model is the
    // source of truth for which accounts the wallet actually owns. Falls back to
    // `defaultValue` if the account isn't found.
    bool isPublicAccount(const QString& accountId, bool defaultValue = true) const;

signals:
    void countChanged();

private:
    QVector<LEZWalletAccountEntry> m_entries;
};
