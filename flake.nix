{
  description = "Logos Execution Zone Wallet UI - A Qt UI plugin for Logos Execution Zone Wallet Module";

  inputs = {
    nixpkgs.follows = "logos-liblogos/nixpkgs";
    logos-cpp-sdk.url = "github:logos-co/logos-cpp-sdk";
    logos-liblogos.url = "github:logos-co/logos-liblogos";
    logos-execution-zone-module.url = "github:logos-blockchain/logos-execution-zone-module";
    logos-capability-module.url = "github:logos-co/logos-capability-module";
    logos-design-system.url = "github:logos-co/logos-design-system";
    logos-design-system.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, logos-cpp-sdk, logos-liblogos, logos-execution-zone-module, logos-capability-module, logos-design-system }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" "x86_64-windows" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        logosSdk = logos-cpp-sdk.packages.${system}.default;
        logosLiblogos = logos-liblogos.packages.${system}.default;
        logosExecutionZoneModule = logos-execution-zone-module.packages.${system}.default;
        logosCapabilityModule = logos-capability-module.packages.${system}.default;
        logosDesignSystem = logos-design-system.packages.${system}.default;
      });
    in
    {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosExecutionZoneModule, logosCapabilityModule, logosDesignSystem }:
        let
          common = import ./nix/default.nix {
            inherit pkgs logosSdk logosLiblogos;
          };
          src = ./.;

          lib = import ./nix/lib.nix {
            inherit pkgs common src logosExecutionZoneModule;
          };

          app = import ./nix/app.nix {
            inherit pkgs common src logosLiblogos logosExecutionZoneModule logosCapabilityModule logosDesignSystem;
            logosExecutionZoneWalletUI = lib;
          };
        in
        {
          logos-execution-zone-wallet-ui-lib = lib;
          app = app;
          lib = lib;

          default = lib;
        }
      );

      apps = nixpkgs.lib.genAttrs systems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.app}/bin/logos-execution-zone-wallet-ui-app";
        };
      });

      devShells = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosExecutionZoneModule, logosCapabilityModule, logosDesignSystem }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
            pkgs.zstd
            pkgs.krb5
            pkgs.abseil-cpp
          ];

          shellHook = ''
            export LOGOS_LIBLOGOS_ROOT="${logosLiblogos}"
            export LOGOS_DESIGN_SYSTEM_ROOT="${logosDesignSystem}"
            echo "Logos Execution Zone Wallet UI development environment"
            echo "LOGOS_LIBLOGOS_ROOT: $LOGOS_LIBLOGOS_ROOT"
          '';
        };
      });
    };
}
