# Release Checklist

Use this checklist for every release PR from `develop` to `master`.

## Before The Release PR

- Confirm all release work has landed on `develop`.
- Confirm the app version, build number, changelog, and release notes are final.
- Confirm no private keys, App Store credentials, analytics tokens, provisioning
  data, or local environment files are committed.
- Run `bash ./scripts/test-branch-flow-audit.sh && bash ./scripts/audit-branch-flow.sh`
  and confirm the release branch flow rules still pass.
- Run `./scripts/audit-public-artifacts.sh` and confirm it passes.
- Run `bash ./scripts/test-todo-debt-audit.sh && bash ./scripts/audit-todo-debt.sh`
  and confirm no new TODO/FIXME/STOPSHIP debt was introduced.
- Run
  `bash ./scripts/test-codecov-workflow-audit.sh && bash ./scripts/audit-codecov-workflow.sh`
  and confirm every third-party action remains pinned to its reviewed commit,
  Codecov uploads use OIDC, and coverage failures remain release-blocking.
- Run `bash ./scripts/deps/check-dependency-contracts.sh "$PWD"` and confirm
  the committed SwiftPM state, native crypto contract wiring, and
  shared-features patch wiring still fail fast before release.
- Run
  `bash ./scripts/deps/test-shared-features-delta-report.sh && bash ./scripts/deps/audit-shared-features-delta-report.sh "$PWD" --write-report build/reports/shared-features-delta-report.json`
  and review `build/reports/shared-features-delta-report.json`. Every
  `carriedDeltas` entry must either be present in the pinned
  `shared-features-spm` source before removing checkout mutation, or remain
  intentionally carried for the release. Confirm
  `removalReadiness.status` is still `blocked` unless the same report proves all
  required absent markers have been removed from CI and release scripts.
- Run
  `bash ./scripts/deps/export-shared-features-upstream-delta.sh "$PWD" build/shared-features-upstream-delta`
  before upstream handoff or release review of the shared-features patch debt,
  then attach/review `build/shared-features-upstream-delta/handoff-manifest.json`.
- Run `bash ./scripts/test-transaction-builder-tests-audit.sh && bash ./scripts/audit-transaction-builder-tests.sh`
  and confirm Bitcoin, Solana, Iroha, and TON fail-closed transfer coverage
  remains in place.
- Run
  `bash ./scripts/test-testflight-publication-readiness-audit.sh && bash ./scripts/audit-testflight-publication-readiness.sh`
  and review the exact tracked publication snapshot. Do not mark the TestFlight
  upgrade-recovery build release-enabled until the Apple-delivered in-place
  update passes the five-minute usability and second-cold-launch gate in
  `docs/testflight-4.2.0-2026.8.10-upgrade-recovery.md`. Process liveness alone
  is not release evidence.
- Run `bash ./scripts/test-coredata-release-gate.sh`, then run
  `bash ./scripts/ci/run-coredata-release-gate.sh --stage core --simulator-udid <DISPOSABLE_SIMULATOR_UDID>`.
  Require an optimized Release (`-O`) result with zero failures, skips, or
  expected failures. The test scheme must keep `-UNITTEST` enabled so the
  hosted app cannot open an unrelated simulator store.
- On an explicitly approved, sanitized regression fixture (never the live phone
  container), run
  `bash ./scripts/ci/run-coredata-release-gate.sh --stage copied-phone --simulator-udid <DISPOSABLE_SIMULATOR_UDID> --fixture <ABSOLUTE_APPROVED_FIXTURE_PATH>`.
  Require exactly two tests and unchanged source-store fingerprints. Capturing a
  new raw phone fixture requires separate explicit approval.
- Build the normal Release app without `ENABLE_TESTABILITY=YES`. Verify its
  executable retains every managed-object runtime class required by the bundled
  Substrate and User models and that both User compatibility `.mom` resources
  and every historical migration model/mapping are present. Install that exact
  app on a fresh disposable simulator containing raw copies of the complete
  store families. Run `bash ./scripts/ci/run-coredata-simulator-rehearsal.sh`
  and require first launch and relaunch to each emit exactly one
  `FEARLESS_STARTUP_READY` marker and no `FEARLESS_STARTUP_FAILED`, crash, or
  fatal Core Data/migration marker. Require exact protected row-count
  preservation plus unchanged wallet identity, key, and relationship
  fingerprints; the source fixture must remain byte-for-byte unchanged.
