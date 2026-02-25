# Builds the logos-execution-zone-wallet-ui-app standalone application
{ pkgs, common, src, logosLiblogos, logosExecutionZoneModule, logosCapabilityModule, logosExecutionZoneWalletUI, logosDesignSystem, lgpm, logosCapabilityModuleLgx, logosExecutionZoneModuleLgx }:

pkgs.stdenv.mkDerivation rec {
  pname = "logos-execution-zone-wallet-ui-app";
  version = common.version;

  inherit src;
  inherit (common) buildInputs meta;

  nativeBuildInputs = common.nativeBuildInputs ++ [ pkgs.patchelf pkgs.removeReferencesTo ];

  qtLibPath = pkgs.lib.makeLibraryPath (
    [
      pkgs.qt6.qtbase
      pkgs.qt6.qtremoteobjects
      pkgs.zstd
      pkgs.krb5
      pkgs.zlib
      pkgs.glib
      pkgs.stdenv.cc.cc
      pkgs.freetype
      pkgs.fontconfig
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.libglvnd
      pkgs.mesa.drivers
      pkgs.xorg.libX11
      pkgs.xorg.libXext
      pkgs.xorg.libXrender
      pkgs.xorg.libXrandr
      pkgs.xorg.libXcursor
      pkgs.xorg.libXi
      pkgs.xorg.libXfixes
      pkgs.xorg.libxcb
    ]
  );
  qtPluginPath = "${pkgs.qt6.qtbase}/lib/qt-6/plugins";
  qmlImportPath = "${placeholder "out"}/lib:${pkgs.qt6.qtbase}/lib/qt-6/qml";

  dontWrapQtApps = false;
  dontStrip = true;

  qtWrapperArgs = [
    "--prefix" "LD_LIBRARY_PATH" ":" qtLibPath
    "--prefix" "QT_PLUGIN_PATH" ":" qtPluginPath
    "--prefix" "QML2_IMPORT_PATH" ":" qmlImportPath
  ];

  preConfigure = ''
    runHook prePreConfigure
    export MACOSX_DEPLOYMENT_TARGET=12.0
    runHook postPreConfigure
  '';

  preFixup = ''
    runHook prePreFixup

    export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins"
    export QML_IMPORT_PATH="${pkgs.qt6.qtbase}/lib/qt-6/qml"

    find $out -type f -executable -exec sh -c '
      if file "$1" | grep -q "ELF.*executable"; then
        if patchelf --print-rpath "$1" 2>/dev/null | grep -q "/build/"; then
          echo "Cleaning RPATH for $1"
          patchelf --remove-rpath "$1" 2>/dev/null || true
        fi
        if echo "$1" | grep -q "/logos-execution-zone-wallet-ui-app$"; then
          echo "Setting RPATH for $1"
          patchelf --set-rpath "$out/lib" "$1" 2>/dev/null || true
        fi
      fi
    ' _ {} \;

    find $out -name "*.so" -exec sh -c '
      if patchelf --print-rpath "$1" 2>/dev/null | grep -q "/build/"; then
        echo "Cleaning RPATH for $1"
        patchelf --remove-rpath "$1" 2>/dev/null || true
      fi
    ' _ {} \;

    runHook prePostFixup
  '';

  configurePhase = ''
    runHook preConfigure

    echo "Configuring logos-execution-zone-wallet-ui-app..."

    test -d "${logosLiblogos}" || (echo "liblogos not found" && exit 1)
    test -d "${logosExecutionZoneModule}" || (echo "execution-zone-module not found" && exit 1)
    test -d "${logosCapabilityModule}" || (echo "capability-module not found" && exit 1)
    test -d "${logosExecutionZoneWalletUI}" || (echo "execution-zone-wallet-ui not found" && exit 1)
    test -d "${logosDesignSystem}" || (echo "logos-design-system not found" && exit 1)

    cmake -S app -B build \
      -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
      -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=FALSE \
      -DCMAKE_INSTALL_RPATH="" \
      -DCMAKE_SKIP_BUILD_RPATH=TRUE \
      -DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    cmake --build build
    echo "logos-execution-zone-wallet-ui-app built successfully!"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/modules

    if [ -f "build/bin/logos-execution-zone-wallet-ui-app" ]; then
      cp build/bin/logos-execution-zone-wallet-ui-app "$out/bin/"
      echo "Installed logos-execution-zone-wallet-ui-app binary"
    fi

    if [ -f "${logosLiblogos}/bin/logoscore" ]; then
      cp -L "${logosLiblogos}/bin/logoscore" "$out/bin/"
      echo "Installed logoscore binary"
    fi
    if [ -f "${logosLiblogos}/bin/logos_host" ]; then
      cp -L "${logosLiblogos}/bin/logos_host" "$out/bin/"
      echo "Installed logos_host binary"
    fi

    if ls "${logosLiblogos}/lib/"liblogos_core.* >/dev/null 2>&1; then
      cp -L "${logosLiblogos}/lib/"liblogos_core.* "$out/lib/" || true
    fi

    OS_EXT="so"
    case "$(uname -s)" in
      Darwin) OS_EXT="dylib";;
      Linux) OS_EXT="so";;
      MINGW*|MSYS*|CYGWIN*) OS_EXT="dll";;
    esac

    for lgxFile in ${logosCapabilityModuleLgx}/*.lgx; do
      echo "Installing $lgxFile via lgpm..."
      ${lgpm}/bin/lgpm --modules-dir "$out/modules" install --file "$lgxFile"
    done
    for lgxFile in ${logosExecutionZoneModuleLgx}/*.lgx; do
      echo "Installing $lgxFile via lgpm..."
      ${lgpm}/bin/lgpm --modules-dir "$out/modules" install --file "$lgxFile"
    done

    if [ -f "${logosExecutionZoneWalletUI}/lib/logos_execution_zone_wallet_ui.$OS_EXT" ]; then
      cp -L "${logosExecutionZoneWalletUI}/lib/logos_execution_zone_wallet_ui.$OS_EXT" "$out/"
    fi

    if [ -d "${logosDesignSystem}/lib/Logos/Theme" ]; then
      mkdir -p "$out/lib/Logos"
      cp -R "${logosDesignSystem}/lib/Logos/Theme" "$out/lib/Logos/"
      echo "Copied Logos.Theme to lib/Logos/Theme/"
    fi
    if [ -d "${logosDesignSystem}/lib/Logos/Controls" ]; then
      mkdir -p "$out/lib/Logos"
      cp -R "${logosDesignSystem}/lib/Logos/Controls" "$out/lib/Logos/"
      echo "Copied Logos.Controls to lib/Logos/Controls/"
    fi

    cat > $out/README.txt <<EOF
Logos Execution Zone Wallet UI App
==================================
liblogos: ${logosLiblogos}
execution-zone-module: ${logosExecutionZoneModule}
capability-module: ${logosCapabilityModule}
execution-zone-wallet-ui: ${logosExecutionZoneWalletUI}
design-system: ${logosDesignSystem}

Layout:
  bin/logos-execution-zone-wallet-ui-app
  lib/
  modules/
  logos_execution_zone_wallet_ui.$OS_EXT
EOF

    runHook postInstall
  '';
}
