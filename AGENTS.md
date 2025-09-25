# Repository Guidelines

<!-- wallet-context:start -->
> About this codebase  
> This repository contains the codebase for a cryptocurrency wallet compatible with the Polkadot ecosystem (and related networks).  
> It uses dependencies available in the iOS ecosystem (e.g., SoraFoundation, SoraKeystore, FearlessKeys) and has an Android counterpart in soramitsu/fearless-Android.
<!-- wallet-context:end -->

## Project Structure & Modules
- `fearless/`: App sources, split by features/modules.
- `fearlessTests/`, `fearlessIntegrationTests/`: Unit/integration tests.
- `fearless.xcworkspace`, `fearless.xcodeproj`: Xcode workspace/project files.
- `Pods/`, `Podfile`, `Podfile.lock`: CocoaPods dependencies.
- `Jenkinsfile`: CI pipeline configuration.
- Config files: `.swiftlint.yml`, `.swiftformat`, `.periphery.yml`.

## Build, Test, and Dev Commands
- Install dependencies: `pod install`
- Build (Debug, simulator):
  - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' build`
- Run unit tests (on simulator):
  - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' test`
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
- Jenkins is configured to run tests on each build. For deterministic local parity, use `scripts/test-matrix.sh` before opening a PR.

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
- CI must be green (Jenkins or equivalent).

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

The project mixes CocoaPods and Swift Package Manager. Follow these steps in order.

1) Prerequisites (local dev)
- Xcode 15.4+ (Xcode 18 SDK supported; CI pins 15.x when available for SPM/IrohaCrypto stability)
- CocoaPods: `brew install cocoapods` (or `gem install cocoapods`)
- SwiftFormat, SwiftLint (optional for local): `brew install swiftformat swiftlint`

2) Install Pods (always open the workspace)
- From repo root: `pod install`
- Open: `open fearless.xcworkspace`

3) Resolve SPM packages
- CLI: `xcodebuild -resolvePackageDependencies -workspace fearless.xcworkspace -scheme fearless`
- Xcode GUI: File → Packages → Reset Package Caches → Resolve Package Versions (if needed)

4) Build & test on Simulator (no signing)
- Build: `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' build`
- Tests: `bash scripts/test-matrix.sh` (runs Debug + Release simulator tests)

5) Archive (two options)
- Development archive (local testing without Distribution certs):
  - In Xcode target ‘fearless’ → Signing & Capabilities (Dev config): set Automatic + Apple Development + your team/profile.
  - Then: `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Dev -destination 'generic/platform=iOS' -archivePath "$PWD/build/fearless.xcarchive" clean archive`
- Ad‑hoc archive (CI/Release parity):
  - Requirements on the machine: Apple Distribution certificate for team `YLWWUD25VZ` + ad‑hoc profile `fearlesswallet-dev-adhoc` installed.
  - Project Dev config must be Manual + Apple Distribution + `jp.co.soramitsu.fearlesswallet.dev` + `PROVISIONING_PROFILE_SPECIFIER=fearlesswallet-dev-adhoc`.

6) Private pods (FearlessKeys)
- The pod `FearlessKeys` is private. To allow `pod install` on CI/local without prompting:
  - Provide a GitHub Personal Access Token with repo read access (recommended env var: `GH_PAT_READ`).
  - Preconfigure git on the agent: `git config --global url."https://${GH_PAT_READ}@github.com/".insteadOf "https://github.com/"`
  - Alternatively, write a `~/.netrc` with GitHub credentials (read‑only).

7) IrohaCrypto + SPM stability (Xcode 16/18)
- The SPM package `shared-features-spm` must be pinned to a revision that works with Xcode 16/18 (`6d6cb16…`).
- A hotfix exists at `scripts/spm-iroha-hotfix.sh` that patches `IrohaCrypto` module map if stale DerivedData causes umbrella header errors; `scripts/test-matrix.sh` will invoke it for tests.

8) Web3 duplication
- The project uses `soramitsu/web3-swift@7.7.7`. Do not add another Web3 source; duplicate packages will cause resolver failure.

## CI Build Requirements (Jenkins)

- CocoaPods available on agents (or handled in a shared pipeline step). If Pods are installed elsewhere, our Jenkinsfile guards will skip `pod install` gracefully.
- Environment variables:
  - `GH_PAT_READ` (optional): GitHub PAT for private pods (`FearlessKeys`).
  - `DEVELOPER_DIR` (optional): Jenkinsfile auto‑pins to Xcode 15.x if present for SPM stability; otherwise default Xcode is used.
- Steps performed before archive:
  - Clean SPM caches; resolve packages if the workspace exists.
  - Configure GitHub token (if provided) and run `pod install --repo-update` when `pod` is available.
  - Patch IrohaCrypto module map if needed (hotfix function inside Jenkinsfile).
- Fastlane lane archives Dev as Ad‑hoc with mapping:
  - `jp.co.soramitsu.fearlesswallet.dev` → `fearlesswallet-dev-adhoc`
  - Ensure the Apple Distribution cert for `YLWWUD25VZ` is installed on the CI keychain.

## Common Build Failures & Fixes

- “No profile … matching ‘fearlesswallet-dev-adhoc’”: install the ad‑hoc profile (and Distribution certificate) on the machine, or switch PR builds to Development signing.
- “Missing package product ‘MPQRCoreSDK’”: resolve SPM; reset SPM caches; ensure network access for binary targets.
- “umbrella header … IrohaCrypto-umbrella.h not found”: use the pinned `shared-features-spm` revision and/or run the hotfix (`scripts/spm-iroha-hotfix.sh`).
- “multiple similar targets ‘Web3’ …”: dedupe to `soramitsu/web3-swift@7.7.7` only.
- “pod install” fails cloning FearlessKeys: supply `GH_PAT_READ` or gate that pod in CI.

## Troubleshooting Raw Archive Output

- To bypass xcpretty and see the actual error:
  - `set -o pipefail; xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Dev -destination 'generic/platform=iOS' -archivePath "$PWD/build/fearless.xcarchive" clean archive | tee build/archive.raw.log`
  - Then: `tail -n 300 build/archive.raw.log`
