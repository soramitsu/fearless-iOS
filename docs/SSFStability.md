SSF Dependencies Stability Notes

Overview
- The wallet depends on Soramitsu’s shared-features-spm (SSF) packages: SSFModels, SSFUtils, IrohaCrypto, Polkaswap, etc. Xcode 16+/18 and SwiftPM cache resets can cause frequent build/test breakage without guardrails.

Key fixes in this repo
- Pin shared-features-spm revision: 6d6cb16b7f1f12028fe93d50a4e928a938af141e
  - Script: scripts/deps/enforce-ssf-pin.sh
  - Wired into dev (scripts/dev-setup.sh), CI (scripts/ci/bootstrap.sh), and tests (scripts/test-matrix.sh) before package resolution.
  - Why: prevents resolver drift when Package.resolved is invalidated by Xcode, keeping a known-good SSF state.

- IrohaCrypto module.modulemap hotfix
  - Script: scripts/spm-iroha-hotfix.sh
  - What: corrects umbrella header path and injects a minimal umbrella header when missing under DerivedData/SourcePackages.
  - Why: fixes “umbrella header … IrohaCrypto-umbrella.h not found” on Xcode 16+ with stale DerivedData.

- shared-features-spm manifest/source patches
  - Script: scripts/spm-shared-features-fixes.sh
  - What: ensures SSFModels depends on BigInt/RobinHood under explicit module builds; patches Web3 Data.bytes drift; converts SSFCrypto AddressFactory to struct for DI; guards scrypt SSE2 on arm64-sim; normalizes Polkaswap AddressFactory metatype usage.
  - Why: resolves frequent compile errors after upstream changes or stricter build settings.

- Git LFS for binary targets
  - CI/bootstrap ensures git-lfs is installed and LFS assets are fetched for shared-features-spm (e.g., MPQRCoreSDK.xcframework). Fails with a clear message when missing.

Test target resilience
- Ambiguous models: tests include fearlessTests/Helper/TestTypeAliases.swift to alias MetaAccountModel and ChainAccountResponse to the app’s types and avoid collisions with SSF types.
- JSONRPCEngine: tests include a complete conformance in fearlessTests/Common/Services/ChainRegistry/MockConnection.swift.

How to update SSF safely
- Bump the shared-features-spm revision in enforce-ssf-pin.sh (and consider updating Package.resolved), then run scripts/dev-setup.sh.
- Verify: scripts/test-matrix.sh (Debug + Release).
- If IrohaCrypto errors appear, re-run spm-iroha-hotfix.sh or clear DerivedData caches.

