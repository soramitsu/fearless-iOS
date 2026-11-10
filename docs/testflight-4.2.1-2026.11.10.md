# TestFlight and App Review 4.2.1 (2026.11.10)

Uploaded on 9 November 2026. App Store Connect finished processing the build as
`VALID` at 11:56 UTC; internal status is `IN_BETA_TESTING`. The existing **App Store
Connect Users** group contains the build. No external group was assigned.

- Bundle: `jp.co.soramitsu.fearlesswallet`; App Store Connect app: `1537251089`.
- Source: `5b91c912c4c05fa3806d909d16bfbfcdc932ed73` on
  `hotfix/4.2.0-polkaswap-usability`.
- Delivery/build ID: `d2e684fa-13e5-423a-ac1e-e5bb26147400`.
- App Review: the owner chose to replace 2026.11.9 with this build ("Build
  2026.11.10"). 2026.11.9 was removed from the queue unreviewed at 12:03 UTC and was
  never published. This build was submitted at 12:04 UTC as
  `329e0185-c418-4977-8419-77be27971a94`, in the normal queue. The What's New text
  did not change.
- Release type: changed from `AFTER_APPROVAL` to `MANUAL` on 10 November at
  01:01 UTC after a PIN lifecycle failure required investigation. The submission
  remained in the normal review queue. A real application race was subsequently
  confirmed; this build must remain held and be replaced by 2026.11.11. The owner
  authorized the replacement and its production service settings. No expedited
  review was requested.

## What changed from 2026.11.9

Two changes reach the app:

- `46097e14f` fixes a use-after-free the compiler produced in
  `SolanaTransactionBroadcaster.retry` at `-O`. No screen reached it. See
  `testflight-4.2.1-2026.11.9.md`.
- The build number.

## Local validation at this source

Validation was local; hosted CI was not a release prerequisite.

| Check | Result |
|---|---|
| Full suite, Release `-O`, iOS 27.0 | 3,700 passed, 0 failed, 95 skipped, no host restarts |
| Full suite, Debug, iOS 27.0 | 3,771 passed, 1 failed, 96 skipped; the 1 passes alone (below) |
| Full suite, Debug, iOS 18.1 | Takeover run on a first-boot simulator: 3,770 passed, 2 failed, 96 skipped. TON fixture and real PIN lifecycle race, below |
| Core Data release gate, core stage | Exactly 478 Release `-O` tests, no failures, skips or expected failures |
| Core Data simulator rehearsal | Passes on iOS 27.0, 26.5, 18.1 and 17.5; the phone-store copy is unchanged |
| Upgrade from 4.0.4 | G5 12/12 and real launch 12/12, each after one rerun (below) |
| Local-chain sends | 20/20 |
| Solana lock and kill-restart harnesses | 3/3 and 7 of 7 modes |
| Shipped-store upgrade | 1/1 |
| Source audits and script self-tests | 59/59; one needed a rerun (below) |

The skipped tests are those listed in `testflight-4.2.1-2026.11.9.md`, less the
113,989-row migration test, which ran and passed in this Release suite.

### Failures and how each was settled

| Test | Where | Settled by |
|---|---|---|
| TON WebKit bridge, page timeout | Debug on iOS 27.0 and 18.1 | The fixture did not attach its view to a visible scene and did not track the intended navigation. Test-only fix `07c717d56` passes ten repeated bridge checks on each runtime |
| `KeychainContinuityTests` U6, 5 s PIN timeout | `ton-27` upgrade cell | The cell passes 6/6 on a fresh clone. Wallet data was preserved in both runs |
| `roots-26` real launch | `simctl launch` hit its 10-minute limit at load above 800 | Passes on a fresh clone with all 13 app keys unchanged. The first run also left them unchanged |
| Two export-password keyboard tests and the username keyboard test | Debug on iOS 18.1, every run on a rebooted simulator | Simulator state, below |
| `PinPersistenceTests/testActualNavigationPopFencesPendingPinChangeCompletion` | Reproduced in the first-boot iOS 18.1 full run | **Real app race; blocks this build.** A pending save can navigate after the PIN screen is removed but before its disappearance callback cancels the presenter. Application fix `4fc2b3a1a` belongs in replacement 2026.11.11 |
| `test-fastlane-testflight-contract.sh` | Audits | The audit script did not set `FASTLANE_BIN`, so the test found Homebrew's Fastlane 2.241.2. It passes with the reviewed 2.238.0 |

**The PIN departure race.** Diagnostic tests at `a6fcb1b96` use the production
`FearlessNavigationController`, wait for actual appearance and transition events,
and deliver the pending save callback immediately after a real animated or
nonanimated pop. The race reproduced in 18 of 20 attempts on iOS 18.1. Timestamped
traces show `willMove(toParent: nil)` before the pop returns, followed by stale
navigation from the save completion, then `viewWillDisappear`. The earlier claim
that this was only simulator load sensitivity was incorrect. `4fc2b3a1a` cancels
the presenter at the containment callback, before UIKit removes the screen.
The baseline failure, traces, source/artifact hashes and replacement validation
are retained under `takeover-20261110/`; the replacement has its own release record.

**The keyboard tests.** A rebooted iOS 18.1 simulator hides its on-screen keyboard.
With one `.xctestrun`, a new simulator passes all three on its first boot and fails
them after every reboot, reporting a 75-point frame and hide events only. Setting
`AutomaticMinimizationEnabled` to false does not help, because the system sets it
back at boot. No code in `fearless/` or `fearlessTests/` touches this state, and iOS
27.0 is not affected. The validation scripts rebooted before each full run, which is
what brought it on; the 2026.11.9 run passed these tests on a first boot. A real
hardware keyboard was not tested. In the failing state the username test could not
scroll Continue into view, but it also injects a fake keyboard over the hidden one.

### Availability

The Debug simulator availability compile completed successfully on 9 November 2026
at 20:13:47 UTC, with an explicit iOS 18.1 simulator destination. It compiled 5,975
Swift steps, reported `BUILD SUCCEEDED`, exited 0 and produced no availability
diagnostics. Its app target was `arm64-apple-ios15.0-simulator`; the checkout stayed
clean at `39a3e0997`, which adds only documentation to release source `5b91c912c`.
The receipt is `tests/audits/availability-explicit-destination.record.txt`, alongside
the retained raw build log.

The earlier `scripts/check-availability.sh` attempts stalled during simulator
discovery and do not count as passes. Independently, the signed Release archive's
clean build contains 1,007 compile steps targeting `arm64-apple-ios15.0` and no
availability diagnostics.

### Physical sr25519 validation

On 10 November 2026, `Sr25519KnownAnswerTests` passed all 11 tests, with no failures
or skips, on an iPhone 17 Pro Max running iOS 27.0.1. The test used the separate
`jp.co.soramitsu.fearlesswallet.dev` host, built from `6063ef167` in Debug with
`SWIFT_OPTIMIZATION_LEVEL=-O` and testability enabled. The sr25519 implementation,
native libraries, signing wrappers and relevant tests and fixtures are unchanged
from that source to this release. The recorded uncommitted files at build time were
unrelated mnemonic-share and iPad layout tests.

This verifies those cryptography paths on a physical device; it does not verify
the exact App Store archive or the Release compile conditions. The test app was
removed afterward, and the before/after installed-app inventory matched. The
production wallet was not replaced or operated. Evidence is in
`takeover-20261110/device/`, `device-run.log` and `device-test-provenance.json`.

### The signed archive

The archive passed the production identity, service-configuration, historical
storage, signing, entitlements, dSYM and artifact-integrity audits.

- 12 Mach-O files: 2 have a minimum OS of 14.0 and 10 have 15.0.
- `libswiftCompatibilitySpan.dylib` is signed by team `YLWWUD25VZ`.
- All 28 Core Data classes are in `__objc_classlist`.

**The fix in the device binary.** The signature is retained at `0x1007fd4dc` before
the snapshot is destroyed at `0x1007fd4ec`. 2026.11.9 did these the other way round.

**Whole-binary scan.** `scan-retain-after-destroy.py` examined 222,807 destroy and
release calls and flagged 48, against 49 in 2026.11.9. The one that went is the fixed
site, and none are new. The other 48 were triaged as safe on 2026.11.9. This is a
pattern scan: evidence, not proof.

### Physical TestFlight update

On 10 November 2026, the owner confirmed updating from 2026.11.9 to 2026.11.10,
opening and unlocking normally, with existing wallets appearing normally. Read-only
paired-device metadata independently confirmed version `4.2.1`, build `2026.11.10`
on the same iPhone 17 Pro Max. The receipt is
`takeover-20261110/physical-testflight-upgrade.json`.

This is a basic in-place upgrade and wallet-visibility check. It does not attest to
a funded transfer, a new copied-phone database fixture, or every item in the longer
physical usability checklist.

### Release tooling follow-ups

`278f3bd88` removes simulator discovery from the availability compilation check and
captures compiler stderr. Its six regression cases pass. The script defaults to a
generic simulator destination and supports an explicit destination.

The workspace passkey prerequisite audit was stale relative to its committed API
contract: revoke-all uses `CredentialRevokeAllRequest`, and null assertion handles
are restricted to an exact credential-bound challenge. Workspace commit `bf28086`
updates those checks. All 149 audit self-tests and the offline audit against this
exact iOS release source pass. Passkey backup stays disabled; this does not qualify
the deployed service or authorize enabling it. The workspace remote could not be
fetched (`Repository not found`), so that tooling commit is retained locally.

### Not run

- `Sr25519KnownAnswerTests` using the exact Release compile configuration on a
  physical phone; the optimized Debug device result above has narrower scope.
- The gate's copied-phone stage: it needs a phone store with a non-empty `-wal`. The
  only copy has an empty one, and a new capture needs the owner's approval.
- The physical TestFlight checklist items and
  `audit-testflight-upgrade-usability-gate.py`.
- The WalletConnect live tests. They last passed at `7f8276acf`, and no WalletConnect
  file changed from `698f42236` to this source.

## Artifact receipts

- Archive SHA-256: `f05b6ae7f399a12c0a38add755413f6904ddea8f6d5eefb8881bfd9ba0c61b1a`.
- Executable SHA-256: `327ad0f878af332b909e70e1c91f7fb99f17ef6c579505668b4d8bd92eddc851`.
- Uploaded IPA SHA-256: `f42d921f3f902455b2c9790d94c7bfc78929c8d62b3caf8a6089d00233a8cce7`.

Evidence is retained in
`/Users/takemiyamakoto/dev/fearless/build/reports/ios-public-release-4.2.1-2026.11.10/`.
The signed archive, IPA, export receipt and upload receipt are under
`release/5b91c912c4-20261109T104208Z/`. Server verification is recorded in
`asc-testflight-verification-2026.11.10.json`, and the review change in the
`asc-1` to `asc-5` receipts.

Apple accepted the upload, but Fastlane returned exit 1 for the local
`CDUploaderStateInfoResumeFilePath` error, as with 2026.11.9. No retry was sent. The
recovered upload receipt binds Apple's delivery and final `VALID` status to the exact
audited archive and exported IPA.

Temporary production service settings were removed after the archive, and the ignored
generated configuration was restored to its keyless state.
