#include "LEZAccountFilterModel.h"

LEZAccountFilterModel::LEZAccountFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &LEZAccountFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &LEZAccountFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &LEZAccountFilterModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &LEZAccountFilterModel::countChanged);
}

void LEZAccountFilterModel::setFilterByPublic(bool value)
{
    if (m_filterByPublic == value)
        return;
    m_filterByPublic = value;
    invalidateFilter();
    emit filterByPublicChanged();
    emit countChanged();
}

void LEZAccountFilterModel::setOnlyInitialized(bool value)
{
    if (m_onlyInitialized == value)
        return;
    m_onlyInitialized = value;
    invalidateFilter();
    emit onlyInitializedChanged();
    emit countChanged();
}

bool LEZAccountFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    if (!sourceModel())
        return false;
    const QModelIndex idx = sourceModel()->index(sourceRow, 0, sourceParent);
    const bool isPublic = sourceModel()->data(idx, LEZWalletAccountModel::IsPublicRole).toBool();
    if (isPublic != m_filterByPublic)
        return false;
    if (m_onlyInitialized && !sourceModel()->data(idx, LEZWalletAccountModel::IsInitializedRole).toBool())
        return false;
    return true;
}

int LEZAccountFilterModel::rowForAddress(const QString& address) const
{
    for (int i = 0; i < rowCount(); ++i) {
        if (data(index(i, 0), LEZWalletAccountModel::AccountIdRole).toString() == address)
            return i;
    }
    return -1;
}