- Require the processed app to declare `MinimumOSVersion` exactly `15.0`. Run
  `scripts/ci/materialize-embedded-framework-dsyms.sh` on the signed archive,
  then require the signed-archive audit to prove exact UUID parity between every
  embedded code object and its dSYM. The materializer supplies UUID-exact upload
  bundles for Xcode's three generated crypto stubs and the stripped
  MPQRCoreSDK vendor binary; this removes App Store Connect's missing-dSYM
  warnings but does not claim unavailable MPQR source-line DWARF.
- Validate build `4.2.0 (2026.8.17)` through a true internal TestFlight group
  containing the affected phone's App Store Connect user before changing the
  public beta group. Do not substitute an external group that requires Beta App
  Review. Run
  `scripts/audit-testflight-upgrade-usability-gate.py` against sanitized evidence
  and require a five-minute usable first launch, working PIN and wallet route,
  the Portfolio, DeFi, Polkaswap, Cross-chain, and Settings controls/routes, a
  nonzero PI-backed Polkaswap token price,
  preservation checks, and a successful second cold launch. Do not uninstall
  or clear app data.
- Run
  `bash ./scripts/test-ton-production-send-readiness-audit.sh && bash ./scripts/audit-ton-production-send-readiness.sh`
  and confirm `config/ton-production-send-readiness.json` remains `blocked`
  with `releaseEnabled` set to `false`. This evidence gate is required in
  addition to the transaction-builder fixture audit; it must not be skipped for
  a release archive.
- Keep `TonProductionSendReleasePolicy.production` hard-disabled. Native TON
  send remains unavailable even though the local implementation now enforces:
  - a versioned, bounded, canonical Keychain journal persists the exact signed
    bearer BOC before signed emulation; pending intents survive process
    termination, validate their signature/template/quote on load, and reconcile
    before any new broadcast; ordinary confirmation never auto-rebroadcasts an
    older pending BOC, and recovery runs before mnemonic/key access;
  - journal phases are monotonic, and a confirmed terminal tombstone remains in
    the journal until the success controller has actually been presented and the
    UI explicitly acknowledges the exact intent identity and message hash;
    friendly sender addresses are canonicalized internally, so termination
    between reconciliation and user-visible success cannot authorize a duplicate;
  - confirmation binds a fresh 30-second fee quote to the exact sender,
    recipient, amount, bounce flag, body, public key, sequence number, state-init,
    expiry, endpoint origin, unsigned signing payload, signed BOC, and exact
    signed-emulation fee; stale, mutated, state-drifted, and fee-drifted quotes
    fail closed;
  - the confirmation screen starts disabled for TON, reuses one serialized
    cached transfer service, and activates a quote only after the exact
    nine-decimal TON fee and opaque quote ID have been applied to the visible
    view; the compatibility `estimateFee` API can never activate a quote, and
    unsubscribe revokes the quote synchronously;
  - recovery that confirms an older, different intent is surfaced as a distinct
    previous-transfer receipt, never as success for the new transfer; the user
    must visibly acknowledge the old exact identity/hash and receive a fresh fee
    before confirming the new transfer;
  - exact-hash unknown outcomes have explicit user-visible recovery UX and copy
    the exact lowercase 32-byte message hash;
  - signed emulation, broadcast, and reconciliation are restricted to an
    immutable reviewed endpoint allowlist with exact origin and a bounded,
    visible-ASCII provisioned authorization credential, rather than any selected
    HTTPS chain node; persisted recovery additionally requires the current
    credentialed origin to equal the stored quote origin.
  Production enablement still requires one immutable release evidence set proving:
  - current TonAPI schemas pass the bounded transport, redirect, intent-binding,
    memo-required, journal-recovery, retry, expiry, and reconciliation adversarial
    suites, and independently establish that `ignore_signature_check` unsigned
    emulation has exact fee parity with the corresponding signed Wallet V4R2
    template (or replace it with a reviewed attested quote/local-TVM mechanism);
  - the exact binary-owned send origin, credentials, and registry provenance are
    independently reviewed and provisioned; and
  - a reviewed finalized-chain absence proof or explicit audited quarantine and
    recovery workflow exists for expired, never-confirmed bearer records; the
    current fail-closed journal intentionally blocks that sender indefinitely
    rather than guessing absence, and storage atomicity must be reviewed if any
    second process or app extension can access the same Keychain namespace; and
  - a funded mainnet Wallet V4R2 transfer has independently verified emulation,
    broadcast, on-chain reconciliation, fee, and recipient credit evidence.
  Unit and fixture tests alone do not authorize production TON send.
