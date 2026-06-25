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
- Run `bash ./scripts/test-transaction-builder-tests-audit.sh && bash ./scripts/audit-transaction-builder-tests.sh`
  and confirm Bitcoin, Solana, Iroha, and TON fail-closed transfer coverage
  remains in place.
- Run `bash ./scripts/check-iroha-mobile-sdk-release-assets.sh --self-test`.
  If `IROHA_MOBILE_SDK_RELEASE_TAG` is configured for the release, also run
  `bash ./scripts/check-iroha-mobile-sdk-release-assets.sh --download --tag "$IROHA_MOBILE_SDK_RELEASE_TAG"`.
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
