# Repository Guidelines

<!-- wallet-context:start -->
> About this codebase  
> This repository contains the codebase for a cryptocurrency wallet compatible with the Polkadot ecosystem (and related networks).  
> It uses Swift Package Manager dependencies and local support packages (e.g., FearlessFoundation, FearlessSecureStorage, FearlessDependencies) and has an Android counterpart in soramitsu/fearless-Android.
<!-- wallet-context:end -->

## Project Structure & Modules
- `fearless/`: App sources, split by features/modules.
- `Packages/`: Local Swift packages and package-level dependency aggregation.
- `fearlessTests/`, `fearlessIntegrationTests/`: Unit/integration tests.
- `fearless.xcworkspace`, `fearless.xcodeproj`: Xcode workspace/project files.
- Config files: `.swiftlint.yml`, `.swiftformat`, `.periphery.yml`.

## Build, Test, and Dev Commands
- Install/validate dependencies: `bash scripts/ci/bootstrap.sh`
- Resolve packages: `xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless`
- Build (Debug, simulator):
  - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' build`
- Run unit tests (on simulator):
  - `xcodebuild -workspace fearless.xcworkspace -scheme fearless.tests -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' test`
- Verify first-party Swift packages:
  - `bash scripts/test-local-packages.sh`
- Lint/format:
  - `swiftlint` (uses `.swiftlint.yml`)
  - `swiftformat .` (uses `.swiftformat`)
  - CI matrix: `bash scripts/test-matrix.sh` runs tests for Debug and Release

Example destinations
- iPhone 15: `-destination 'platform=iOS Simulator,OS=latest,name=iPhone 15'`
- iPhone 14 Pro: `-destination 'platform=iOS Simulator,OS=latest,name=iPhone 14 Pro'`
- iPad Pro (11-inch) 4th gen: `-destination 'platform=iOS Simulator,OS=latest,name=iPad Pro (11-inch) (4th generation)'`

Tip: list available destinations with `xcodebuild -showsdks` and `xcrun simctl list devices`.

CI note
- GitHub Actions/Codecov run package bootstrap and simulator tests. For deterministic local parity, use `scripts/test-matrix.sh` before opening a PR.

## Coding Style & Naming
- Language: Swift; follow Swift API design guidelines.
- Formatting: SwiftFormat; linting with SwiftLint.
- Files: one main type per file; names in PascalCase; avoid long files.
- Packages/Modules: keep dependencies explicit; prefer dependency injection to singletons.
- Avoid force‑unwraps; handle errors explicitly with clear user messaging.

## Testing Guidelines
- Framework: XCTest; tests live in `fearlessTests/` and `fearlessIntegrationTests/`.
- Naming: mirror the class under test, e.g., `AccountRepositoryTests.swift`; test methods `testX_whenY_thenZ`.
- Coverage: maintain/raise coverage for changed code.
- New code policy: whenever you add a function, add at least one unit test covering it.