- Run `bash ./scripts/check-iroha-mobile-sdk-release-assets.sh --self-test`.
  If `IROHA_MOBILE_SDK_RELEASE_TAG` is configured for the release, also run
  `bash ./scripts/check-iroha-mobile-sdk-release-assets.sh --download --tag "$IROHA_MOBILE_SDK_RELEASE_TAG"`.
  Then run
  `bash ./scripts/test-iroha-production-send-readiness-audit.sh && bash ./scripts/audit-iroha-production-send-readiness.sh`.
  Artifact validation does not unblock send: keep the default unavailable
  signer and Nexus disabled while
  `config/iroha-production-send-readiness.json` is `blocked`.
  For any future iOS Iroha enablement review, require all of the following in
  the same immutable release evidence set:
  - the enforced iOS 15 product minimum and SDK platform alignment;
  - a directly resolvable, compiling Swift package whose source expectations
    match every published XCFramework slice digest;
  - canonical compact transaction-hash parity and source/binary provenance;
  - authoritative protocol chain ID, live asset/scale, and fee-policy mapping;
  - a reviewed zeroizable secret-lifecycle boundary;
  - exact local/Torii receipt-hash equality plus accepted and finalized status;
  - deployed-node compatibility and funded Taira and Nexus broadcast evidence.
  A local unpublished upstream correction is diagnostic only and cannot satisfy
  a release criterion.
- From the workspace root, run
  `bash scripts/audit-passkey-backup-prerequisites.sh` and confirm
  `config/passkey-backup-production.json` still matches iOS passkey code,
  associated domains, CloudKit storage, and the production challenge-service
  contract. Before enabling user-facing passkey backup, run the same audit with
  `PASSKEY_BACKUP_LIVE_HEALTH=1` and confirm the deployed challenge service
  passes. Keep `isPasskeyBackupEnabled=false` unless that live release audit is
  green for the release.
- Before enabling user-facing passkey backup, confirm the iOS flow handles
  iCloud account availability, CloudKit production schema readiness,
  associated-domain provisioning, provisioning profiles, and a recovery path
  that offers restore before creating a new backup.
- Keep the default `UnavailableBackupAuthorizationProvider` in place
  until a reviewed issuer supplies one-time, exact-request-body-bound grants
  backed by production App Attest/provisioning evidence. Its authorization
  subject must represent stable Fearless wallet ownership across iOS and
  Android, not an Apple account or device identifier. Confirm missing,
  malformed, replayed, wrong-body, and wrong-subject grants fail before any
  challenge is issued.
- Keep `UnavailablePasskeyBackupKeyProvider` in place until product and
  security approve a wallet-owned, cross-device recovery source for an exact
  32-byte backup key. A device-local Keychain key is not a cross-device
  recovery key. Verify loss/replacement-device recovery plus wrong-key,
  tamper, metadata-swap, truncation, and nonce-uniqueness tests for the
  canonical AES-256-GCM envelope before enabling the flag.
- Verify credential list, single revoke, and revoke-all use exact-body-bound
  grants. Deletion must durably revoke all server credentials before removing
  the CloudKit record; a revoke failure must leave the encrypted record intact.
- Confirm public build instructions still work without private overlays.
- When the private iOS overlay checkout is available, run
  `PRIVATE_OVERLAY_REPORT=build/reports/private-overlay-boundary.tsv PRIVATE_REPO_DIR=../fearless-iOS-priv ./scripts/audit-private-overlay-boundary.sh`
  and confirm it passes. If it fails, use the full TSV report to move every
  listed product-code or public-config path back to the public repo before
  release.
- Run or confirm green CI for branch-flow audit, public artifact audit,
  TODO-debt audit, Iroha mobile SDK release asset contract, private-overlay
  audit self-test, simulator build, and tests.
- Confirm Universal Wallet migrations, legacy export-only access, and supported
  network registry changes are documented in the PR.
- Confirm rollback owner, monitoring owner, and release communication channel.

## Release PR To `master`

- Open the PR from `develop` or `release/<version>` to `master`.
- Include test evidence, migration notes, release notes, and rollback notes.
- Confirm the `Branch Flow` workflow is green for the release PR.
- Require review and green CI before merge.
- Merge with a merge commit so the release boundary is visible.
- Create the release tag only after the merge commit is on `master`.

## After Release

- Verify the distributed artifact matches the tagged commit.
- Monitor crash, wallet creation, import, transfer, and indexer error rates.
- Keep the hotfix path ready from `master` until rollout completes.
