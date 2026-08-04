#ifndef WALLET_STARTUP_FLOW_H
#define WALLET_STARTUP_FLOW_H

#include <QString>

namespace WalletStartupFlow {

enum class Action {
    None,
    OpenDefault,
    RefreshAccounts,
};

struct Result {
    QString state;
    QString errorCode;
    QString errorMessage;
    Action action = Action::None;
};

Result fromStatusEnvelope(const QString& envelope);
Result fromOpenEnvelope(const QString& envelope);
Result coreUnavailable();
bool shouldRetryHandshake(const QString& version, int attempt, int maximumAttempts);

} // namespace WalletStartupFlow

#endif // WALLET_STARTUP_FLOW_H
