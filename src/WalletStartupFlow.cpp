#include "WalletStartupFlow.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QVersionNumber>

#include <utility>

namespace {

struct Envelope {
    bool valid = false;
    bool success = false;
    QString state;
    QString errorCode;
};

Envelope parseEnvelope(const QString& raw)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(raw.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return {};

    const QJsonObject object = document.object();
    static const QSet<QString> allowedFields = {
        QStringLiteral("success"),
        QStringLiteral("state"),
        QStringLiteral("profile"),
        QStringLiteral("error_code"),
        QStringLiteral("error"),
    };
    for (auto it = object.constBegin(); it != object.constEnd(); ++it) {
        if (!allowedFields.contains(it.key()))
            return {};
    }

    const QJsonValue success = object.value(QStringLiteral("success"));
    const QJsonValue state = object.value(QStringLiteral("state"));
    const QJsonValue profile = object.value(QStringLiteral("profile"));
    const QJsonValue errorCode = object.value(QStringLiteral("error_code"));
    const QJsonValue error = object.value(QStringLiteral("error"));
    if (!success.isBool() || !state.isString() || profile.toString() != QStringLiteral("default")
        || !errorCode.isString() || !error.isString())
        return {};

    const Envelope envelope = {
        true,
        success.toBool(),
        state.toString(),
        errorCode.toString(),
    };

    static const QSet<QString> allowedErrorCodes = {
        QStringLiteral("context_unavailable"),
        QStringLiteral("profile_incomplete"),
        QStringLiteral("non_default_wallet_open"),
        QStringLiteral("wallet_already_open"),
        QStringLiteral("profile_not_found"),
        QStringLiteral("open_failed"),
        QStringLiteral("rollback_failed"),
    };
    if (envelope.success) {
        if ((envelope.state != QStringLiteral("open") && envelope.state != QStringLiteral("closed"))
            || !envelope.errorCode.isEmpty() || !error.toString().isEmpty())
            return {};
    } else if (envelope.state != QStringLiteral("error")
        || !allowedErrorCodes.contains(envelope.errorCode) || error.toString().isEmpty()) {
        return {};
    }

    return envelope;
}

WalletStartupFlow::Result malformedEnvelope()
{
    return {
        QStringLiteral("error"),
        QStringLiteral("malformed_response"),
        QStringLiteral("The shared wallet returned an invalid response. Try again."),
    };
}

QString sanitizedMessage(const QString& errorCode)
{
    if (errorCode == QStringLiteral("context_unavailable"))
        return QStringLiteral("Basecamp storage is not ready yet. Try again.");
    if (errorCode == QStringLiteral("profile_incomplete"))
        return QStringLiteral("The shared wallet profile is incomplete and cannot be opened safely.");
    if (errorCode == QStringLiteral("non_default_wallet_open")
        || errorCode == QStringLiteral("wallet_already_open"))
        return QStringLiteral("Another wallet profile is open. Close it, then try again.");
    if (errorCode == QStringLiteral("open_failed"))
        return QStringLiteral("The shared wallet could not be opened. Try again.");
    if (errorCode == QStringLiteral("rollback_failed"))
        return QStringLiteral("The shared wallet needs manual recovery before it can be opened.");
    return QStringLiteral("The shared wallet could not be opened. Try again.");
}

QString sanitizedCode(const QString& errorCode)
{
    static const QSet<QString> allowedCodes = {
        QStringLiteral("context_unavailable"),
        QStringLiteral("profile_incomplete"),
        QStringLiteral("non_default_wallet_open"),
        QStringLiteral("wallet_already_open"),
        QStringLiteral("open_failed"),
        QStringLiteral("rollback_failed"),
    };
    return allowedCodes.contains(errorCode) ? errorCode : QStringLiteral("wallet_error");
}

WalletStartupFlow::Result envelopeError(const Envelope& envelope)
{
    const QString code = sanitizedCode(envelope.errorCode);
    return {
        QStringLiteral("error"),
        code,
        sanitizedMessage(code),
    };
}

} // namespace

