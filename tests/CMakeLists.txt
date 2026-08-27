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

# logos-test assertion macros include __FILE__ in failure messages. Normalize
# project paths so those diagnostics stay useful without embedding the ephemeral
# Nix build directory in the executable.
get_filename_component(TEST_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(
        lez_wallet_ui_startup_tests
        PRIVATE "-ffile-prefix-map=${TEST_SOURCE_ROOT}=."
    )
endif()

# Source-inspection tests consume a deterministic fixture tree beside the build
# binary. Do not compile the source checkout path into the executable: Nix build
# directories are ephemeral, and embedding them makes the test output vary across
# rebuilds. An installed test can use LEZ_WALLET_UI_TEST_FIXTURES to point at a
# source checkout instead.
set(TEST_FIXTURE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/fixtures")
set(TEST_FIXTURE_FILES
    metadata.json
    src/LEZWalletBackend.cpp
    src/LEZWalletBackend.rep
    src/LEZWalletPlugin.h
    src/qml/views/OnboardingView.qml
)

foreach(relative_path IN LISTS TEST_FIXTURE_FILES)
    get_filename_component(relative_directory "${relative_path}" DIRECTORY)
    file(MAKE_DIRECTORY "${TEST_FIXTURE_ROOT}/${relative_directory}")
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/../${relative_path}"
        "${TEST_FIXTURE_ROOT}/${relative_path}"
        COPYONLY
    )
endforeach()
