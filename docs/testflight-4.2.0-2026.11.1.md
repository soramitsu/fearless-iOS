# TestFlight 4.2.0 (2026.11.1)

Status: **uploaded to App Store Connect on 1 November 2026 at 08:29 JST** (delivery
`4f2d5592-e99d-4010-a657-ac907a21fb5d`) for internal TestFlight testing. App Store Connect reported no warnings and
was processing the build when the upload finished.

## Candidate

- Branch: `release/4.2.0` (PR #1312), archived at `b8fe48bd5`. The tests ran at `5b8bc191c` and `385ce7aed`;
  `b8fe48bd5` and the later `0cf384557` change only the archive script and its contract test, so the app sources
  are those of `5b8bc191c`.
- Bundle and version: `jp.co.soramitsu.fearlesswallet`, `4.2.0 (2026.11.1)`. Builds 2026.10.1 and 2026.10.29 were
  never uploaded.
- Devices: iPhone and, new in this build, iPad (`UIDeviceFamily` 1 and 2, all four iPad orientations).
  `MinimumOSVersion` 15.0, `ITSAppUsesNonExemptEncryption` false.
- Signing: Apple Distribution for team `YLWWUD25VZ` (certificate SHA-1 `84AB95335BE14CAE9B050A353910F86FF2F9539B`)
  with the App Store profile "Fearless App Store 2026.7.26" (`0d51265e-4b53-4a1f-814a-436dc9ca087b`, valid until
  2027-07-26).
- Service settings: taken from `soramitsu/fearless-keys` 0.1.5 (`8eca7dd5d`), the source of 4.1.0 and 2026.9.6, on the
  owner's OK, and written to the ignored `fearless/env-vars.sh`: TON API, WalletConnect project, Google Drive backup
  client and callback, Etherscan V2 and Alchemy. On 2026-11-01 TonAPI, WalletConnect, Etherscan and Alchemy (node and
  transfer history) each accepted its key and refused a random one, and Google's OAuth endpoint accepted the backup
  client with its bound callback. No release source holds a KaiaScan key, so Kaia history shows its error with Retry
  and View on explorer; the release audit treats that key as optional since `910067a21`.

## What changed since 2026.10.29

- **Universal accounts use the wallet password** (#1314, design A). A wallet with a `///password` derives its
  Bitcoin, Solana, TON and Taira/Nexus accounts with that password as the BIP39 passphrase. Imports and restores
  keep the words-only account while it holds funds or can't be checked, and existing accounts are never replaced
  automatically. One notice per wallet lists old and new addresses, and Switch moves only an account confirmed empty.
- **Substrate `///password` is NFKD-normalised everywhere**, like the phones. When an earlier browser extension's rule
  (NFC, or the password as typed) gives a different account, the import asks which account to open. A network's own
  phrase import asks too.
- **Native iPad layout** (merge of `claude/ios-ipad-native-4.2.0`): adaptive columns and sheets, side panels and
  corner-adapted safe areas on iPadOS 26 and later. iPhone layouts are unchanged.
- **Review fixes** (Codex gpt-6-astra, ultra, four rounds on the password lanes): a password wallet keeps watching
  the universal account it doesn't show, in both directions, and switches only when the shown one is confirmed
  empty. Funds arriving at a password-protected address get their own notice in nine languages. Arrivals are
  recorded for the wallet that found them, and stale checks are dropped. The notice queue shows Switch's outcome
  before queued arrivals and never shows a notice twice.
- **Archive provenance**: master took the 4.2.0 line as one squash commit (#1305), so no master-based source could
  pass the archive's ancestry check against the distributed 2026.7.28 source `2e45e55dc`. The archive now accepts
  descent from the squash `cbc0b07c8`. It first checks that the squash's tree is exactly the tree of the pull request
  head `aad0fc85b`, and that this head descends from `2e45e55dc`. After the upload, an independent review hardened
  the check (`0cf384557`): it fails closed when a tree can't be read, and the contract test runs it against a
  throwaway history shaped like #1305, so seven bypass mutations now fail.
- **TestFlight 2026.9.6 testers**: that build's legacy-wallet and history fixes are in this release, re-implemented
  more strictly by #1305. Of the 7,146 app lines its four fix commits added, 97% are present verbatim; the rest was
  rewritten (Etherscan V2 history, EVM node failover, the keychain-transaction rollback of a native TON import, and
  the verified phrase export). Its store models are in the historical store audit.

## Verification

All local (this project does not use hosted CI). Evidence: the workspace's `build/reports/ios-testflight-2026.11.1/`.

- Full `fearless.tests` suite at `385ce7aed` (iOS 26.5 simulator, Xcode 27.2): 3,593 tests, 3,497 passed, 94 skipped
  (the same skip set as every earlier baseline), 2 failed. Both failures were iPad sheet tests with frames recorded on
  iOS 27.0; `5b8bc191c` (test only) derives them from the corner-adapted safe area, and the 133 iPad lane tests pass
  there.
- Key continuity from 4.0.4 (G5) at `5b8bc191c`: 6 of 6 iOS 26.5 cells pass (roots, curves and paths, raw seeds,
  JSON, per-network accounts, TON). The old state stays byte-identical after each cell. This host cannot run the six
  iOS 27.0 cells, because Xcode 27.2 refuses the 27.0 runtime.
- Static release audits (9), the release identity audit for 4.2.0 (2026.11.1), the three storage model audits and 34
  of 34 runnable script tests pass. The archive contract test and the service configuration audit tests (35) pass at
  `b8fe48bd5`, and the hardened contract test (10 override mutations, 8 provenance cases) at `0cf384557`.
- Signed archive (`scripts/ci/build-audited-ios-release-archive.sh` at `b8fe48bd5`, 23:20-23:27 UTC on 31 October):
  every gate passed. The gates cover the service settings (generated file SHA-256 `10f2c5b4…49bd8`, unchanged by the
  build), the release identity, the three storage audits, `** ARCHIVE SUCCEEDED **` and the signed-artifact audit
  (exact certificate, App Store profile, production entitlements and Core Data contract). Archive tree SHA-256
  `c81695395b76e912dabe7afd506d8b6d6a0aafa09abf7b1905065c8c16dcadae`, app executable SHA-256
  `67a419eab4f261c57681b04b760f6b05b1df5f57e3ae335faf24a73c369ed21d`. The build log and receipts contain no key
  value.
- App Store IPA export of the same archive: SHA-256
  `c3ae963a0939b6a61fa41436e73fef8afabee43e607427c5f68cf82c90b359bc` (101,011,479 bytes), 4.2.0 (2026.11.1),
  `UIDeviceFamily` 1 and 2. The upload (`xcodebuild -exportArchive`, destination `upload`, Xcode's signed-in team
  account) re-exported the archive with the same options: 17 analysis responses with no warnings, then
  `UPLOAD SUCCEEDED with no errors` and state `PROCESSING`.

## Publishing again

1. Write the production settings to the ignored `fearless/env-vars.sh` in a clean release checkout (names in
   `scripts/ci/generate-ios-service-configuration.py`), then run
   `bash scripts/ci/build-audited-ios-release-archive.sh --archive <new path>.xcarchive --receipt <new path>.json` with
   `IOS_RELEASE_SOURCE_PACKAGES_DIR` and `SOURCE_PACKAGES_DIR` set to the pinned package checkout. This build's
   settings file was removed again after the archive.
2. Upload with `xcodebuild -exportArchive -archivePath <archive> -exportOptionsPlist <copy of
   fastlane/ExportOptions.plist with destination=upload> -exportPath <new dir> -allowProvisioningUpdates` while Xcode
   is signed in to team `YLWWUD25VZ`. The next build number must be above 2026.11.1.

## Notes for testers

- The build installs over the App Store version and keeps existing wallets. Write down every wallet's recovery phrase
  before installing any test build.
- New to check: wallets with a `///password` (the universal-account notice, Switch, and Wallet details per network);
  importing a phrase with a non-ASCII password; the iPad layout in both orientations and at narrow window widths.
- Kaia history is unavailable in this build (no KaiaScan key).
- Never take screenshots of recovery phrases or keys; screenshots attached to TestFlight feedback are uploaded to
  Apple.
