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