## Commit & Pull Requests
- Commits: concise, imperative subjects; reference issues (`#123`). Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`) encouraged.
- Before PR: ensure build + tests pass locally; `swiftlint`/`swiftformat` are clean.
- PR checklist: clear description, linked issue, screenshots/video for UI, steps to test, risk/rollback notes.
- CI must be green.

## Security & Configuration
- Never commit secrets or private keys. Use Keychain/secure storage at runtime; use CI secrets for pipelines.
- Do not alter seed handling, signing, or cryptography without maintainer approval.
- Runtime registries and chain/type sources must be aligned with the current Polkadot SDK release; coordinate updates with maintainers.
- Use `*.xcconfig` and environment variables for private values; avoid hardcoding secrets in `Info.plist`.

## Dependencies & Versioning
- Prefer conservative upgrades (patch/minor). Pin major bumps to separate PRs with clear testing notes.
- Summarize upstream changes (link release notes) and provide a rollback plan.
- If aligning to a Polkadot SDK release, ensure iOS utils/runtime dependencies are pinned accordingly (e.g., fearless-utils‑ios or equivalent).

## Preferred Tasks for Agents
- Keep build green: fix warnings, flaky tests, and broken CI when root cause is clear.
- Code hygiene: remove dead code; improve naming; tighten access control.
- Tooling: enforce SwiftLint/SwiftFormat; update configs when safe.
- Tests: add missing unit tests around changed code; stabilize integration tests.
- Docs: keep README/ROADMAP/this guide accurate; small updates are welcome.

## Out of Scope (without prior approval)
- Feature/UI/UX changes.
- Protocol, staking, or on‑chain logic changes.
- Wallet/account management, seeds, encryption, or secure storage changes.
- Adding telemetry/analytics.

## Communication & Escalation
- Use GitHub issues/PRs for decisions and traceability.
- See `CONTRIBUTING.md` for community channels and expectations.
- When in doubt, open an issue and wait for maintainer guidance.

## Sources of Truth
- Roadmap (Aha!): https://soramitsucoltd.aha.io/shared/97bc3006ee3c1baa0598863615cf8d14
- Dev status board: https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2
- Issues: https://github.com/soramitsu/fearless-iOS/issues
- Contributing: ./CONTRIBUTING.md
- Roadmap (repo): ./ROADMAP.md

---

By following these guidelines, agents help keep Fearless Wallet iOS healthy, predictable, and aligned with the published roadmap while minimizing risk to users.

## Build & Archive — End‑to‑End Checklist

The project is Swift Package Manager based. Follow these steps in order.

1) Prerequisites (local dev)
- Xcode 15.4+ (Xcode 18 SDK supported; CI pins 15.x when available for SPM/IrohaCrypto stability)
- SwiftFormat, SwiftLint (optional for local): `brew install swiftformat swiftlint`

2) Resolve SPM packages
- CLI: `xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless`
- Xcode GUI: File → Packages → Reset Package Caches → Resolve Package Versions (if needed)

3) Bootstrap dependency contracts
- From repo root: `bash scripts/ci/bootstrap.sh`

4) Build & test on Simulator (no signing)
- Build: `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' build`
- Tests: `bash scripts/test-matrix.sh` (runs Debug + Release simulator tests using `fearless.tests` by default)

5) Archive (two options)
- Development archive (local testing without Distribution certs):
  - In Xcode target ‘fearless’ → Signing & Capabilities (Dev config): set Automatic + Apple Development + your team/profile.
  - The Apple Developer account must have access to the `group.jp.co.soramitsu.fearlesswallet.walletconnect` App Group used by `fearless/WalletConnect.entitlements` and `WalletConnectService`.
  - Then: `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Dev -destination 'generic/platform=iOS' -archivePath "$PWD/build/fearless.xcarchive" clean archive`
  - To export an installable development IPA with the same verification checks: `SIGNING_MODE=automatic EXPORT_METHOD=debugging SIGNED_ARCHIVE=1 EXPORT_SIGNED_ARCHIVE=1 REQUIRE_RUNTIME_KEYS=0 SKIP_BOOTSTRAP=1 ARCHIVE_PATH="$PWD/build/fearless-debugging.xcarchive" EXPORT_PATH="$PWD/build/fearless-debugging-export" bash scripts/ci/archive-smoke.sh "$PWD"`
  - To install and launch that IPA on a trusted connected device: `DEVICE_ID="<device udid|serial|name>" IPA_PATH="$PWD/build/fearless-debugging-export/fearless.ipa" scripts/ci/install-ipa-to-device.sh`
