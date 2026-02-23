#pragma once

#include <QAbstractListModel>
#include <QJsonArray>
#include <QString>

struct LEZWalletAccountEntry {
    QString name;
    QString address;
    QString balance;
    bool isPublic = true;
};

class LEZWalletAccountModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Role {
        NameRole = Qt::UserRole + 1,
        AddressRole,
        BalanceRole,
        IsPublicRole
    };
    Q_ENUM(Role)

    explicit LEZWalletAccountModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void replaceFromJsonArray(const QJsonArray& arr);
    void setBalanceByAddress(const QString& address, const QString& balance);
    int count() const { return m_entries.size(); }

signals:
    void countChanged();

private:
    QVector<LEZWalletAccountEntry> m_entries;
};
