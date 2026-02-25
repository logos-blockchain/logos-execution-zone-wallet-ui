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
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    logos-package-manager.url = "github:logos-co/logos-package-manager-module";
  };

  outputs = { self, nixpkgs, logos-cpp-sdk, logos-liblogos, logos-execution-zone-module, logos-capability-module, logos-design-system, nix-bundle-lgx, logos-package-manager }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" "x86_64-windows" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        logosSdk = logos-cpp-sdk.packages.${system}.default;
        logosLiblogos = logos-liblogos.packages.${system}.default;
        logosExecutionZoneModule = logos-execution-zone-module.packages.${system}.default;
        logosCapabilityModule = logos-capability-module.packages.${system}.default;
        logosDesignSystem = logos-design-system.packages.${system}.default;
        lgxBundler = nix-bundle-lgx.bundlers.${system}.default;
        lgpm = logos-package-manager.packages.${system}.cli;
      });
    in
    {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosExecutionZoneModule, logosCapabilityModule, logosDesignSystem, lgxBundler, lgpm }:
        let
          common = import ./nix/default.nix {
            inherit pkgs logosSdk logosLiblogos;
          };
          src = ./.;

          lib = import ./nix/lib.nix {
            inherit pkgs common src logosExecutionZoneModule;
          };

          logosCapabilityModuleLgx = lgxBundler logosCapabilityModule;
          logosExecutionZoneModuleLgx = lgxBundler logosExecutionZoneModule;

          app = import ./nix/app.nix {
            inherit pkgs common src logosLiblogos logosExecutionZoneModule logosCapabilityModule logosDesignSystem lgpm logosCapabilityModuleLgx logosExecutionZoneModuleLgx;
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

      devShells = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosExecutionZoneModule, logosCapabilityModule, logosDesignSystem, lgpm, ... }: {
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
