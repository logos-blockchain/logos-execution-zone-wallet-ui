# logos-execution-zone-wallet-ui

A Qt UI plugin for the Logos Execution Zone Wallet Module, providing a graphical interface to manage execution zone wallet accounts and transfers.

## Features

- Create and list public/private accounts
- View account balances
- Sync to block height
- Public and private transfers
- First-time onboarding (config path, storage path, password)

## Supported platforms

- **Linux**: x86_64, aarch64
- **macOS**: aarch64 (Apple Silicon)
- **Windows**: x86_64 (Nix build depends on logos-liblogos and other inputs providing Windows packages)

## How to Build

### Using Nix (Recommended)

```bash
# Build plugin (default)
nix build

# Build standalone app
nix build '.#app'

# Development shell
nix develop
```

### Running the Standalone App

Build and run in one step:

```bash
nix run
```

Or build first, then run:

```bash
nix build '.#app'
./result/bin/logos-execution-zone-wallet-ui-app
```

## Nix Organization

- `nix/default.nix` — Common configuration (dependencies, flags)
- `nix/lib.nix` — UI plugin compilation
- `nix/app.nix` — Standalone Qt application compilation

## Configuration

Config path and storage path are persisted via QSettings (`Logos`, `ExecutionZoneWalletUI`). On first run, if opening the wallet fails, the onboarding screen is shown to create a new wallet.

### QML hot reload

During development, set `DEV_QML_PATH` to your `src/qml` directory to load QML from disk and see changes without recompiling:

```bash
export DEV_QML_PATH=/path/to/logos-execution-zone-wallet-ui/src/qml
```
