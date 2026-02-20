# Common build configuration shared across all packages
{ pkgs, logosSdk, logosLiblogos }:

{
  pname = "logos-execution-zone-wallet-ui";
  version = "1.0.0";

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.qt6.wrapQtAppsHook
  ];

  buildInputs = [
    pkgs.qt6.qtbase
    pkgs.qt6.qtremoteobjects
    pkgs.zstd
    pkgs.krb5
    pkgs.abseil-cpp
  ];

  cmakeFlags = [
    "-GNinja"
    "-DLOGOS_CPP_SDK_ROOT=${logosSdk}"
    "-DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}"
  ];

  env = {
    LOGOS_LIBLOGOS_ROOT = "${logosLiblogos}";
  };

  meta = with pkgs.lib; {
    description = "Logos Execution Zone Wallet UI - A Qt UI plugin for Logos Execution Zone Wallet Module";
    platforms = platforms.unix ++ platforms.windows;
  };
}
