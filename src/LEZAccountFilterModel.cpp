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

bool LEZAccountFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    if (!sourceModel())
        return false;
    const QModelIndex idx = sourceModel()->index(sourceRow, 0, sourceParent);
    const bool isPublic = sourceModel()->data(idx, LEZWalletAccountModel::IsPublicRole).toBool();
    return isPublic == m_filterByPublic;
}

int LEZAccountFilterModel::rowForAddress(const QString& address) const
{
    for (int i = 0; i < rowCount(); ++i) {
        if (data(index(i, 0), LEZWalletAccountModel::AddressRole).toString() == address)
            return i;
    }
    return -1;
}
