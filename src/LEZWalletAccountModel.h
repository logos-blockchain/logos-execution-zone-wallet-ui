#pragma once

#include <QAbstractListModel>
#include <QVariant>
#include <QString>

// Public accounts have no key group, so they all share the PublicSectionKey section.
// Private accounts section by NPK (the key group they belong to) — see
// LEZWalletBackend::buildEnrichedAccountList, which attaches "npk"/"keys_json" per entry.
inline const QString PublicSectionKey = QStringLiteral("public");

struct LEZWalletAccountEntry {
    QString name;
    QString accountId;
    QString balance;
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
    int count() const { return m_entries.size(); }

signals:
    void countChanged();

private:
    QVector<LEZWalletAccountEntry> m_entries;
};
