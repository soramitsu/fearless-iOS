# TestFlight 4.2.0 (2026.10.1)

Status: **source ready; not yet archived or uploaded.** Archiving needs the
production service settings, and uploading needs App Store Connect access. Both
belong to the owner and are described under "Publishing" below.

## Candidate

- Branch: `release/fearless-safe-upgrade`, which includes the TestFlight safety
  lane `lane/I6-testflight-security`.
- Bundle and version: `jp.co.soramitsu.fearlesswallet`, `4.2.0 (2026.10.1)`,
  the first build number above the consumed 2026.9.6.
- Release settings: `MinimumOSVersion` 15.0, `-O`, testability off, no `DEBUG`
  code, `get-task-allow` false.
- Signing: Apple Distribution for team `YLWWUD25VZ` with the App Store profile
  "Fearless App Store 2026.7.26" (valid until 2027-07-26). The release identity
  audit passes for this version and build.

## Safety changes in this build

These close gaps found in the pre-TestFlight review of the candidate:

- WalletConnect signing is compiled off (`WalletConnectSigningPolicy`), the same
  way IrohaConnect is. A dApp request is declined before any key is read, the
  dApp receives a rejection, and the user sees one notice that nothing was
  signed. Existing sessions stay listed and can be disconnected. WalletConnect's
  SDK telemetry is switched off.
- A Google Drive backup of an existing wallet asks for the PIN or biometrics
  before the recovery phrase is read, like the phrase, seed and JSON exports. New
  backup passwords need at least eight characters; restoring an older backup
  still accepts its password.
- While the app is in the background, a launch-screen window covers every other
  window, so the app switcher snapshot never shows a phrase, seed or key.
- The emergency export share sheet no longer offers Copy (which syncs through
  Universal Clipboard), printing, contacts or posting targets. Files, AirDrop and
  mail remain so the material can still reach a recovery tool.
- Remote config stays veto-only: a failed feature-toggle fetch no longer brings
  back NFT send that the live config switches off, and the remote
  `pendulum_case_enabled` flag can no longer switch on QR recovery-phrase import.
- A TON testnet switch stored by the hidden debug menu of 4.0.2 to 4.1.0 no
  longer keeps Release builds on TON testnet.
- Node addresses a user enters must use `wss://`.
- A staking alert no longer links to a domain that has lapsed.
- The privacy manifest declares the file timestamp, system boot time, disk
  space and app-group defaults APIs the app uses.

## Verification

Run on 2026-10-22 against the safety lane (code identical to its head) on an
iOS 27.0 simulator, Xcode 27.0, with the pinned package checkout.

- Unit suite (`fearlessTests`, Debug test build): 3,192 tests executed, 3,119
  passed, 72 skipped, 1 failed. The failure,
  `SendPresentationTests.testActualKeyboardNotificationsRetainEditorAndReachContinue`,
  is a keyboard-layout hit test that ran while the host's load average was
  above 150. It passed 13 of 14 isolated reruns on the lane and 14 of 14 on the
  unchanged candidate, failing runs took two to three times longer, and the
  lane does not touch Send. Re-run it on an idle host before uploading.
- Core Data release gate in optimized Release (`-O`): 469 tests, no failures,
  skips or expected failures. The gate's reviewed manifest still lists 424 tests
  because the candidate later added 54 and renamed 9; with a refreshed manifest
  (awaiting review) the gate reports PASSED for exactly 469 tests.
- Static gates on the lane: public artifacts, TODO debt, transaction-builder
  coverage, release signing gate, publication snapshot, the three storage model
  audits, dependency contracts, private overlay boundary and the release
  identity for 4.2.0 (2026.10.1) pass. The TON and Iroha send-readiness audits
  pass once their own pattern and scan bugs are fixed; those tooling fixes are
  awaiting review and do not change the app.
- Unsigned Release device build: succeeds, with `MinimumOSVersion` 15.0, `-O`,
  testability off and the extended privacy manifest. An inventory of every URL
  compiled into the app and its frameworks shows no new hosts and no cleartext
  endpoint the app uses.
- SwiftFormat lint of the app sources: clean.

## Publishing

1. Provide the production service settings as the ignored
   `fearless/env-vars.sh` in the release worktree (the variable names are in
   `scripts/ci/generate-ios-service-configuration.py`). The release audit
   requires the TON API, WalletConnect project, Google backup client and URL
   scheme, Alchemy, Etherscan and KaiaScan settings. Do not export them into the
   shell that runs `xcodebuild`; the build phase reads the file itself.
2. Build and audit the archive from a clean checkout:
   `bash scripts/ci/build-audited-ios-release-archive.sh --archive <new absolute
   path>.xcarchive --receipt <new absolute path>.json`, with
   `IOS_RELEASE_SOURCE_PACKAGES_DIR` and `SOURCE_PACKAGES_DIR` set to the pinned
   package checkout.
3. Confirm in App Store Connect that build 2026.10.1 is unused, then upload with
   `fastlane ios publish_archive` or Xcode Organizer, and assign the build to the
   internal group only.

## Notes for testers

- The build installs over the App Store version and keeps existing wallets.
  Write down every wallet's recovery phrase before installing any test build.
- Check after the upgrade: every wallet, address and balance; PIN and
  biometrics; By token portfolio; explicit network on Send and Receive; Bitcoin
  and Solana sends with small amounts only; backup and export prompts.
- Not available: WalletConnect signing, IrohaConnect and XCM transfers.
- Never take screenshots of recovery phrases or keys; screenshots attached to
  TestFlight feedback are uploaded to Apple.
