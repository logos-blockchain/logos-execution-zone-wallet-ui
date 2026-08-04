cmake_minimum_required(VERSION 3.14)
project(LEZWalletUIStartupTests LANGUAGES CXX)

include(LogosTest)

logos_test(
    NAME lez_wallet_ui_startup_tests
    MODULE_SOURCES
        ../src/WalletStartupFlow.cpp
    TEST_SOURCES
        main.cpp
        test_wallet_startup.cpp
    EXTRA_INCLUDES
        ../src
)
