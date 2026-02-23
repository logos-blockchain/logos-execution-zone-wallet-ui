#pragma once

#include <QSortFilterProxyModel>
#include "LEZWalletAccountModel.h"

class LEZAccountFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(bool filterByPublic READ filterByPublic WRITE setFilterByPublic NOTIFY filterByPublicChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit LEZAccountFilterModel(QObject* parent = nullptr);

    bool filterByPublic() const { return m_filterByPublic; }
    void setFilterByPublic(bool value);

    int count() const { return rowCount(); }

    Q_INVOKABLE int rowForAddress(const QString& address) const;

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex& sourceParent) const override;

signals:
    void filterByPublicChanged();
    void countChanged();

private:
    bool m_filterByPublic = true;
};
