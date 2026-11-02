# TestFlight 4.2.0 (2026.11.3)

Status: **uploaded to App Store Connect on 2 November 2026 at 13:25 JST** (delivery
`d021f6bd-3d94-4d53-b318-c13cc3aa54c6`) for internal TestFlight testing. App Store Connect was processing the build
when the upload finished. This is the build to submit for App Review; 2026.11.1 and 2026.11.2 stay on TestFlight.

## Candidate

- Branch: `release/4.2.0` (PR #1312), archived at `12e8fe7de`.
- Bundle and version: `jp.co.soramitsu.fearlesswallet`, `4.2.0 (2026.11.3)`, iPhone and iPad (`UIDeviceFamily` 1 and
  2), `MinimumOSVersion` 15.0.
- Signing: Apple Distribution for team `YLWWUD25VZ` (certificate SHA-1 `84AB95335BE14CAE9B050A353910F86FF2F9539B`)
  with the App Store profile "Fearless App Store 2026.7.26" (`0d51265e-4b53-4a1f-814a-436dc9ca087b`).
- Service settings: `soramitsu/fearless-keys` 0.1.5 again, on the owner's OK, written to the ignored
  `fearless/env-vars.sh` and removed after the archive. TonAPI, WalletConnect, Etherscan and Alchemy accepted their
  keys on 2026-11-02 and Google accepted the backup client. The generated settings file has the same SHA-256 as
  2026.11.1's and 2026.11.2's (`10f2c5b4…49bd8`).

## What changed since 2026.11.2

All of it concerns the warnings for recipients on the scam list (`remote-config/production/scamDetection`, read from
`master`):

- **The confirm screen's warning sheet** (`e120f1b03`). Tapping the warning next to a flagged recipient opened a sheet
  titled with the sanctions sentence for every kind of flag, in every language, since 2022 (`040d19653`). It is now
  titled "Warning" and repeats the Send screen's warning for that flag. A flag the app does not recognise gets the
  general advice. The unused sanctions title is deleted.
- **Every category in the list has its own warning** (`76053aa11`). The list has 24,291 rows in seven categories.
  Service (42 financial services, wallet providers and custodians), High Risk Organization (35 high-risk exchanges)
  and Theft (3 hacks) were read as unknown, so the Send screen gave no explanation and a custodian got "don't send"
  advice. A service now gets the same care note as an exchange, and the other two advise against sending.
- **A hidden phishing address** (`76053aa11`). Rows were split on every comma, so the one quoted name
  (`"Polkadot2022 Net, Polkadotevent2022"`) pushed its phishing address into the type column, and that address was
  never flagged. The list is now read as CSV.
- **Donations, theft and translations** (`724ab23bf`, `f3a8d0df2`, `12e8fe7de`). Both Donation rows are charities,
  but their warning called the address suspicious and advised against sending. It now says the address is a
  charity's and asks the user to make sure they mean to donate. Theft is highlighted in red like a scam. The
  low-activity warning was English in all eight other languages and is now translated. The Japanese warnings are
  reworded to read naturally, and Russian and Simplified Chinese wording is fixed.
- **Stored flags survive bad downloads** (`f3a8d0df2`, `12e8fe7de`):
  - A flag type stored by a newer build reads as unknown instead of failing every stored flag.
  - Any line ending is accepted.
  - An empty or unreadable download keeps the stored flags instead of deleting them all.
  - A damaged byte costs only its own row.
- **Build number 2026.11.3** (`82deb545d`): 2026.11.2 joins the consumed builds and becomes a supported in-place
  upgrade predecessor.

## Verification

All local (this project does not use hosted CI). Evidence: the workspace's `build/reports/ios-testflight-2026.11.3/`.

- Full `fearless.tests` suite at `12e8fe7de` (iOS 26.5 simulator, Xcode 27.2): 3,607 tests, 3,513 passed, 0 failed,
  94 skipped (the usual count).
- The new tests fail on the old code:
  - With the old presenter and strings, the sanctions title, the English low-activity text and the missing full stop
    each fail a test.
  - With the old comma split, the quoted row's address and the production list's unknown flag each fail a test.
- Static release audits (9), the build number check and 34 of 34 runnable script tests pass at `12e8fe7de`.
- Independent review in three rounds by a Claude subagent; each round's findings are fixed in the next commit.
- Signed archive (`scripts/ci/build-audited-ios-release-archive.sh` at `12e8fe7de`, 04:13-04:21 UTC). Every gate
  passed: service settings before and after the build, release identity, the three storage audits,
  `** ARCHIVE SUCCEEDED **`, upload dSYMs and the signed-artifact audit. Archive tree SHA-256
  `1430fe4c5c73bdf913f0216cd27b76c99bb4f72361d8b5349af036f0527d1a58`, app executable SHA-256
  `cff99b82659a5295dcf8ff21c92e42d18d61e2e508f32dac40fcd749f7418219`.
- App Store IPA export of the same archive: SHA-256 `2f6d22f1a57f76f9f3cabbdd9f79c0a83d6951bcf113542473aeaa5b1d8bfaa0`
  (101,017,517 bytes). The upload used `xcodebuild -exportArchive`, destination `upload`, with Xcode's signed-in team
  account. It ended with `UPLOAD SUCCEEDED with no errors, 2 warnings`, state `PROCESSING`, and every analysis
  warning list was empty.
  - Both warnings were App Store Connect requests that timed out (NSURLError -1001), so Xcode skipped its pre-upload
    validation.
  - 2026.11.2 passed that validation. Since then only Swift code, strings, scripts, docs and the build number have
    changed.

## Publishing again

As for 2026.11.2 (`docs/testflight-4.2.0-2026.11.2.md`): after writing `fearless/env-vars.sh`, regenerate
`CIKeys.generated.swift` with the settings loaded before running the archive script. The next build number must be
above 2026.11.3.

## Still open

- Polkadot and Kusama staking need #1312 on `master`: the app reads its network list from `fearless-iOS` master,
  which still marks the relay chains for staking and has no Asset Hub flag.
- No KaiaScan key (Kaia history unavailable), as in 2026.11.1.
- The Send screen's expanded warning shows the list's English name, category and subcategory in every language.
- A TestFlight tester who goes back from 2026.11.3 to 2026.11.2 loses, in that older build, the warnings for the 80
  addresses 2026.11.3 newly recognises: 2026.11.2 cannot read their stored types.
