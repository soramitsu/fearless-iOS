# TestFlight 4.2.1 (2026.11.9)

Uploaded on 8 November 2026. App Store Connect finished processing the build as
`VALID`; internal status is `IN_BETA_TESTING`. The existing **App Store Connect
Users** group contains the build. No external group was assigned.

- Bundle: `jp.co.soramitsu.fearlesswallet`; App Store Connect app: `1537251089`.
- Source: `6a7ebf5f6ff35c383f7de1b0827c03c87dc5fcbb` on
  `hotfix/4.2.0-polkaswap-usability`.
- PIN fix: `22713d002b139eea691ec86591c187da704f8622`, merged with the current
  release line before the build-number change.
- Delivery/build ID: `05b37a0c-319e-42d4-b3f6-9bfb9c33ccea`.
- The owner chose this build for the public release on 8 November. It replaced
  2026.11.8 in App Review as submission `0f4f11e5-0547-4e8a-bfc9-3b9fc1795d98`
  at 11:39 UTC, in the normal queue.
- On 9 November 2026.11.10 replaced it in App Review. 2026.11.9 was not reviewed and
  was never published. See `testflight-4.2.1-2026.11.10.md`.

The PIN keypad restores 72-point normal-size keys, comfortable spacing and
vertical centering. Short screens and large text can scroll without hiding
controls. Input survives layout and text-size changes.

## Local validation

The 13 PIN continuity and localized persistence/retry tests passed on iOS 27.0,
18.1 and 18.4 at the PIN fix commit (39 executions, no failures or skips).
All 13 passed again on iOS 27.0 at the exact release source above. The PIN
implementation and tests are identical across those commits.

Build-number checks and adversarial tests, 20 upgrade-evidence tests, 40 startup
capture tests, and the archive signing/provenance contract tests passed. The
signed archive passed production identity, service-configuration, historical
storage compatibility, signing, entitlements, dSYM and artifact-integrity audits.
Validation was local; hosted CI was not a release prerequisite.

## Public-release validation

Run on this source after the public release was ordered. The test and tooling
commits `8df11065e` and `6063ef167` sit on top of it and change no app code.

| Check | Result |
|---|---|
| Full suite, Debug, iOS 27.0 | 3,772 passed, 0 failed, 96 skipped |
| Full suite, Debug, iOS 18.1 | 3,769 passed, 3 failed, 96 skipped. The 3 were test assumptions, fixed in `b9bc54d1b`, and pass on iOS 18.1 and 27.0 |
| Full suite, Release `-O`, iOS 27.0 | 3,651 passed, 49 failed, 95 skipped (see below) |
| Core Data release gate, core stage | Exactly 478 Release `-O` tests, no failures, skips or expected failures |
| Core Data simulator rehearsal | Passes on iOS 27.0, 26.5, 18.1 and 17.5 from the July phone-store copy, which stays on the build Mac |
| Upgrade from 4.0.4 | G5 12/12, real launch 12/12 |
| Local-chain sends | 20/20 |
| Solana lock and kill-restart harnesses | 3/3 and 7 of 7 modes |
| Shipped-store upgrade | 1/1 |

The archive embeds `libswiftCompatibilitySpan.dylib`, signed by team `YLWWUD25VZ`.
All 12 Mach-O files have a minimum OS of 15.0 or lower, all 28 Core Data classes
are in `__objc_classlist`, and Iroha Connect's release policy is off.

### The Release `-O` failures

| Tests | Cause | Result |
|---|---|---|
| 2 `SolanaSendServiceTests` | Use-after-free, below | Fixed in `46097e14f` |
| 44 needing a window | The test host that started after those crashes, following a 14-minute pause, had no `UIWindowScene` | 44/44 pass in a fresh host |
| 2 timeouts, chain node and TON WebKit page | Probably load: the Mac's load average was over 400 | Pass in a fresh host and in the rerun |
| 1 seed-share | The test needs a Debug-only entry | Test now asserts the entry is absent in Release (`8dfefeaa2`) |

A host also started with no window scene once with no crash, after its simulator
sat idle for about 45 minutes, so idling is the likely trigger. Long runs now
reboot the simulator first. On iOS 18.1 that reboot hides the on-screen keyboard and
fails three keyboard tests; see `testflight-4.2.1-2026.11.10.md`.

