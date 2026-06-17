#pragma once

#include <QSortFilterProxyModel>
#include "LEZWalletAccountModel.h"

// Filters the account model down to accounts with a nonzero claimable vault balance
// (see LEZWalletBackend::refreshVaultBalances), for the Bridge tab's Claim Deposit list.
class LEZClaimableAccountFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit LEZClaimableAccountFilterModel(QObject* parent = nullptr);

    int count() const { return rowCount(); }

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

signals:
    void countChanged();
};