- Release-testing archive (CI/Release parity; legacy Xcode calls this ad-hoc):
  - Requirements on the machine: Apple Distribution certificate for team `YLWWUD25VZ` + unexpired release-testing/ad-hoc profile `fearlesswallet-dev-adhoc` installed.
  - The profile must target `jp.co.soramitsu.fearlesswallet.dev` and include the `group.jp.co.soramitsu.fearlesswallet.walletconnect` App Group.
  - Project Dev config must be Manual + Apple Distribution + `jp.co.soramitsu.fearlesswallet.dev` + `PROVISIONING_PROFILE_SPECIFIER=fearlesswallet-dev-adhoc`.
  - Preflight contracts, runtime keys, and signing material: `RELEASE_READINESS_MODE=preflight scripts/ci/release-readiness.sh "$PWD"`
  - Full archive/export verification: `RELEASE_READINESS_MODE=archive scripts/ci/release-readiness.sh "$PWD"`
  - Full archive/export/install/launch on a trusted device: `RELEASE_READINESS_MODE=install DEVICE_ID="<device udid|serial|name>" scripts/ci/release-readiness.sh "$PWD"`
    - Install mode checks device availability with `scripts/ci/check-device-ready.sh` before starting the signed archive.
  - Verify CI/release parity with a signed archive/export: `REQUIRE_SIGNED_ARCHIVE=1 SKIP_BOOTSTRAP=1 bash scripts/ci/archive-smoke.sh "$PWD"`
    - This verifies the expected signing identity/profile, all required runtime keys, the signed archive path, archive entitlements, and the exported release-testing IPA contents including the packaged app and embedded profile.
    - To also install and launch the exported IPA on a trusted connected device, add `INSTALL_EXPORTED_IPA=1 DEVICE_ID="<device udid|serial|name>"`.
    - If Xcode is logged into an account that can download updated manual signing assets, add `ALLOW_PROVISIONING_UPDATES=1`; the script will still verify the final archive and export contents.
- Automatic archive/export with App Store Connect API key:
  - Provide `APP_STORE_CONNECT_API_KEY_CONTENT`, `APP_STORE_CONNECT_API_KEY_ID`, and `APP_STORE_CONNECT_API_KEY_ISSUER_ID`.
  - Then run: `SIGNING_MODE=automatic ALLOW_PROVISIONING_UPDATES=1 EXPORT_METHOD=release-testing REQUIRE_SIGNED_ARCHIVE=1 SKIP_BOOTSTRAP=1 bash scripts/ci/archive-smoke.sh "$PWD"`
  - The script writes the `.p8` key content to a temporary file, passes xcodebuild authentication flags, and still verifies the exported IPA signature, bundle id, team id, profile, and App Group.

6) Runtime keys
- CI/app keys are read from environment-backed build settings and local `*.xcconfig` values. Do not hardcode secrets in source or `Info.plist`.
- Validate release keys strictly with: `STRICT_RUNTIME_KEYS=1 scripts/secrets/validate-runtime-keys.sh "$PWD"`; strict mode rejects missing and obvious placeholder values.
- `scripts/ci/archive-smoke.sh` loads `.env.local`, `.env`, or `ENV_FILE=...` into the archive process so the same runtime keys validated by strict mode are exported to `xcodebuild`.
- Runtime key wiring is guarded by `scripts/deps/check-runtime-key-contracts.sh`, which keeps the generator map, stencil, `.env.example`, strict validator, and Codecov workflow secret mapping in sync.

7) IrohaCrypto + SPM stability (Xcode 16/18)
- The SPM package `shared-features-spm` must be pinned to a revision that works with Xcode 16/18 (`3ad0fe9…`). We now enforce this automatically via `scripts/deps/enforce-ssf-pin.sh` in CI (`bootstrap.sh`), local dev (`dev-setup.sh`), and tests (`test-matrix.sh`).
- Dependency-contract validation is centralized in:
  - `scripts/deps/check-dependency-contracts.sh`
- Native crypto stability now uses dedicated contract scripts:
  - `scripts/deps/prepare-native-crypto-checkout.sh`
  - `scripts/deps/apply-native-crypto-package-contract.sh`
  - `scripts/deps/apply-native-crypto-modulemap-contract.sh`
  - `scripts/deps/verify-native-crypto-package-state.sh`
