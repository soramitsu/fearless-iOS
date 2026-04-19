SSF Dependencies Stability Notes

Overview
- The wallet depends on Soramitsu’s shared-features-spm (SSF) packages: SSFModels, SSFUtils, IrohaCrypto, Polkaswap, etc. Xcode 16+/18 and SwiftPM cache resets can cause frequent build/test breakage without guardrails.
- Repo entrypoints now validate dependency contracts centrally via `scripts/deps/check-dependency-contracts.sh`.

Key fixes in this repo
- Pin shared-features-spm revision: 3ad0fe928333c9ac28972e3669ca733c6972f060
  - Script: scripts/deps/enforce-ssf-pin.sh
  - Wired into dev (scripts/dev-setup.sh), CI (scripts/ci/bootstrap.sh), and tests (scripts/test-matrix.sh) before package resolution.
  - Why: prevents resolver drift when Package.resolved is invalidated by Xcode, keeping a known-good SSF state.

- Native crypto package contract
  - Scripts:
    - scripts/deps/check-native-crypto-contract-wiring.sh
    - scripts/deps/prepare-native-crypto-checkout.sh
    - scripts/deps/apply-native-crypto-package-contract.sh
    - scripts/deps/apply-native-crypto-modulemap-contract.sh
    - scripts/deps/verify-native-crypto-package-state.sh
  - What:
    - validates that the repo entrypoints still point at the single native crypto contract flow
    - prepares a resolved native crypto checkout end-to-end
    - short-circuits when the resolved checkout already matches the repo-owned contract
    - fails fast if Swift Package re-resolution does not succeed
    - enforces explicit IrohaCrypto linker settings from a repo-owned block
    - enforces module.modulemap and umbrella-header state from repo-owned templates
    - verifies the resolved shared-features-spm checkout matches the expected native-crypto contract
  - Why:
    - fixes missing-symbol and umbrella-header failures
    - makes native crypto failures explicit instead of depending on ad hoc cache mutation

- shared-features-spm manifest/source patches
  - Script: scripts/spm-shared-features-fixes.sh
  - What: ensures SSFModels depends on BigInt/RobinHood under explicit module builds; patches Web3 Data.bytes drift; converts SSFCrypto AddressFactory to struct for DI; guards scrypt SSE2 on arm64-sim; normalizes Polkaswap AddressFactory metatype usage.
  - Why: resolves frequent compile errors after upstream changes or stricter build settings.
  - Wiring guard: scripts/deps/check-shared-features-fix-wiring.sh

- Native crypto upstream delta
  - Doc: docs/SSFNativeCryptoUpstreamDelta.md
  - What: records the exact `shared-features-spm` source changes still being carried locally for `IrohaCrypto` and provides an export script for upstream handoff.
  - Why: makes the remaining Milestone 3 work explicit and upstreamable instead of leaving it distributed across repair scripts.

- Git LFS for binary targets
  - CI/bootstrap ensures git-lfs is installed and LFS assets are fetched for shared-features-spm (e.g., MPQRCoreSDK.xcframework). Fails with a clear message when missing.

Test target resilience
- Ambiguous models: tests include fearlessTests/Helper/TestTypeAliases.swift to alias MetaAccountModel and ChainAccountResponse to the app’s types and avoid collisions with SSF types.
- JSONRPCEngine: tests include a complete conformance in fearlessTests/Common/Services/ChainRegistry/MockConnection.swift.

How to update SSF safely
- Bump the shared-features-spm revision in enforce-ssf-pin.sh (and consider updating Package.resolved), then run scripts/dev-setup.sh.
- Verify: scripts/test-matrix.sh (Debug + Release).
- If IrohaCrypto errors appear, inspect the native crypto contract scripts and verifier output before clearing caches.
