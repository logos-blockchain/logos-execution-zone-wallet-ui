{
  description = "Logos Execution Zone Wallet UI - QML view + C++ backend module";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder/0.2.6";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    lez_core.url = "github:logos-blockchain/logos-execution-zone-module?rev=d5482868c4706c2de8b931f76f2e1050c219016b";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    let
      moduleOutputs = logos-module-builder.lib.mkLogosQmlModule {
        src = ./.;
        configFile = ./metadata.json;
        flakeInputs = inputs;
      };
      testOutputs = logos-module-builder.lib.mkLogosModuleTests {
        src = ./.;
        testDir = ./tests;
        configFile = ./metadata.json;
        flakeInputs = inputs;
      };
    in
      (builtins.removeAttrs moduleOutputs [ "apps" ]) // {
        checks = builtins.mapAttrs (system: testChecks:
          (moduleOutputs.checks.${system} or {}) // testChecks
        ) testOutputs;
      };
}
