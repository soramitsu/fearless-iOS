# Cleanup Baseline

This document is the working baseline for the codebase cleanup program. It records the current highest-value problems, the milestone order, and the acceptance criteria for each stage.

## Current Baseline

### Active Build Blocker

- Native crypto integration is not yet deterministic.
- Current failing area: `shared-features-spm` / `IrohaCrypto` integration in SwiftPM checkout state.
- Current symptom: module map and umbrella-header handling requires script-time repair instead of building cleanly from a fresh checkout.

### High-Volume Warning Buckets

- Manual `#warning` in `CallCodingPath` caused warning fan-out across many compile units.
- Deprecated API usage:
  - `UIView.beginAnimations` / `commitAnimations`
  - deprecated `withUnsafeBytes` / `withUnsafeMutableBytes` signatures
- Concurrency / sendability warnings:
  - inherited `@unchecked Sendable` not restated
  - `await` with no async work
- Code hygiene warnings:
  - unused immutable values
  - `var` that should be `let`
  - values written but never read
- Unsafe pointer construction warnings in selection list view-model hashing/equality code.
- Native binary packaging warnings from simulator frameworks such as `sr25519lib`.

### Build / Repo Process Debt

- Package identity drift between source control and registry packages has required mirrors and cache cleanup.
- Package pins exist in multiple places and have previously drifted out of sync:
  - workspace `Package.resolved`
  - project workspace `Package.resolved`
  - nested package manifests
  - dependency enforcement scripts
- Test/build scripts currently mutate transient package checkout state in `SourcePackages` / `DerivedData`.
- Several build phases always run, increasing build time and noise.

Current status:
- added repo baseline and started normalizing committed SwiftPM state
- committed `Package.resolved` files are now expected to remain identical
- `scripts/deps/check-swiftpm-consistency.sh` is the first repo-side guardrail for package drift
- `IrohaCrypto` patch flow is being consolidated so only one script owns module map / umbrella repair
- `shared-features-spm` fixes now distinguish required checkout patches from best-effort compatibility rewrites
- mirror configuration is now part of the expected committed package state
- local SwiftPM mirror bootstrap is being moved out of `test-matrix.sh` into dedicated dependency scripts
- `test-matrix.sh` is being moved toward an explicit repo-local `SourcePackages` checkout path instead of implicit `DerivedData` resolution
- package resolution now materializes the repo-local checkout before `shared-features-spm` patching, then re-resolves against that same checkout

### Test State

- Test infrastructure is substantially more stable than at the start of this effort, but the build pipeline is not yet deterministic enough to treat the whole suite as trustworthy signal.
- Integration tests should remain clearly separated from fast unit validation once the build path is stable.

## Milestones

### Milestone 1: Baseline and Inventory

Goal:
- establish one written, current inventory of failures, warnings, and debt

Exit criteria:
- this document stays up to date while cleanup is active
- current blockers are grouped by severity and dependency

### Milestone 2: Build Determinism

Goal:
- make a clean checkout resolve packages and build without manual cache surgery

Priority items:
- unify all `shared-features-spm` pins and identities
- eliminate duplicate `Web3` package identity behavior at the source
- stop relying on fragile `DerivedData` state
- simplify `test-matrix.sh` so it verifies environment instead of rewriting it

Exit criteria:
- package graph resolves cleanly from a fresh checkout
- local and CI build paths use the same dependency rules

### Milestone 3: Native Dependency Cleanup

Goal:
- replace script-time crypto patching with a durable package integration

Priority items:
- upstream or repo-owned fix for `IrohaCrypto` module map / umbrella behavior
- stable linker settings for native crypto libraries
- clear simulator architecture policy

Exit criteria:
- no post-resolve mutation needed for native crypto
- no module map or missing-symbol failures

### Milestone 4: Warning Burn-Down

Goal:
- reduce warning volume to near-zero, then prevent regression

Priority buckets:
- deprecated APIs
- concurrency/sendability
- unused values / immutability cleanup
- unsafe pointer usage
- package / binary packaging noise where actionable

Exit criteria:
- warning count is materially reduced
- touched areas are warning-free

### Milestone 5: Test Reliability

Goal:
- turn tests into reliable signal instead of environment-sensitive noise

Priority items:
- keep unit tests deterministic
- isolate network/integration tests behind explicit gating
- document expected environment requirements

Exit criteria:
- fast local validation path exists
- failures indicate regressions, not infrastructure drift

### Milestone 6: Technical Debt Refactors

Goal:
- reduce maintenance cost in the highest-risk parts of the codebase

Priority candidates:
- storage request abstractions
- duplicated operation factory behavior
- compatibility shims and legacy paths
- brittle build / dependency scripts

Exit criteria:
- smaller blast radius for changes
- less duplication and fewer special cases

### Milestone 7: Guardrails

Goal:
- keep the repository clean after the current cleanup pass

Priority items:
- CI gates for dependency drift and new warnings
- documented build/test workflow
- removal plan for temporary hotfix scripts

Exit criteria:
- future work does not reintroduce the same classes of breakage

## Current Focus

Current active milestone:
- Milestone 2: Build Determinism

Immediate next tasks:
1. Replace script-time `IrohaCrypto` checkout mutation with a durable repo-owned package fix.
2. Reduce duplicated package-resolution logic and stale cache cleanup in `scripts/test-matrix.sh`.
3. Start warning burn-down with high-volume, low-risk fixes after the build path is stable.
