#pragma once

#include <QSortFilterProxyModel>
#include "LEZWalletAccountModel.h"

class LEZAccountFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(bool filterByPublic READ filterByPublic WRITE setFilterByPublic NOTIFY filterByPublicChanged)
    Q_PROPERTY(bool onlyInitialized READ onlyInitialized WRITE setOnlyInitialized NOTIFY onlyInitializedChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit LEZAccountFilterModel(QObject* parent = nullptr);

    bool filterByPublic() const { return m_filterByPublic; }
    void setFilterByPublic(bool value);

    // When true, uninitialized accounts are excluded. Used for the account-picker
    // combo boxes (transfer/withdraw "from"/"to" fields) where an uninitialized
    // account can't yet be a valid sender or recipient — as opposed to AccountsPanel's
    // unfiltered accountModel, which must keep showing them so the user can initialize.
    bool onlyInitialized() const { return m_onlyInitialized; }
    void setOnlyInitialized(bool value);

    int count() const { return rowCount(); }

    Q_INVOKABLE int rowForAddress(const QString& address) const;

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

signals:
    void filterByPublicChanged();
    void onlyInitializedChanged();
    void countChanged();

private:
    bool m_filterByPublic = true;
    bool m_onlyInitialized = false;
};
