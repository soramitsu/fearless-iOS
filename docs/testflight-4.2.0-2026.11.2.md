# TestFlight 4.2.0 (2026.11.2)

Status: **uploaded to App Store Connect on 1 November 2026 at 22:43 JST** (delivery
`293c41cf-503e-43a0-b8b9-ba47b10f9c02`) for internal TestFlight testing. App Store Connect reported no warnings and
was processing the build when the upload finished. 2026.11.3 (`docs/testflight-4.2.0-2026.11.3.md`) replaced it as
the build to submit for App Review; 2026.11.1 (`docs/testflight-4.2.0-2026.11.1.md`) and 2026.11.2 stay on TestFlight.

## Candidate

- Branch: `release/4.2.0` (PR #1312), archived at `ab9afa627`.
- Bundle and version: `jp.co.soramitsu.fearlesswallet`, `4.2.0 (2026.11.2)`, iPhone and iPad (`UIDeviceFamily` 1 and
  2), `MinimumOSVersion` 15.0.
- Signing: Apple Distribution for team `YLWWUD25VZ` (certificate SHA-1 `84AB95335BE14CAE9B050A353910F86FF2F9539B`)
  with the App Store profile "Fearless App Store 2026.7.26" (`0d51265e-4b53-4a1f-814a-436dc9ca087b`).
- Service settings: `soramitsu/fearless-keys` 0.1.5 again, on the owner's OK, written to the ignored
  `fearless/env-vars.sh` and removed after the archive. TonAPI, WalletConnect, Etherscan and Alchemy accepted their
  keys on 2026-11-01 and Google accepted the backup client. The generated settings file has the same SHA-256 as
  2026.11.1's (`10f2c5b4…49bd8`).

## What changed since 2026.11.1

Found while making the iPad App Store screenshots:

- **Address warnings name the asset again** (`f66264944`, `bf80e5bd8`). Since #1305 the English, Vietnamese and
  Simplified Chinese scam warning read "don't send {asset} to this account": `{asset}` is not a format specifier, so
  the asset name was dropped. Turkish put the asset mid-word in all three address warnings and in the confirmation
  alert, Russian showed three warnings in English, and the English exchange warning read "may different". A new test
  formats every address warning and the alert in every bundled language.
- **Transfer tab shows user-facing text** (`53956d127`, `ab9afa627`). Route rows listed AssetKey and route-asset
  UUIDs, protocol names and the SSFXCM limitation in engineering terms. Each row now gives one reason: "Not available
  in this version of Fearless." (translated in every bundled language), "Retired: DOT and KSM now live on Asset Hub,
  and the networks no longer accept this transfer.", or the SORA pause notes. Providers are named by the networks
  they connect. A new test rejects identifiers and protocol vocabulary in every row.
- **Build number 2026.11.2** (`bc7bb85d1`, `43ad3eda0`): 2026.11.1 joins the consumed builds and becomes a supported
  in-place upgrade predecessor.

## Verification

All local (this project does not use hosted CI). Evidence: the workspace's `build/reports/ios-testflight-2026.11.2/`.

- Full `fearless.tests` suite at `ab9afa627` (iOS 26.5 simulator, Xcode 27.2): 3,598 tests, 3,504 passed, 0 failed,
  94 skipped (the usual count). The five new tests fail on the 2026.11.1 code and pass now.
- Static release audits (9), the build number check and 34 of 34 runnable script tests pass at `ab9afa627`.
- Independent review of the fixes (a Claude subagent; Codex is signed out). Its findings are fixed in `43ad3eda0`,
  `bf80e5bd8` and `ab9afa627`.
- Signed archive (`scripts/ci/build-audited-ios-release-archive.sh` at `ab9afa627`, 13:32-13:41 UTC). Every gate
  passed: service settings before and after the build, release identity, the three storage audits,
  `** ARCHIVE SUCCEEDED **`, upload dSYMs and the signed-artifact audit. Archive tree SHA-256
  `e85c91f8bd574bcca345d307de6dc30e64394a149f02499373a98538476343d1`, app executable SHA-256
  `26b060586c06cbdeb58bb526fde988e5e8993815797e0375d14e0b0efdd63ee9`.
- App Store IPA export of the same archive: SHA-256 `d81bb5965c9d5b8dd903220890f9f0d0b18c895eb48c18ed9ce41ace75dc2df8`
  (101,008,277 bytes). The upload (`xcodebuild -exportArchive`, destination `upload`, Xcode's signed-in team account)
  ended with `UPLOAD SUCCEEDED with no errors`, every analysis warning list empty, state `PROCESSING`.

## Publishing again

As for 2026.11.1 (`docs/testflight-4.2.0-2026.11.1.md`), with one addition: after writing `fearless/env-vars.sh`,
regenerate `CIKeys.generated.swift` with the settings loaded (`set -a; . fearless/env-vars.sh; set +a; python3
scripts/ci/generate-ios-service-configuration.py`) before running the archive script. Its first gate audits the
generated file, and a stale keyless one fails with "missing required setting". The next build number must be above
2026.11.2.

## Still open

- Polkadot and Kusama staking need #1312 on `master`: the app reads its network list from `fearless-iOS` master,
  which still marks the relay chains for staking and has no Asset Hub flag.
- No KaiaScan key (Kaia history unavailable), as in 2026.11.1.
- The scam confirmation alert's title had been the sanctions sentence for every flag type since 2022, in every
  language. Fixed in 2026.11.3.
