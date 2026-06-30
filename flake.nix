{
  description = "Logos Execution Zone Wallet UI - QML view + C++ backend module";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    logos_execution_zone.url = "github:logos-blockchain/logos-execution-zone-module?rev=b555cd5e81e192989311848150e2d0d7ec3f4eee";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
