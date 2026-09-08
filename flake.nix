{
  description = "Logos Execution Zone Wallet UI - QML view + C++ backend module";

  # Pull pre-built artifacts from the self-hosted Logos Attic cache(Nix binary cache).
  nixConfig = {
    extra-substituters = [ "https://cache.nix.logos.co/public" ];
    extra-trusted-public-keys = [ "public:l4HrXgL4nw246+LBh2SOJyhz64BoGegOYLheT/iIAPU=" ];
  };

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    # TODO: repoint to github:logos-blockchain/logos-execution-zone-module once
    # logos-execution-zone-module#56 is merged.
    lez_core.url = "git+https://github.com/logos-blockchain/logos-execution-zone-module?ref=erhant/wire-payer-ffi-changes";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
