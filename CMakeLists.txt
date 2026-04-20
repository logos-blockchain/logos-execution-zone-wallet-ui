cmake_minimum_required(VERSION 3.14)
project(LEZWalletPlugin LANGUAGES CXX)

if(DEFINED ENV{LOGOS_MODULE_BUILDER_ROOT})
    include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)
else()
    message(FATAL_ERROR "LogosModule.cmake not found. Set LOGOS_MODULE_BUILDER_ROOT.")
endif()

logos_module(
    NAME lez_wallet_ui
    REP_FILE src/LEZWalletBackend.rep
    SOURCES
        src/LEZWalletPluginInterface.h
        src/LEZWalletPlugin.h
        src/LEZWalletPlugin.cpp
        src/LEZWalletBackend.h
        src/LEZWalletBackend.cpp
        src/LEZWalletAccountModel.h
        src/LEZWalletAccountModel.cpp
        src/LEZAccountFilterModel.h
        src/LEZAccountFilterModel.cpp
    FIND_PACKAGES
        Qt6Gui
    LINK_LIBRARIES
        Qt6::Gui
)