- Additional required `shared-features-spm` compatibility fixes (BigInt dep, Web3 Data.bytes, AddressFactory type usage, scrypt guard) are applied by `scripts/spm-shared-features-fixes.sh`.
- The bundled simulator x86_64 slices for native crypto are incomplete; simulator builds exclude x86_64 and use arm64.

8) Web3 duplication
- The project uses `soramitsu/web3-swift@7.7.7`. Do not add another Web3 source; duplicate packages will cause resolver failure.

## CI Build Requirements

- Environment variables:
  - `GH_READ_TOKEN` (optional): GitHub token for authenticated SwiftPM fetches from Soramitsu-owned repositories.
  - `DEVELOPER_DIR` (optional): pin Xcode when the agent has multiple installations.
- Manual signed archive verification in the Codecov workflow requires:
  - `IOS_DISTRIBUTION_CERTIFICATE_P12_BASE64`
  - `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
  - `FEARLESSWALLET_DEV_ADHOC_PROFILE_BASE64`
  - all runtime keys listed in `.env.example` as GitHub secrets
- Automatic signed archive verification in the Codecov workflow can be used instead of manual p12/profile signing by setting:
  - `APP_STORE_CONNECT_API_KEY_CONTENT`
  - `APP_STORE_CONNECT_API_KEY_ID`
  - `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
  - all runtime keys listed in `.env.example` as GitHub secrets
- Steps performed before archive:
  - Clean SPM caches; resolve packages if the workspace exists.
  - Configure GitHub token if provided.
  - Prepare the native crypto checkout against the repo-owned contract when required by the resolved package state.
- Manual signed archive smoke archives and exports Dev as release-testing with mapping:
  - `jp.co.soramitsu.fearlesswallet.dev` → `fearlesswallet-dev-adhoc`
  - Ensure the Apple Distribution cert for `YLWWUD25VZ` is installed on the CI keychain.

## Common Build Failures & Fixes

- “No profile … matching ‘fearlesswallet-dev-adhoc’”: install the release-testing/ad-hoc profile (and Distribution certificate) on the machine, or switch PR builds to Development signing.
- “Application Group with Identifier ‘group.jp.co.soramitsu.fearlesswallet.walletconnect’ is not available”: enable/assign that App Group to the app identifier in Apple Developer, or get maintainer approval before changing both `fearless/WalletConnect.entitlements` and `WalletConnectService.walletConnectGroupIdentifier`.
- “Missing package product ‘MPQRCoreSDK’”: resolve SPM; reset SPM caches; ensure network access for binary targets.
- “umbrella header … IrohaCrypto-umbrella.h not found”: use the pinned `shared-features-spm` revision and run the dedicated native crypto contract scripts / verifier.
- “multiple similar targets ‘Web3’ …”: dedupe to `soramitsu/web3-swift@7.7.7` only.
- Native crypto undefined symbols on x86_64 simulator: build arm64 simulator; the app xcconfigs exclude x86_64 for simulator SDKs.
- “Ambiguous type ‘MetaAccountModel’ / ‘ChainAccountResponse’ in tests”: tests include `fearlessTests/Helper/TestTypeAliases.swift` to resolve ambiguity to app models. If you add conflicting SDK types, keep this shim or qualify uses (`fearless.MetaAccountModel`).
- “JSONRPCEngine conformance missing in tests”: `fearlessTests/Common/Services/ChainRegistry/MockConnection.swift` provides a test engine conforming to the current `JSONRPCEngine` protocol. If the protocol changes upstream, adjust this file accordingly.

## Troubleshooting Raw Archive Output

- To bypass xcpretty and see the actual error:
  - `set -o pipefail; xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Dev -destination 'generic/platform=iOS' -archivePath "$PWD/build/fearless.xcarchive" clean archive | tee build/archive.raw.log`
  - Then: `tail -n 300 build/archive.raw.log`
