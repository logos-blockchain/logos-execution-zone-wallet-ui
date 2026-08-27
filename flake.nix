{
  description = "Logos Execution Zone Wallet UI - QML view + C++ backend module";

  # Pull pre-built artifacts from the self-hosted Logos Attic cache(Nix binary cache).
  nixConfig = {
    extra-substituters = [ "https://cache.nix.logos.co/public" ];
    extra-trusted-public-keys = [ "public:l4HrXgL4nw246+LBh2SOJyhz64BoGegOYLheT/iIAPU=" ];
  };

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
          (moduleOutputs.checks.${system} or {}) // (testChecks // {
            # The Qt binary wrapper carries a fresh Mach-O UUID/signature on every
            # build. These tests need no Qt plugin discovery, so retain the directly
            # linked executable and keep the check output reproducible.
            unit-tests = testChecks.unit-tests.overrideAttrs (_: {
              dontWrapQtApps = true;
            });
          })
        ) testOutputs;
      };
}
