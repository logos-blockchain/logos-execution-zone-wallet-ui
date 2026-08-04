#include <logos_test.h>

#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>

#include "WalletStartupFlow.h"

namespace {

std::string textOf(const std::filesystem::path& path)
{
    std::ifstream input(path);
    std::ostringstream contents;
    contents << input.rdbuf();
    return contents.str();
}

std::filesystem::path repositoryRoot()
{
    return std::filesystem::path(__FILE__).parent_path().parent_path();
}

const QString OpenEnvelope = QStringLiteral(
    R"({"success":true,"state":"open","profile":"default","error_code":"","error":""})");
const QString ClosedEnvelope = QStringLiteral(
    R"({"success":true,"state":"closed","profile":"default","error_code":"","error":""})");

} // namespace

LOGOS_TEST(handshake_retries_only_within_budget)
{
    LOGOS_ASSERT_TRUE(WalletStartupFlow::shouldRetryHandshake(QString(), 0, 100));
    LOGOS_ASSERT_TRUE(WalletStartupFlow::shouldRetryHandshake(QString(), 99, 100));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::shouldRetryHandshake(QString(), 100, 100));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::shouldRetryHandshake(QStringLiteral("0.5.0"), 0, 100));

    const auto unavailable = WalletStartupFlow::coreUnavailable();
    LOGOS_ASSERT_EQ(unavailable.state.toStdString(), std::string("error"));
    LOGOS_ASSERT_EQ(unavailable.errorCode.toStdString(), std::string("core_unavailable"));
}

LOGOS_TEST(status_closed_requests_open_default)
{
    const auto result = WalletStartupFlow::fromStatusEnvelope(ClosedEnvelope);
    LOGOS_ASSERT_EQ(result.state.toStdString(), std::string("closed"));
    LOGOS_ASSERT_TRUE(result.action == WalletStartupFlow::Action::OpenDefault);
}

LOGOS_TEST(status_open_requests_account_refresh)
{
    const auto result = WalletStartupFlow::fromStatusEnvelope(OpenEnvelope);
    LOGOS_ASSERT_EQ(result.state.toStdString(), std::string("open"));
    LOGOS_ASSERT_TRUE(result.action == WalletStartupFlow::Action::RefreshAccounts);
}

LOGOS_TEST(open_default_transitions_to_open_or_missing)
{
    const auto opened = WalletStartupFlow::fromOpenEnvelope(OpenEnvelope);
    LOGOS_ASSERT_EQ(opened.state.toStdString(), std::string("open"));
    LOGOS_ASSERT_TRUE(opened.action == WalletStartupFlow::Action::RefreshAccounts);

    const auto missing = WalletStartupFlow::fromOpenEnvelope(QStringLiteral(
        R"({"success":false,"state":"error","profile":"default","error_code":"profile_not_found","error":"raw detail"})"));
    LOGOS_ASSERT_EQ(missing.state.toStdString(), std::string("missing"));
    LOGOS_ASSERT_EQ(missing.errorCode.toStdString(), std::string("profile_not_found"));
    LOGOS_ASSERT_FALSE(missing.errorMessage.contains(QStringLiteral("raw detail")));
}

LOGOS_TEST(error_envelopes_are_sanitized)
{
    const auto known = WalletStartupFlow::fromOpenEnvelope(QStringLiteral(
        R"({"success":false,"state":"error","profile":"default","error_code":"open_failed","error":"/Users/alice/private/wallet.json"})"));
    LOGOS_ASSERT_EQ(known.errorCode.toStdString(), std::string("open_failed"));
    LOGOS_ASSERT_FALSE(known.errorMessage.contains(QStringLiteral("alice")));

    const auto unknown = WalletStartupFlow::fromOpenEnvelope(QStringLiteral(
        R"({"success":false,"state":"error","profile":"default","error_code":"attacker-controlled","error":"secret"})"));
    LOGOS_ASSERT_EQ(unknown.errorCode.toStdString(), std::string("wallet_error"));
    LOGOS_ASSERT_FALSE(unknown.errorMessage.contains(QStringLiteral("secret")));
}

LOGOS_TEST(malformed_or_secret_bearing_envelopes_are_rejected)
{
    const auto malformed = WalletStartupFlow::fromStatusEnvelope(QStringLiteral("not-json"));
    LOGOS_ASSERT_EQ(malformed.errorCode.toStdString(), std::string("malformed_response"));

    const auto wrongTypes = WalletStartupFlow::fromStatusEnvelope(QStringLiteral(
        R"({"success":"yes","state":"open","profile":"default","error_code":"","error":""})"));
    LOGOS_ASSERT_EQ(wrongTypes.errorCode.toStdString(), std::string("malformed_response"));

    for (const QString& field : {
            QStringLiteral("mnemonic"),
            QStringLiteral("signing_key"),
            QStringLiteral("seed"),
            QStringLiteral("secret"),
            QStringLiteral("wallet_path"),
        }) {
        const QString raw = QStringLiteral(
            R"({"success":true,"state":"open","profile":"default","error_code":"","error":"","%1":"do not expose"})")
            .arg(field);
        const auto secretBearing = WalletStartupFlow::fromOpenEnvelope(raw);
        LOGOS_ASSERT_EQ(secretBearing.errorCode.toStdString(), std::string("malformed_response"));
        LOGOS_ASSERT_TRUE(secretBearing.action == WalletStartupFlow::Action::None);
    }
}

LOGOS_TEST(qml_exposes_all_sanitized_startup_states_and_retry)
{
    const std::string qml = textOf(repositoryRoot() / "src/qml/views/OnboardingView.qml");
    LOGOS_ASSERT_TRUE(qml.find("walletState === \"closed\"") != std::string::npos);
    LOGOS_ASSERT_TRUE(qml.find("walletState === \"missing\"") != std::string::npos);
    LOGOS_ASSERT_TRUE(qml.find("walletState === \"error\"") != std::string::npos);
    LOGOS_ASSERT_TRUE(qml.find("retryRequested") != std::string::npos);
    LOGOS_ASSERT_TRUE(qml.find("walletError") != std::string::npos);
}

LOGOS_TEST(normal_startup_surface_has_no_path_or_secret_persistence)
{
    const auto root = repositoryRoot();
    const std::string backend = textOf(root / "src/LEZWalletBackend.cpp");
    const std::string interface = textOf(root / "src/LEZWalletBackend.rep");
    const std::string onboarding = textOf(root / "src/qml/views/OnboardingView.qml");
    const std::string startupSurface = backend + interface + onboarding;

    LOGOS_ASSERT_TRUE(startupSurface.find("QSettings") == std::string::npos);
    LOGOS_ASSERT_TRUE(startupSurface.find("QClipboard") == std::string::npos);
    LOGOS_ASSERT_TRUE(startupSurface.find("configPath") == std::string::npos);
    LOGOS_ASSERT_TRUE(startupSurface.find("storagePath") == std::string::npos);
    LOGOS_ASSERT_TRUE(startupSurface.find("createNew") == std::string::npos);
    LOGOS_ASSERT_TRUE(startupSurface.find("create_default") == std::string::npos);
    LOGOS_ASSERT_TRUE(startupSurface.find("restore_default") == std::string::npos);
    LOGOS_ASSERT_TRUE(onboarding.find("TextInput.Password") == std::string::npos);
    LOGOS_ASSERT_TRUE(interface.find("copyToClipboard") == std::string::npos);
}
