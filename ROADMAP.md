# Roadmap — Fearless Wallet iOS

This document mirrors the structure used in the Android repository’s roadmap and adapts it for iOS. The authoritative product roadmap and delivery plans are maintained in Aha! and on the public dev board.

## Full support for Polkadot SDK release: polkadot-stable2503

Why: Align the wallet with the latest stable Polkadot SDK, ensuring type/metadata compatibility and correct decoding/encoding across chains.

Scope: Substrate runtime alignment across Polkadot/Kusama/Westend/AssetHub and major parachains used by the app (per chain registry).

Acceptance criteria:
- App runs without SCALE decode errors on target chains.
- Balances, transfers, fees, and staking screens load and execute extrinsics successfully on Polkadot and Kusama.
- Chain sync stable: connections establish, runtime providers load, subscriptions update on version bumps.
- No regressions in unit/integration tests; lint/format checks green.
- If APIs changed (e.g., extrinsic names/signatures), code updated or guarded by capability checks.

Suggested steps:
1) Registry alignment:
   - Refresh chain/type registries consumed by the app to stable2503.
   - If registries are bundled JSONs in the app, replace them with stable2503‑aligned versions and verify diffs in PR.
   - If registries are provided by SSF libraries or remote endpoints, coordinate with maintainers to bump the dependency or adjust the configured URLs for Debug/QA builds and verify.
   - Capture the exact sources/versions used in the PR description.
2) Utils/runtime integration:
   - Pin or update iOS runtime/utils dependencies (e.g., SSFChainRegistry/SSFRuntimeCodingService or equivalents) to versions compatible with stable2503.
   - Verify that SCALE encoding/decoding and metadata parsing succeed on target chains in debug logs.
3) Build + checks:
   - `bash scripts/ci/bootstrap.sh`
   - `swiftformat . && swiftlint`
   - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' build`
   - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' test`
4) Runtime smoke tests (manual):
   - Verify initial network connections and metadata load (debug logs).
   - Balances show assets and fiat values.
   - Send: compute fee and submit a small transfer on Westend/Kusama (test account).
   - Staking: validators/nominators decode without crashes.
5) Address API deltas:
   - Update runtime‑extrinsic assumptions and storage paths; add capability checks as needed.
6) Update defaults (optional):
   - If stable2503 becomes default, update configuration and docs with the new registry sources.
7) Document:
   - Add notes on the exact registry sources/versions and verification results in the PR description and update this roadmap if needed.

Verification matrix (execute manually):
- Polkadot: balances load, transfer fee computed, send succeeds on test account.
- Kusama: as above; staking validator list loads.
- AssetHub: asset enumeration works; transfers succeed to another account.
- Westend: basic transfer path for low‑risk checks.

## iOS Backlog (illustrative)
- [ ] WalletConnect: improve session reconnection reliability and error surfacing.
- [ ] EVM chains: handle gas estimation failures gracefully; improve fee UI for L2s.
- [ ] Staking: optimize validators list loading and caching on slow networks.
- [ ] Localization: audit new/changed strings across all `.lproj`; fill gaps.
- [ ] Performance: reduce cold start time; trim excessive logging in Release.
- [ ] Fearless Utils (upstream hygiene):
  - Align package manifests with modern toolchains (iOS 13+, drop armv7). No functional changes.
  - Keep SwiftPM manifests as the primary integration path.
  - Verify IrohaCrypto consumption consistency across app and utils (prefer single source to avoid duplicate modules).
  - Ensure CI builds on Xcode 16/18 with iPhoneOS SDK 18.x (no armv7, correct module visibility).
  - Target: open PR to soramitsu/fearless-utils-iOS with minimal, non‑breaking changes; coordinate release tagging.

## Xcode & App Store Compliance
- Keep Xcode and Swift toolchain aligned with supported App Store requirements.
- Update deployment targets and signing settings as needed; verify Release builds on CI.
- Ensure third‑party libraries and binary artifacts meet App Store policies.
 - CI hygiene for iOS 18 SDK:
   - Deduplicate SwiftPM packages (e.g., Web3) to a single source to avoid resolver conflicts.
   - Patch or bump modules with brittle module.modulemap (e.g., IrohaCrypto via shared‑features‑spm) and upstream fixes.
   - Keep runtime keys environment-backed and unavailable to untrusted PRs.

## Sources of Truth
- Product roadmap (Aha!): https://soramitsucoltd.aha.io/shared/97bc3006ee3c1baa0598863615cf8d14
- Dev status board: https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2
- Issues: https://github.com/soramitsu/fearless-iOS/issues
- README: ./README.md
- Contributing: ./CONTRIBUTING.md

For the most accurate and up‑to‑date details, always refer to the Aha! roadmap and dev board links above.
