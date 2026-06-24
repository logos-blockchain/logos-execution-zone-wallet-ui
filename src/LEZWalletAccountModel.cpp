#include "LEZWalletAccountModel.h"
#include <QJsonObject>

LEZWalletAccountModel::LEZWalletAccountModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

int LEZWalletAccountModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_entries.size();
}

QVariant LEZWalletAccountModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return QVariant();

    const LEZWalletAccountEntry& e = m_entries.at(index.row());
    switch (role) {
    case NameRole:    return e.name;
    case AccountIdRole:  return e.accountId;
    case BalanceRole: return e.balance;
    case IsPublicRole: return e.isPublic;
    default:          return QVariant();
    }
}

QHash<int, QByteArray> LEZWalletAccountModel::roleNames() const
{
    return {
        { NameRole,    "name"    },
        { AccountIdRole, "accountId" },
        { BalanceRole, "balance" },
        { IsPublicRole, "isPublic" }
    };
}

void LEZWalletAccountModel::replaceFromJsonArray(const QJsonArray& arr)
{
    beginResetModel();
    int oldCount = m_entries.size();
    m_entries.clear();
    for (const QJsonValue& v : arr) {
        LEZWalletAccountEntry e;
        e.balance = QString();
        if (v.isObject()) {
            const QJsonObject obj = v.toObject();
            e.accountId = obj.value(QStringLiteral("account_id")).toString();
            e.isPublic = obj.value(QStringLiteral("is_public")).toBool(true);
        } else {
            e.accountId = v.toString();
            e.isPublic = true;
        }
        e.name = QString();
        m_entries.append(e);
    }
    endResetModel();
    if (oldCount != m_entries.size())
        emit countChanged();
}

void LEZWalletAccountModel::replaceFromVariantList(const QVariantList& list)
{
    beginResetModel();
    int oldCount = m_entries.size();
    m_entries.clear();
    for (const QVariant& v : list) {
        LEZWalletAccountEntry e;
        e.balance = QString();
        if (v.canConvert<QVariantMap>()) {
            const QVariantMap obj = v.toMap();
            e.accountId = obj.value(QStringLiteral("account_id")).toString();
            e.isPublic = obj.value(QStringLiteral("is_public"), true).toBool();
        } else {
            e.accountId = v.toString();
            e.isPublic = true;
        }
        e.name = QString();
        m_entries.append(e);
    }
    endResetModel();
    if (oldCount != m_entries.size())
        emit countChanged();
}

void LEZWalletAccountModel::setBalanceByAccountId(const QString& accountId, const QString& balance)
{
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).accountId == accountId) {
            if (m_entries.at(i).balance != balance) {
                m_entries[i].balance = balance;
                QModelIndex idx = index(i, 0);
                emit dataChanged(idx, idx, { BalanceRole });
            }
            return;
        }
    }
}
