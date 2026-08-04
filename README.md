# logos-execution-zone-wallet-ui

A QML + C++ backend UI module for the [Logos](https://logos.co) platform that provides a graphical interface to manage execution zone wallet accounts and transfers.

Built with [`logos-module-builder`](https://github.com/logos-co/logos-module-builder) using the `mkLogosQmlModule` pattern (QML frontend + C++ backend with Qt Remote Objects).

## Features

- Create and list public/private accounts
- View account balances
- Sync to block height
- Public and private transfers (shielded, deshielded, private-owned)
- Open the wallet profile shared by modules in the same Basecamp instance
- Account key management

## Supported Platforms

- **Linux**: x86_64, aarch64
- **macOS**: aarch64 (Apple Silicon)

## How to Run in Basecamp

The supported runtime is the module installed inside Basecamp. Build the LGX and install it into the Basecamp plugin directory:

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

## Shared wallet startup

`lez_core` owns the default wallet profile for the Basecamp instance. On startup this UI waits for the inter-module handshake, calls `wallet_status`, calls `open_default` when the profile is closed, and refreshes accounts only after the shared profile reports `open`.

This startup slice does not create or restore wallets. Those actions remain blocked on the secure core lifecycle release tracked by [execution-zone#156](https://github.com/logos-blockchain/logos-execution-zone/issues/156) and [lez_core PR #47](https://github.com/logos-blockchain/logos-execution-zone-module/pull/47).

### Legacy settings and wallet files

Older releases stored user-selected config and storage locations in UI settings. The normal Basecamp flow now ignores those values: it does not read, rewrite, clear, log, or derive locations from them. Existing settings and wallet files are left untouched. A future explicit migration flow must let the user review and confirm any import; do not delete legacy data while evaluating this startup change.

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
