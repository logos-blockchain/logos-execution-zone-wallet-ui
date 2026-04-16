# logos-execution-zone-wallet-ui

A QML + C++ backend UI module for the [Logos](https://logos.co) platform that provides a graphical interface to manage execution zone wallet accounts and transfers.

Built with [`logos-module-builder`](https://github.com/logos-co/logos-module-builder) using the `mkLogosQmlModule` pattern (QML frontend + C++ backend with Qt Remote Objects).

## Features

- Create and list public/private accounts
- View account balances
- Sync to block height
- Public and private transfers (shielded, deshielded, private-owned)
- First-time onboarding (config path, storage path, password)
- Account key management

## Supported Platforms

- **Linux**: x86_64, aarch64
- **macOS**: aarch64 (Apple Silicon)

## How to Run

### Standalone (recommended for development)

```bash
# Run directly
nix run

# With local workspace overrides
nix run --override-input liblogos_execution_zone_wallet_module path:../logos-execution-zone-module \
        --override-input logos-module-builder path:../logos-module-builder
```

The standalone app starts Logos Core, loads `capability_module` and `liblogos_execution_zone_wallet_module`, then launches the QML UI via an isolated `ui-host` process.

### In Basecamp

```bash
# Build LGX
nix build .#lgx

# Install into Basecamp's plugin directory
lgpm --ui-plugins-dir ~/Library/Application\ Support/Logos/LogosBasecampDev/plugins \
     install --file result/*.lgx
```

Or from the workspace:

```bash
ws bundle logos-execution-zone-wallet-ui --auto-local
```

### Build Targets

```bash
nix build            # default — combined plugin + QML output
nix build .#lgx      # .lgx package for distribution
nix build .#install  # lgpm-installed output (modules/ + plugins/)
nix run              # standalone app with wallet module
nix develop          # enter development shell
```

## Module Structure

```
logos-execution-zone-wallet-ui/
├── flake.nix                          # mkLogosQmlModule
├── metadata.json                      # Module config (ui_qml type)
├── CMakeLists.txt                     # logos_module() macro
└── src/
    ├── LEZWalletBackend.rep           # RemoteObject interface
    ├── LEZWalletBackend.h/cpp         # Business logic (extends LEZWalletBackendSimpleSource)
    ├── LEZWalletPlugin.h/cpp          # Thin plugin entry point
    ├── LEZWalletPluginInterface.h     # Plugin interface marker
    ├── LEZWalletAccountModel.h/cpp    # QAbstractListModel for accounts
    ├── LEZAccountFilterModel.h/cpp    # Proxy model for account filtering
    └── qml/
        └── ExecutionZoneWalletView.qml  # QML frontend (+ sub-views)
```

## Configuration

Config path and storage path are persisted via QSettings (`Logos`, `ExecutionZoneWalletUI`). On first run, if opening the wallet fails, the onboarding screen is shown to create a new wallet.

### QML Hot Reload

During development, set `DEV_QML_PATH` to load QML from disk without recompiling:

```bash
export DEV_QML_PATH=/path/to/logos-execution-zone-wallet-ui/src/qml
```

## Dependencies

| Dependency | Purpose |
|---|---|
| Qt6 Core, RemoteObjects, Declarative | UI framework + IPC |
| [`logos-module-builder`](https://github.com/logos-co/logos-module-builder) | Build system (mkLogosQmlModule) |
| [`logos-execution-zone-module`](https://github.com/logos-blockchain/logos-execution-zone-module) | Wallet backend module |

## Related Repositories

| Repository | Role |
|---|---|
| [`logos-execution-zone-module`](https://github.com/logos-blockchain/logos-execution-zone-module) | Wallet backend — this UI's required dependency |
| [`logos-module-builder`](https://github.com/logos-co/logos-module-builder) | Module build system |
| [`logos-liblogos`](https://github.com/logos-co/logos-liblogos) | Logos Core platform |
