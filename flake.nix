{
  description = "Logos Execution Zone Wallet UI - QML view + C++ backend module";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    liblogos_execution_zone_wallet_module.url = "github:logos-blockchain/logos-execution-zone-module";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;

      # Stub the typed wrapper for liblogos_execution_zone_wallet_module.
      # That module ships its plugin via a hand-rolled mkDerivation (not
      # mkLogosModule), so it does not produce a *_api.h via
      # logos-cpp-generator --module-only. LEZWalletBackend never uses the
      # typed wrapper — it talks to the wallet module via raw
      # LogosAPIClient::invokeRemoteMethod() — but the auto-generated
      # logos_sdk.{h,cpp} umbrella still references the wrapper, so we drop
      # empty stubs in to satisfy the include + initializer.
      preConfigure = ''
        mkdir -p ./generated_code/include
        cat > ./generated_code/include/liblogos_execution_zone_wallet_module_api.h <<'EOF'
#pragma once
#include "logos_api.h"

// Stub: see flake.nix preConfigure. The wallet module isn't built with
// mkLogosModule and doesn't produce a typed _api.h. LEZWalletBackend uses
// raw LogosAPIClient::invokeRemoteMethod() instead, so this empty class
// only needs to satisfy the umbrella logos_sdk.h's member declaration and
// constructor initializer.
class LiblogosExecutionZoneWalletModule {
public:
    explicit LiblogosExecutionZoneWalletModule(LogosAPI* /*api*/) {}
};
EOF
        cat > ./generated_code/include/liblogos_execution_zone_wallet_module_api.cpp <<'EOF'
// Stub source for the typed wrapper. The umbrella logos_sdk.cpp #includes
// this file; the class is fully defined inline in the header above so this
// translation unit is intentionally empty.
EOF
      '';
    };
}
