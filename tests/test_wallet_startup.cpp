#include <logos_test.h>

#include <filesystem>
#include <fstream>
#include <deque>
#include <functional>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

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

struct PendingCall {
    QString method;
    WalletStartupFlow::Coordinator::CallCompletion completion;
};

struct StartupHarness {
    explicit StartupHarness(const int maximumRetries = 0)
    {
        WalletStartupFlow::Coordinator::Hooks hooks;
        hooks.invoke = [this](const QString& method,
                           WalletStartupFlow::Coordinator::CallCompletion completion) {
            calls.push_back({method, std::move(completion)});
        };
        hooks.schedule = [this](const int, WalletStartupFlow::Coordinator::Task task) {
            scheduled.push_back(std::move(task));
        };
        hooks.refreshAccounts = [this](
                                    WalletStartupFlow::Coordinator::RefreshCompletion completion) {
            refresh = std::move(completion);
        };
        hooks.publish = [this](const WalletStartupFlow::Result& result) {
            published.push_back(result);
        };
        coordinator = std::make_unique<WalletStartupFlow::Coordinator>(
            std::move(hooks), maximumRetries, 1);
    }

    void completeCall(const QString& value, const bool ok)
    {
        auto completion = std::move(calls.front().completion);
        calls.pop_front();
        completion(value, ok);
    }

    void runScheduled()
    {
        auto task = std::move(scheduled.front());
        scheduled.pop_front();
        task();
    }

    std::deque<PendingCall> calls;
    std::deque<WalletStartupFlow::Coordinator::Task> scheduled;
    WalletStartupFlow::Coordinator::RefreshCompletion refresh;
    std::vector<WalletStartupFlow::Result> published;
    std::unique_ptr<WalletStartupFlow::Coordinator> coordinator;
};

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

LOGOS_TEST(core_version_must_be_an_exact_compatible_release)
{
    LOGOS_ASSERT_TRUE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("0.5.0")));
    LOGOS_ASSERT_TRUE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("0.5.9")));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("0.4.9")));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("1.0.0")));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("0.5")));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("0.5.0-dev")));
    LOGOS_ASSERT_FALSE(WalletStartupFlow::isCompatibleCoreVersion(QStringLiteral("not-a-version")));
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
    LOGOS_ASSERT_EQ(unknown.errorCode.toStdString(), std::string("malformed_response"));
    LOGOS_ASSERT_FALSE(unknown.errorMessage.contains(QStringLiteral("secret")));
}

LOGOS_TEST(contradictory_envelopes_are_rejected)
{
    for (const QString& raw : {
            QStringLiteral(R"({"success":true,"state":"open","profile":"default","error_code":"open_failed","error":"detail"})"),
            QStringLiteral(R"({"success":true,"state":"error","profile":"default","error_code":"","error":""})"),
            QStringLiteral(R"({"success":false,"state":"closed","profile":"default","error_code":"open_failed","error":"detail"})"),
            QStringLiteral(R"({"success":false,"state":"error","profile":"default","error_code":"","error":""})"),
            QStringLiteral(R"({"success":false,"state":"error","profile":"default","error_code":"unknown","error":"detail"})"),
        }) {
        const auto result = WalletStartupFlow::fromOpenEnvelope(raw);
        LOGOS_ASSERT_EQ(result.errorCode.toStdString(), std::string("malformed_response"));
        LOGOS_ASSERT_TRUE(result.action == WalletStartupFlow::Action::None);
    }

    const QString missing = QStringLiteral(
        R"({"success":false,"state":"error","profile":"default","error_code":"profile_not_found","error":"detail"})");
    LOGOS_ASSERT_EQ(
        WalletStartupFlow::fromStatusEnvelope(missing).errorCode.toStdString(),
        std::string("malformed_response"));
    LOGOS_ASSERT_EQ(
        WalletStartupFlow::fromOpenEnvelope(missing).state.toStdString(),
        std::string("missing"));
}

LOGOS_TEST(coordinator_runs_compatible_async_lifecycle_in_order)
{
    StartupHarness harness;
    harness.coordinator->start();
    LOGOS_ASSERT_EQ(harness.calls.front().method.toStdString(), std::string("version"));

    harness.completeCall(QStringLiteral("0.5.0"), true);
    LOGOS_ASSERT_EQ(harness.calls.front().method.toStdString(), std::string("wallet_status"));
    harness.completeCall(ClosedEnvelope, true);
    LOGOS_ASSERT_EQ(harness.calls.front().method.toStdString(), std::string("open_default"));
    harness.completeCall(OpenEnvelope, true);
    LOGOS_ASSERT_TRUE(static_cast<bool>(harness.refresh));

    auto refresh = std::move(harness.refresh);
    refresh(true);
    LOGOS_ASSERT_EQ(harness.published.back().state.toStdString(), std::string("open"));
}

LOGOS_TEST(coordinator_sanitizes_transport_and_refresh_failures)
{
    StartupHarness transportHarness;
    transportHarness.coordinator->start();
    transportHarness.completeCall(QStringLiteral("/Users/alice/private/wallet.json"), false);
    LOGOS_ASSERT_EQ(
        transportHarness.published.back().errorCode.toStdString(),
        std::string("core_unavailable"));
    LOGOS_ASSERT_FALSE(transportHarness.published.back().errorMessage.contains(QStringLiteral("alice")));

    StartupHarness refreshHarness;
    refreshHarness.coordinator->start();
    refreshHarness.completeCall(QStringLiteral("0.5.0"), true);
    refreshHarness.completeCall(OpenEnvelope, true);
    auto refresh = std::move(refreshHarness.refresh);
    refresh(false);
    LOGOS_ASSERT_EQ(
        refreshHarness.published.back().errorCode.toStdString(),
        std::string("account_refresh_failed"));
}