namespace WalletStartupFlow {

Result fromStatusEnvelope(const QString& raw)
{
    const Envelope envelope = parseEnvelope(raw);
    if (!envelope.valid)
        return malformedEnvelope();
    if (!envelope.success && envelope.errorCode == QStringLiteral("profile_not_found"))
        return malformedEnvelope();
    if (!envelope.success)
        return envelopeError(envelope);
    if (envelope.state == QStringLiteral("open"))
        return {QStringLiteral("open"), {}, {}, Action::RefreshAccounts};
    if (envelope.state == QStringLiteral("closed"))
        return {QStringLiteral("closed"), {}, {}, Action::OpenDefault};
    return malformedEnvelope();
}

Result fromOpenEnvelope(const QString& raw)
{
    const Envelope envelope = parseEnvelope(raw);
    if (!envelope.valid)
        return malformedEnvelope();
    if (envelope.success && envelope.state == QStringLiteral("open"))
        return {QStringLiteral("open"), {}, {}, Action::RefreshAccounts};
    if (!envelope.success && envelope.errorCode == QStringLiteral("profile_not_found"))
        return {
            QStringLiteral("missing"),
            QStringLiteral("profile_not_found"),
            QStringLiteral("No shared wallet profile exists in this Basecamp profile."),
        };
    if (!envelope.success)
        return envelopeError(envelope);
    return malformedEnvelope();
}

Result coreUnavailable()
{
    return {
        QStringLiteral("error"),
        QStringLiteral("core_unavailable"),
        QStringLiteral("The shared wallet service is unavailable. Try again."),
    };
}

Result incompatibleCore()
{
    return {
        QStringLiteral("error"),
        QStringLiteral("incompatible_core"),
        QStringLiteral("This wallet requires LEZ Core 0.5.x. Update the installed module, then try again."),
    };
}

Result accountRefreshFailed()
{
    return {
        QStringLiteral("error"),
        QStringLiteral("account_refresh_failed"),
        QStringLiteral("The shared wallet opened, but its accounts could not be loaded. Try again."),
    };
}

bool shouldRetryHandshake(const QString& version, const int attempt, const int maximumAttempts)
{
    return version.isEmpty() && attempt < maximumAttempts;
}

bool isCompatibleCoreVersion(const QString& version)
{
    qsizetype suffixIndex = 0;
    const QVersionNumber parsed = QVersionNumber::fromString(version, &suffixIndex);
    return !parsed.isNull() && parsed.segmentCount() == 3 && suffixIndex == version.size()
        && parsed.majorVersion() == 0 && parsed.minorVersion() == 5;
}

Coordinator::Coordinator(Hooks hooks, const int maximumRetries, const int retryDelayMs)
    : m_hooks(std::move(hooks)),
      m_maximumRetries(maximumRetries),
      m_retryDelayMs(retryDelayMs)
{
}

void Coordinator::start()
{
    if (m_callInFlight) {
        m_restartPending = true;
        m_hooks.publish({QStringLiteral("closed"), {}, {}});
        return;
    }
    startNewCycle();
}

void Coordinator::retry()
{
    start();
}

void Coordinator::startNewCycle()
{
    m_restartPending = false;
    const quint64 generation = ++m_generation;
    m_hooks.publish({QStringLiteral("closed"), {}, {}});
    requestVersion(generation, 0);
}

void Coordinator::requestVersion(const quint64 generation, const int attempt)
{
    invoke(generation, QStringLiteral("version"),
        [this, generation, attempt](const QString& version, const bool transportOk) {
            if (!finishCallOrRestart(generation))
                return;
            if (!transportOk || version.isEmpty()) {
                if (attempt < m_maximumRetries) {
                    const std::weak_ptr<int> lifetime = m_lifetime;
                    m_hooks.schedule(m_retryDelayMs, [this, lifetime, generation, attempt]() {
                        if (lifetime.expired())
                            return;
                        if (generation == m_generation)
                            requestVersion(generation, attempt + 1);
                    });
                } else {
                    m_hooks.publish(coreUnavailable());
                }
                return;
            }
            if (!isCompatibleCoreVersion(version)) {
                m_hooks.publish(incompatibleCore());
                return;
            }
            requestStatus(generation);
        });
}

void Coordinator::requestStatus(const quint64 generation)
{
    invoke(generation, QStringLiteral("wallet_status"),
        [this, generation](const QString& envelope, const bool transportOk) {
            if (!finishCallOrRestart(generation))
                return;
            if (!transportOk) {
                m_hooks.publish(coreUnavailable());
                return;
            }
            const Result status = fromStatusEnvelope(envelope);
            if (status.action == Action::OpenDefault) {
                m_hooks.publish(status);
                requestOpen(generation);
            } else if (status.action == Action::RefreshAccounts) {
                requestAccountRefresh(generation);
            } else {
                m_hooks.publish(status);
            }
        });
}

void Coordinator::requestOpen(const quint64 generation)
{
    invoke(generation, QStringLiteral("open_default"),
        [this, generation](const QString& envelope, const bool transportOk) {
            if (!finishCallOrRestart(generation))
                return;
            if (!transportOk) {
                m_hooks.publish(coreUnavailable());
                return;
            }
            const Result opened = fromOpenEnvelope(envelope);
            if (opened.action == Action::RefreshAccounts)
                requestAccountRefresh(generation);
            else
                m_hooks.publish(opened);
        });
}

void Coordinator::requestAccountRefresh(const quint64 generation)
{
    m_callInFlight = true;
    const std::weak_ptr<int> lifetime = m_lifetime;
    m_hooks.refreshAccounts([this, lifetime, generation](const bool success) {
        if (lifetime.expired())
            return;
        if (!finishCallOrRestart(generation))
            return;
        m_hooks.publish(success
            ? Result{QStringLiteral("open"), {}, {}}
            : accountRefreshFailed());
    });
}

void Coordinator::invoke(
    const quint64 generation,
    const QString& method,
    std::function<void(QString, bool)> completion
)
{
    m_callInFlight = true;
    const std::weak_ptr<int> lifetime = m_lifetime;
    m_hooks.invoke(method,
        [this, lifetime, generation, completion = std::move(completion)](
            QString value, const bool ok) {
            if (lifetime.expired())
                return;
            if (generation != m_generation)
                return;
            completion(std::move(value), ok);
        });
}

bool Coordinator::finishCallOrRestart(const quint64 generation)
{
    if (generation != m_generation)
        return false;
    m_callInFlight = false;
    if (!m_restartPending)
        return true;
    startNewCycle();
    return false;
}

} // namespace WalletStartupFlow
