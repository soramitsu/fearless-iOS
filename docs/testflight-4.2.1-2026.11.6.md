# TestFlight 4.2.1 (2026.11.6)

Status: **submitted for App Review on 7 November 2026 at 19:06 JST (Waiting for Review, manual release)**; see
"App Review". Uploaded at 11:57 JST and processed by 12:01 JST (VALID), delivery
`e5d47d08-2967-47f2-89bf-b5b79504dbc9`. Internal TestFlight testing state: IN_BETA_TESTING. Export compliance is
complete (no non-exempt encryption). Not submitted for external beta.

## Why 4.2.1

On 7 November 2026 App Store Connect listed 4.2.0 as **Pending Developer Release** with build 2026.11.5: Apple has
approved it and the release is manual. An approved version takes no new uploads, so the Polkaswap fixes ship as
4.2.1. **2026.11.5 has the three Polkaswap defects below; releasing 4.2.0 as approved ships them to every App Store
user.** The owner chose to withdraw 4.2.0 and submit 4.2.1 instead.

## Candidate

- Branch: `hotfix/4.2.0-polkaswap-usability` (PR #1315 to `master`), archived at `6e6a104f8`.
- Bundle and version: `jp.co.soramitsu.fearlesswallet`, `4.2.1 (2026.11.6)`, iPhone and iPad.
- Service settings: `soramitsu/fearless-keys` 0.1.5 again, written to the ignored `fearless/env-vars.sh` and
  removed after the archive. TonAPI, WalletConnect, Etherscan, Alchemy and Alchemy history accepted their keys on
  2026-11-07, and Google did not reject the backup client. The generated settings file has the same SHA-256 as the
  4.2.0 builds (`10f2c5b4…49bd8`).

## What changed since 2026.11.5

All three regressions came in with #1305.

- **Token picker** (`3c9ccba2d`). The Polkaswap asset sheet stretched its search field over most of the screen.
  `SearchTextField` took its size from an unused content view, which reported a zero height, and #1305 replaced its
  fixed height with a 44 pt minimum. It now reports and hugs its own height. The sheet's list and its empty state
  share a container. Every selection sheet built on `SelectableListViewLayout` benefits.
- **Confirm button** (`3c9ccba2d`). Polkaswap became a tab in #1305. Preview pushed the confirmation inside it, where
  the tab bar and the raised Polkaswap button covered Confirm and the header sat under the status bar. The
  confirmation now hides the tab bar, and its header and button stay inside the safe area.
- **Quotes** (`c9bca8952`). A quote could take minutes. Each SORA block (about 6 s) cancelled the pending request,
  hid the shown quote and asked again, and only the newest request's reply was accepted. Every reply slower than a
  block was thrown away. Now:
  - A reply that answers the inputs on screen is shown unless a newer one is already shown.
  - Block refreshes keep the quote and send nothing while a reply is awaited.
  - Quotes go straight to the SORA socket.
  - Typing waits 0.3 s instead of 0.8 s.
  - Stale block subscriptions are ignored.

  In the simulator, against the production SORA nodes, the time from keystroke to quote fell from about 1.8 s to
  0.69 s.
- **Build 2026.11.6, version 4.2.1** (`cc8e3ec1c`, `1092c5e17`, `6e6a104f8`).

## Verification

All local (this project does not use hosted CI). Evidence: the workspace's `build/reports/ios-testflight-2026.11.6/`.

- Full `fearless.tests` at `cc8e3ec1c` (iOS 26.5 simulator, Xcode 27.2):
  - 3,624 tests: 3,529 passed, 94 skipped, 1 failed.
  - The skips are the same 94 as 2026.11.5's run. 3,624 is 2026.11.5's 3,619 plus 5 new tests.
  - The failure is the load-sensitive `PinPersistenceTests.testActualNavigationPopFencesPendingPinChangeCompletion`.
    It passed 3 of 3 alone, and its class passed 15/15.
- The new tests fail on the previous code:
  - The search field measured 653 pt.
  - A tap on Confirm reached a tab button.
  - The awaited quote reply was discarded.
- Static release audits: 9/9 passed. Script tests: all passed or explained (see the evidence README).
- Signed archive (`scripts/ci/build-audited-ios-release-archive.sh` at `6e6a104f8`, 02:31-02:51 UTC). Every gate
  passed:
  - service settings before and after the build, and the release identity 4.2.1 (2026.11.6);
  - the historical, Substrate and user storage model audits;
  - `** ARCHIVE SUCCEEDED **` and the dSYMs;
  - the signed-artifact audit.

  Archive tree SHA-256 `a4b44d3cd5f57b77bc31f3edca63d6e3a4d8894dcbd422de744cb138446758ae`, app executable SHA-256
  `d77d1ef971c20a582da683281dccb1b475506308c417d1185418213da17f50c3`.
- App Store IPA export of the same archive: SHA-256
  `1a51c2e1968a4c3c192ddb15d40f2b05b03f673d71a1c7cc996cfea4ce1eeb42` (101,038,649 bytes).
- Upload with Fastlane pilot 2.238.0 and the App Store Connect API key. altool reported `UPLOAD SUCCEEDED with no
  errors`, delivery `e5d47d08-2967-47f2-89bf-b5b79504dbc9`. The temporary IPA it sent had the same SHA-256 as the
  export. Fastlane then exited 1 over altool's local resume-file message, as with 2026.11.5. App Store Connect
  listed the upload as PROCESSING with no errors or warnings, and nothing was uploaded twice.

## App Review

On the owner's word ("Submit 4.2.1", then "Yes, withdraw 4.2.0"), through the App Store Connect API on 7 November
2026 (UTC):

1. 10:04: 4.2.0 removed from review. That version is Developer Rejected, and its approval is gone.
2. 10:05: the same version record renumbered to 4.2.1 with build 2026.11.6. It keeps 4.2.0's approved texts and
   screenshots. What's New is unchanged ("What's new in 4.2"), which still fits users coming from 4.0.4.
3. 10:06: submitted. Review submission `b76f4826-43fb-4feb-a054-f14792846b0c` is Waiting for Review, and the release
   is manual.

A read-back at 10:06 showed 4.2.1 as the only iOS version in flight and 4.0.4 still live. Receipts are in the
evidence folder (`asc-submit-*.json`).

## Still open

- App Review of 4.2.1. After approval it waits for the owner's manual release.