LOGOS_TEST(coordinator_bounds_warmup_retries)
{
    StartupHarness harness(1);
    harness.coordinator->start();
    harness.completeCall(QString(), false);
    LOGOS_ASSERT_EQ(harness.scheduled.size(), static_cast<std::size_t>(1));
    harness.runScheduled();
    LOGOS_ASSERT_EQ(harness.calls.size(), static_cast<std::size_t>(1));
    harness.completeCall(QString(), false);
    LOGOS_ASSERT_TRUE(harness.scheduled.empty());
    LOGOS_ASSERT_EQ(harness.published.back().errorCode.toStdString(), std::string("core_unavailable"));
}

LOGOS_TEST(retry_does_not_overlap_slow_calls_or_publish_stale_success)
{
    StartupHarness callHarness;
    callHarness.coordinator->start();
    callHarness.coordinator->retry();
    callHarness.coordinator->retry();
    LOGOS_ASSERT_EQ(callHarness.calls.size(), static_cast<std::size_t>(1));
    callHarness.completeCall(QStringLiteral("0.5.0"), true);
    LOGOS_ASSERT_EQ(callHarness.calls.size(), static_cast<std::size_t>(1));
    LOGOS_ASSERT_EQ(callHarness.calls.front().method.toStdString(), std::string("version"));

    StartupHarness refreshHarness;
    refreshHarness.coordinator->start();
    refreshHarness.completeCall(QStringLiteral("0.5.0"), true);
    refreshHarness.completeCall(OpenEnvelope, true);
    refreshHarness.coordinator->retry();
    LOGOS_ASSERT_TRUE(refreshHarness.calls.empty());
    auto staleRefresh = std::move(refreshHarness.refresh);
    staleRefresh(true);
    LOGOS_ASSERT_EQ(refreshHarness.calls.size(), static_cast<std::size_t>(1));
    LOGOS_ASSERT_EQ(refreshHarness.calls.front().method.toStdString(), std::string("version"));
    LOGOS_ASSERT_EQ(refreshHarness.published.back().state.toStdString(), std::string("closed"));
}

LOGOS_TEST(late_callbacks_are_safe_after_coordinator_destruction)
{
    std::deque<PendingCall> calls;
    {
        WalletStartupFlow::Coordinator::Hooks hooks;
        hooks.invoke = [&calls](const QString& method,
                           WalletStartupFlow::Coordinator::CallCompletion completion) {
            calls.push_back({method, std::move(completion)});
        };
        hooks.schedule = [](const int, WalletStartupFlow::Coordinator::Task) {};
        hooks.refreshAccounts = [](WalletStartupFlow::Coordinator::RefreshCompletion) {};
        hooks.publish = [](const WalletStartupFlow::Result&) {};
        auto coordinator = std::make_unique<WalletStartupFlow::Coordinator>(std::move(hooks));
        coordinator->start();
    }

    LOGOS_ASSERT_EQ(calls.size(), static_cast<std::size_t>(1));
    auto lateCompletion = std::move(calls.front().completion);
    lateCompletion(QStringLiteral("0.5.0"), true);
    LOGOS_ASSERT_EQ(calls.size(), static_cast<std::size_t>(1));
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

LOGOS_TEST(startup_uses_async_error_channels_and_release_versions_are_aligned)
{
    const auto root = repositoryRoot();
    const std::string backend = textOf(root / "src/LEZWalletBackend.cpp");
    const std::string plugin = textOf(root / "src/LEZWalletPlugin.h");
    const std::string metadata = textOf(root / "metadata.json");

    LOGOS_ASSERT_TRUE(backend.find("invokeRemoteMethodAsync") != std::string::npos);
    LOGOS_ASSERT_TRUE(backend.find("AsyncResultErrorCallback") != std::string::npos);
    LOGOS_ASSERT_TRUE(backend.find("lez_core.version()") == std::string::npos);
    LOGOS_ASSERT_TRUE(backend.find("lez_core.wallet_status()") == std::string::npos);
    LOGOS_ASSERT_TRUE(backend.find("lez_core.open_default()") == std::string::npos);
    LOGOS_ASSERT_TRUE(plugin.find("1.2.0") != std::string::npos);
    LOGOS_ASSERT_TRUE(metadata.find("\"version\": \"1.2.0\"") != std::string::npos);
}

LOGOS_TEST(initial_account_enrichment_is_async_and_context_guarded)
{
    const std::string backend = textOf(repositoryRoot() / "src/LEZWalletBackend.cpp");
    const auto start = backend.find("void LEZWalletBackend::refreshAccountsForStartup");
    const auto end = backend.find("void LEZWalletBackend::finishOpeningSharedWallet");
    LOGOS_ASSERT_TRUE(start != std::string::npos);
    LOGOS_ASSERT_TRUE(end != std::string::npos);
    const std::string startupRefresh = backend.substr(start, end - start);

    for (const std::string& method : {
            "list_accounts",
            "get_private_account_keys",
            "get_account_public",
            "get_account_private",
            "get_all_labels_for_account",
        }) {
        LOGOS_ASSERT_TRUE(startupRefresh.find(method) != std::string::npos);
    }
    LOGOS_ASSERT_TRUE(startupRefresh.find("invokeCoreAsync") != std::string::npos);
    LOGOS_ASSERT_TRUE(startupRefresh.find("m_logos->lez_core") == std::string::npos);
    LOGOS_ASSERT_TRUE(backend.find("QPointer<LEZWalletBackend>") != std::string::npos);
}
