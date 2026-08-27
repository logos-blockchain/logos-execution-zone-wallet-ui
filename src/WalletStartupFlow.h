#ifndef WALLET_STARTUP_FLOW_H
#define WALLET_STARTUP_FLOW_H

#include <functional>
#include <memory>
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
Result incompatibleCore();
Result accountRefreshFailed();
bool shouldRetryHandshake(const QString& version, int attempt, int maximumAttempts);
bool isCompatibleCoreVersion(const QString& version);

class Coordinator {
public:
    using CallCompletion = std::function<void(QString, bool)>;
    using RefreshCompletion = std::function<void(bool)>;
    using Task = std::function<void()>;

    struct Hooks {
        std::function<void(const QString&, CallCompletion)> invoke;
        std::function<void(int, Task)> schedule;
        std::function<void(RefreshCompletion)> refreshAccounts;
        std::function<void(const Result&)> publish;
    };

    explicit Coordinator(Hooks hooks, int maximumRetries = 100, int retryDelayMs = 50);

    void start();
    void retry();
    bool callInFlight() const { return m_callInFlight; }

private:
    void startNewCycle();
    void requestVersion(quint64 generation, int attempt);
    void requestStatus(quint64 generation);
    void requestOpen(quint64 generation);
    void requestAccountRefresh(quint64 generation);
    void invoke(
        quint64 generation,
        const QString& method,
        std::function<void(QString, bool)> completion
    );
    bool finishCallOrRestart(quint64 generation);

    Hooks m_hooks;
    int m_maximumRetries;
    int m_retryDelayMs;
    quint64 m_generation = 0;
    bool m_callInFlight = false;
    bool m_restartPending = false;
    std::shared_ptr<int> m_lifetime = std::make_shared<int>(0);
};

} // namespace WalletStartupFlow

#endif // WALLET_STARTUP_FLOW_H
