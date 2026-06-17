#pragma once

#include <QAbstractListModel>
#include <QVariant>
#include <QString>

struct LEZWalletAccountEntry {
    QString name;
    QString accountId;
    QString balance;
    bool isPublic = true;
};

class LEZWalletAccountModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        AccountIdRole,
        BalanceRole,
        IsPublicRole
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