**The use-after-free.** Swift 6.4.2 at `-O` makes
`SolanaTransactionBroadcaster.retry` destroy the snapshot and then retain
`record.signature` from it, on the branch for a record with no matching cluster
binding. The caller gets a freed string. **2026.11.9 contains this:** the executable
above has the same order at `0x1007fd4c0`.

No screen reaches that branch today:

- App Store 4.0.4 has no Solana code, so an update from it brings no Solana record.
- New records always carry the cluster's genesis hash, so they stay bound.
- An unbound record can only come from a TestFlight build before `625eda1c3`.
  `submit` stops it earlier at `unavailableSignature`, which is correct, and that
  dialog offers no retry.
- Retry is only offered after an unknown outcome on a bound record.

A pattern scan of the whole executable checked 222,810 destroy and release calls
and found no other real case. It is evidence, not proof.

**The fix.** `46097e14f` keeps the snapshot alive past the copy with
`withExtendedLifetime`. The retain now comes first in a testable Release build and
in a non-testable Simulator build with App Store settings. On the fix, the full suite
in Release `-O` on iOS 27.0 had 3,699 passed, 0 failed, 96 skipped and no host
restarts. The extra skip is the 113,989-row migration test, because that rebuild
left out its flag; it passed in the first Release run and in the gate, and the fix
does not touch Core Data.

**Status.** Automatic release was set at 13:46 UTC and put back to manual at 19:03
UTC when this was found, so an approval could not publish the build. Project policy
keeps a real failure blocking, so the owner decided between shipping 2026.11.9 with
this fault and replacing it with a rebuilt 2026.11.10. They chose the rebuild.

### Not run

- `Sr25519KnownAnswerTests` on a physical iPhone, Release: a test host is built and
  waits for the phone to be unlocked.
- Opening 2026.11.9 on a physical phone: it is installed on the iPhone 17 Pro Max,
  and whether it opened and unlocked is not yet confirmed.
- The gate's copied-phone stage: it needs a phone store with a non-empty `-wal`. The
  only copy has an empty one, and a new capture needs the owner's approval.
- The physical TestFlight checklist items and
  `audit-testflight-upgrade-usability-gate.py`.
- The WalletConnect live tests were not rerun. They last passed at `7f8276acf`, and
  no WalletConnect file changed from `698f42236` to this source.

`config/testflight-publication-readiness.json` describes the July public TestFlight
link (2026.7.26). That is a different channel, so it was left as it is.

### Skipped tests

| Tests | Why | Covered elsewhere |
|---|---|---|
| 32 | Placeholders, "to be implemented" | No |
| 21 | Need live remote endpoints | No |
| 20 | Local-chain sends | Yes, 20/20 |
| 7 | Upgrade fixtures | Yes, G5 and shipped-store upgrade |
| 5 | Solana process harnesses | Yes, lock and kill-restart |
| 4 | Other conditions, including a compiled rollback flag | No |
| 2 | Modules that were removed | Not applicable |
| 2 | WalletConnect live | Earlier source, above |
| 2 | Copied-phone stage | No, above |

## Artifact receipts

- Archive SHA-256: `3641c3707aa60fa4c4ebb1fc8903fc0f27d096b2c38a7f9974507a433363eba7`.
- Executable SHA-256: `66fbe8c8dd7e219d2815b9bd7a28ff2dbad0f21e98599b343997b16f86ca9b5b`.
- Uploaded IPA SHA-256: `acbb04355cf71ca4f53a148d79c3324ea819488dfc7504c381e02c78b4e4449c`.

Evidence is retained in
`/Users/takemiyamakoto/dev/fearless/build/reports/ios-pin-testflight-20261108/`.
The signed archive, IPA, export receipt and upload receipt are under
`release/6a7ebf5f6f-20261108T081618Z/`. Server verification is recorded in
`asc-testflight-verification-2026.11.9.json`.

Apple accepted the upload, but Fastlane returned exit 1 for the local
`CDUploaderStateInfoResumeFilePath` error. No retry was sent. The recovered
upload receipt binds Apple's delivery and final `VALID` status to the exact
audited archive, exported IPA and retained temporary upload copy.

Temporary production service settings were removed after the archive, and the
ignored generated configuration was restored to its keyless state.
