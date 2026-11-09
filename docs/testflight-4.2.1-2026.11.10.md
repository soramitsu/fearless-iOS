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
- Release type: `AFTER_APPROVAL` since 12:04 UTC, so it goes public when Apple
  approves it. No expedited review was requested.

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
| Full suite, Debug, iOS 18.1 | 3,768 passed, 4 failed, 96 skipped on a rebooted simulator; each of the 4 is explained below. No run was clean, and a run on a first boot stalled and did not finish |
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
| TON WebKit bridge, 10 s page timeout | Debug on iOS 27.0 and 18.1 | Passes alone on both, in 2.5 s and 1.1 s. Load average was above 800 |
| `KeychainContinuityTests` U6, 5 s PIN timeout | `ton-27` upgrade cell | The cell passes 6/6 on a fresh clone. Wallet data was preserved in both runs |
| `roots-26` real launch | `simctl launch` hit its 10-minute limit at load above 800 | Passes on a fresh clone with all 13 app keys unchanged. The first run also left them unchanged |
| Two export-password keyboard tests and the username keyboard test | Debug on iOS 18.1, every run on a rebooted simulator | Simulator state, below |
| `PinPersistenceTests/testActualNavigationPopFencesPendingPinChangeCompletion` | One Debug run on iOS 18.1 | Passes alone in 0.2 s. It was already recorded as load-sensitive at 2026.11.6. The test pops without animation, so the cancel can run after the save's completion on a slow machine; that part is a reading of the code, not a proof |
| `test-fastlane-testflight-contract.sh` | Audits | The audit script did not set `FASTLANE_BIN`, so the test found Homebrew's Fastlane 2.241.2. It passes with the reviewed 2.238.0 |

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

`scripts/check-availability.sh` did not finish. It was blocked in `simctl list`, in
uninterruptible wait, because the simulator service had stalled on the overloaded
Mac. It also never completed for 2026.11.9: the log from that attempt has no compile
steps.

Its test is a grep of the build output, so the same pattern was run over this
archive's log: a clean compile with 1,007 compile steps, targeting
`arm64-apple-ios15.0`, with 0 matches. In Swift a use above the deployment target is
a compile error. This is the shipped Release configuration, not the script's Debug
Simulator one.

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

### Not run

- `Sr25519KnownAnswerTests` on a physical iPhone, Release: the phone stayed locked for
  the 12 hours the test waited. It is waiting again.
- Opening 2026.11.10 on a physical phone.
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
