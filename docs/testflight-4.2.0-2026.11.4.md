# TestFlight 4.2.0 (2026.11.4)

Status: **uploaded to App Store Connect on 3 November 2026 at 18:45 JST** (delivery
`6e7eb98c-1ef2-484b-8b34-a6c456afd666`) for internal TestFlight testing. App Store Connect reported no errors or
warnings and was processing the build when the upload finished. This is the build to submit for App Review.
2026.11.1, 2026.11.2 and 2026.11.3 stay on TestFlight, but on iPhone their Receive screen shows only its title bar.

**App Store version 4.2.0 is ready for the owner to submit (提出準備中, not submitted).** On 4 November 2026:
- At 03:58 JST, 2026.11.4 replaced 2026.11.3 as its build. App Store Connect asked no questions.
- The listing is updated:
  - new iPhone screenshots in the 6.9-, 6.5- and 5.5-inch groups (the required 6.3-inch size borrows them)
  - the description and keywords
  - What's New
- The iPad 13-inch screenshots are unchanged.

All of it was checked after a reload. The workspace's `build/reports/ios-appstore-connect-4.2.0-20261102/` holds the
evidence (`evidence-listing-chrome/`, `evidence-build-2026.11.4/`).

## Candidate

- Branch: `release/4.2.0` (PR #1312), archived at `5cdbd7221`.
- Bundle and version: `jp.co.soramitsu.fearlesswallet`, `4.2.0 (2026.11.4)`, iPhone and iPad (`UIDeviceFamily` 1 and
  2), `MinimumOSVersion` 15.0.
- Signing: Apple Distribution for team `YLWWUD25VZ` (certificate SHA-1 `84AB95335BE14CAE9B050A353910F86FF2F9539B`)
  with the App Store profile "Fearless App Store 2026.7.26" (`0d51265e-4b53-4a1f-814a-436dc9ca087b`).
- Service settings: `soramitsu/fearless-keys` 0.1.5 again, on the owner's OK, written to the ignored
  `fearless/env-vars.sh` and removed after the archive. TonAPI, WalletConnect, Etherscan and Alchemy accepted their
  keys on 2026-11-03 and Google accepted the backup client. The generated settings file has the same SHA-256 as the
  three earlier 4.2.0 builds (`10f2c5b4…49bd8`).

## What changed since 2026.11.3

- **Receive on iPhone** (`be7439958`). Since the Receive redesign (#1305, `cbc0b07c8`), the Receive screen on iPhone
  showed only its "Receive BTC" title bar: no QR code, address, Copy or Share.
  - Cause: the restyled layout gave its scrolling content no height, and the app's bottom sheet only bounds its top,
    so the sheet shrank to the title.
  - Fix: the content now asks for its own height at a priority below content hugging and compression resistance, so
    a full window lays out as before.
  - A new test presents Receive through the real bottom sheet in an iPhone-sized window; without the fix it fails.
    The earlier tests made Receive the window's root and never saw the sheet.
- **Send and history titles** (`1607edb8e`): "Send funds" and "All transactions" (were "Send fund" and "All
  transaction"); Indonesian "Kirim dana" (was "Dana terkirim", "Funds sent"); Portuguese "Enviar fundos" (was "Enviar
  fundo").
- **Build number 2026.11.4** (`5cdbd7221`): 2026.11.3 joins the consumed builds and becomes a supported in-place
  upgrade predecessor.

## Verification

All local (this project does not use hosted CI). Evidence: the workspace's `build/reports/ios-testflight-2026.11.4/`.

- Full `fearless.tests` suite at `5cdbd7221` (iOS 26.5 simulator, Xcode 27.2): 3,608 tests, 3,514 passed, 0 failed,
  94 skipped (the usual skips; one new test).
- Receive classes: 41 passed, 1 skipped. With the height at `.high` priority, two existing full-window tests squashed
  a segment to 0 points, which is why the priority is 200.
- Static release audits (9), the build number check (28 consumed builds, 7 tools agree) and 34 of 34 runnable script
  tests pass at `5cdbd7221`.
- Independent review by a Claude subagent: the fix holds for iPhone sheets, iPad cards, the keyboard, large text and
  rotation, and no other screen in this sheet lacks a height. Its findings (the Indonesian and Portuguese titles,
  intermediate commits that did not build) are fixed.
- Signed archive (`scripts/ci/build-audited-ios-release-archive.sh` at `5cdbd7221`, 09:35-09:42 UTC). Every gate
  passed: service settings before and after the build, release identity, the three storage audits,
  `** ARCHIVE SUCCEEDED **`, upload dSYMs and the signed-artifact audit. Archive tree SHA-256
  `737088b09a234b9c978bc797795e408556e88b7332c4c356096601d7a596689e`, app executable SHA-256
  `c72536213bba7ad4692e094037d0e69e76b88305ace97eaf9d4c5e65bc91cd3d`.
- App Store IPA export of the same archive: SHA-256 `90666552ae0cffac3d55f7d1d9360e0be2627b65c667ed457b82d75751bf071a`
  (101,018,763 bytes). The upload used `xcodebuild -exportArchive`, destination `upload`, with Xcode's signed-in team
  account. It ended with `UPLOAD SUCCEEDED with no errors`, state `PROCESSING`, and every analysis warning list was
  empty. Unlike 2026.11.3, no request timed out.

## Publishing again

As for 2026.11.3 (`docs/testflight-4.2.0-2026.11.3.md`): after writing `fearless/env-vars.sh`, regenerate
`CIKeys.generated.swift` with the settings loaded before running the archive script. The next build number must be
above 2026.11.4.

## Still open

- Submitting 4.2.0 for review is the owner's call.
- Polkadot and Kusama staking need #1312 on `master`: the app reads its network list from `fearless-iOS` master,
  which still marks the relay chains for staking and has no Asset Hub flag.
- No KaiaScan key (Kaia history unavailable), as in 2026.11.1.
- The Send screen's expanded warning shows the list's English name, category and subcategory in every language.
- Settings' wallet card shows fiat to eight decimals (for example `$229.39933598`).
