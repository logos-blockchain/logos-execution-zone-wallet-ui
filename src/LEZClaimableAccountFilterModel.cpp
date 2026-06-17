#include "LEZClaimableAccountFilterModel.h"

LEZClaimableAccountFilterModel::LEZClaimableAccountFilterModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &LEZClaimableAccountFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &LEZClaimableAccountFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &LEZClaimableAccountFilterModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &LEZClaimableAccountFilterModel::countChanged);
}

bool LEZClaimableAccountFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const
{
    if (!sourceModel())
        return false;
    const QModelIndex idx = sourceModel()->index(sourceRow, 0, sourceParent);
    const QString vaultBalance = sourceModel()->data(idx, LEZWalletAccountModel::VaultBalanceRole).toString();
    return !vaultBalance.isEmpty() && vaultBalance != QStringLiteral("0");
}
