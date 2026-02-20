# Builds the logos-execution-zone-wallet-ui library
{ pkgs, common, src, logosExecutionZoneModule }:

pkgs.stdenv.mkDerivation {
  pname = "${common.pname}-lib";
  version = common.version;

  inherit src;
  inherit (common) buildInputs cmakeFlags meta env;
  nativeBuildInputs = common.nativeBuildInputs;

  dontWrapQtApps = true;

  configurePhase = ''
    runHook preConfigure
    cmake -S . -B build \
      -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      ''${cmakeFlags}
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    if [ -f build/modules/execution_zone_wallet_ui.dylib ]; then
      cp build/modules/execution_zone_wallet_ui.dylib $out/lib/
    elif [ -f build/modules/execution_zone_wallet_ui.so ]; then
      cp build/modules/execution_zone_wallet_ui.so $out/lib/
    elif [ -f build/modules/execution_zone_wallet_ui.dll ]; then
      cp build/modules/execution_zone_wallet_ui.dll $out/lib/
    else
      echo "Error: No library file found in build/modules/"
      ls -la build/modules/ 2>/dev/null || true
      exit 1
    fi

    runHook postInstall
  '';
}
