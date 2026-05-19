# Release Notes Draft

Prepared on May 19, 2026 for release `4.2.0` from `develop` at `947b154ec54505dd6cd547dcd2e68f64ba295771`.

Scope:
- Base commit: `84c96ef32135efeaa4aef0d0c78313b77e320e14`
- Head commit: `947b154ec54505dd6cd547dcd2e68f64ba295771`
- App project version in source on May 19, 2026: `MARKETING_VERSION = 4.2.0`, `CURRENT_PROJECT_VERSION = 8`

## App Store "What's New"

- Added TON balance support improvements, including better handling for jettons and more reliable asset updates.
- Added Coinbase buy flow support for supported assets and networks.
- Improved WalletConnect stability and session handling.
- Fixed account switching, transfer validation, and transaction history issues across multiple networks.
- Improved overall app reliability with broader network compatibility and balance-sync fixes.

## Internal Release Summary

### User-facing additions

- Added TON support infrastructure in the wallet balance pipeline.
- Added TON jetton balance handling and TON environment selection logic improvements.
- Added Coinbase purchase provider integration for supported buy flows.

### Wallet and account improvements

- Restored the real account switch and account management flow.
- Improved WalletConnect configuration, signer compatibility, and storage setup.
- Improved window and top-view-controller handling in app navigation flows.

### Balance, assets, and chain data

- Improved TON, Ethereum, and Substrate balance fetching paths.
- Fixed caching for single TON jetton balance refreshes.
- Preserved cached chain assets and asset price data during persistence and reloads.
- Fixed missing-account handling so chains without an account return empty balances instead of stale state or hard errors.
- Improved chain asset persistence and mapper compatibility with current shared-features models.
- Improved handling of para metadata, identity-related fields, and tolerant chain decoding.

### Network, history, and transfer fixes

- Restored websocket multi-node failover behavior.
- Improved explorer and history provider normalization so non-Subsquid and OKLink routes are handled correctly.
- Restored XCM minimum-amount validation for affected bridge routes.
- Improved transfer and cross-chain compatibility handling, including trusted aliaser behavior.
- Improved chain sync behavior to fail closed on malformed token payloads instead of clearing cached assets.

### SORA and ecosystem compatibility

- Improved SORA-related asset wiring and compatibility paths in the balance and pricing stack.
- Updated dependencies and compatibility layers to align with the current shared-features and Polkadot ecosystem APIs.

### Build, CI, and release engineering

- Hardened simulator selection in local and CI test flows, including architecture-aware destination handling.
- Hardened Codecov and PR test workflows to avoid false-green runs and simulator resolution failures.
- Added and standardized SwiftPM pinning, mirror bootstrapping, and native-crypto contract enforcement.
- Improved private-pod handling for `FearlessKeys` in PR and local builds.
- Added bootstrap, dependency-contract, and release-prep helper scripts to stabilize local and CI builds.
- Restored project references and build-phase inputs required for clean builds without private dependencies.

### Test and tooling improvements

- Added broad regression coverage for TON routing, chain sync compatibility, storage mapping, network worker compatibility, and asset persistence.
- Refreshed mocks, test aliases, and compatibility shims to keep the test targets aligned with current app and dependency APIs.
- Stabilized `scripts/test-matrix.sh` and related test tooling for Debug and Release simulator runs.

## Notes For App Store Connect

- The "What's New" section above is already written in App Store-safe language and avoids internal tooling details.
- If you want a shorter version for phased release or hotfix submission, use only the first three bullets and keep the rest in internal release notes.
