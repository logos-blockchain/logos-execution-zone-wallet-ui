{
  description = "Logos Execution Zone Wallet UI - QML view + C++ backend module";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    logos_execution_zone.url = "github:logos-blockchain/logos-execution-zone-module?rev=ee5a7e7e3b062c625a7f5af451f87a2c4ac67e4b";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
