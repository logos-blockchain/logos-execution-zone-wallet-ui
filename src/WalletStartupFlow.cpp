#include "WalletStartupFlow.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>

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

    return {
        true,
        success.toBool(),
        state.toString(),
        errorCode.toString(),
    };
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

bool shouldRetryHandshake(const QString& version, const int attempt, const int maximumAttempts)
{
    return version.isEmpty() && attempt < maximumAttempts;
}

} // namespace WalletStartupFlow
