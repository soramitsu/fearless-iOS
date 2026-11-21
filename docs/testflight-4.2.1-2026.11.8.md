# TestFlight 4.2.1 (2026.11.8)

**Status:** submitted for App Review on 8 November 2026 at 10:00 KST (01:00 UTC), under submission `41fe8d21-14dc-4282-8ab4-959d28439355`. A fresh App Store Connect read at 14:30:41 KST (05:30:41 UTC) confirmed **WAITING_FOR_REVIEW**, build **VALID**, and **MANUAL** release. This is a submission, not a public release.

- **Upload:** 09:46 KST (00:46 UTC); processed by 09:50 KST (00:50 UTC). Delivery/build ID `6c212da9-b565-4197-9bac-5214391c254e`.
- **TestFlight:** internal testing `IN_BETA_TESTING` after processing. Not submitted for external beta.
- **Export compliance:** complete; no non-exempt encryption.

## Why this build replaced 2026.11.7

[2026.11.7](testflight-4.2.1-2026.11.7.md) removed the non-open-source WalletConnect SDK, its UI and its stored sessions. The owner then requested WalletConnect support with pairing and signing. This build restores it using the app's own open-source client and removes the one-time session wipe. The key-exposure fixes and the removal of `sorawallet`, Reown, `yttrium` and the unlicensed `ton-api-swift` remain.

The review submission carrying 2026.11.7 was cancelled, 2026.11.8 was attached, and 4.2.1 was resubmitted. What's New stayed byte-identical and release remained manual. Build 2026.11.7 was never publicly released; internal testers who ran it must pair dApps again because its cleanup already removed their sessions.

## Source and artifacts

- **Branch:** `hotfix/4.2.0-polkaswap-usability`.
- **Exact source commit:** `698f4223672f42516933197db7af75fee12eab7e`.
- **Review:** [PR #1315](https://github.com/soramitsu/fearless-iOS/pull/1315) carries the release line to `master`; [PR #1321](https://github.com/soramitsu/fearless-iOS/pull/1321) records the earlier key-exposure fixes.
- **App:** `jp.co.soramitsu.fearlesswallet`, 4.2.1 (2026.11.8), iPhone and iPad.
- **Service settings:** from `fearless-keys` 0.1.5, including the WalletConnect project ID required by the relay. The ignored `fearless/env-vars.sh` was removed after archiving, and keyless generated settings were restored.

The signed archive passed clean-source, release identity, service configuration, production entitlement and signing-profile checks. Its team is `YLWWUD25VZ`, with profile `Fearless App Store 2026.7.26`. Inspection found the in-repo WalletConnect client and no Reown, `yttrium` or `sorawallet` framework or implementation.

| Artifact | SHA-256 |
| --- | --- |
| Archive tree | `375a2eaa1a9841646e63e40723f13586aaab46afaae6f3678be876f3a459c040` |
| App executable | `2695ec6a65b1779e32e02dbe6024f480926c23f0fa8be1f92484b37609fb8e34` |
| Exported IPA, 95,416,777 bytes | `07c5a7e03fad5c4989cfb441b015c013494a697c5b0c3e64c7629fb010ac7dc9` |

The temporary IPA sent by altool was byte-identical to the audited export. altool reported a successful upload; Fastlane subsequently returned an error about its local resume file. The upload was confirmed server-side and was not repeated. The receipt binds the source commit, archive, executable, export and delivery ID. On takeover, the retained IPA, executable, archive tree and receipt hashes were checked again and matched; deep/strict code-signature verification also passed (`takeover-artifact-integrity-20261108.json`).

## WalletConnect behavior

`Packages/FearlessWalletConnect` implements the wallet side of WalletConnect v2 using Swift and Apple frameworks, with no external package dependencies. It imports earlier WalletConnectSwiftV2 and Reown sessions, pairings and relay identity. Pairing works through QR codes, `wc:` links and `fearless://wc?uri=` links.

- EVM methods: `personal_sign`, `eth_signTypedData`, `eth_signTypedData_v4`, `eth_signTransaction` and `eth_sendTransaction`.
- Polkadot methods: `polkadot_signMessage` and `polkadot_signTransaction`.
- Every signature requires fresh PIN or trusted biometric authorization. Requests are bound to the session's approved account and network.
- Confirmations display the site reported by WalletConnect Verify; unverified sites receive a warning and scam attestations are declined.
- Typed values are parsed and canonicalized before both display and hashing. Transfers, approvals, standard permits and nested Substrate calls receive readable confirmation details. Undecoded data is shown with a warning; requests too large to show completely are declined.
- Remote switches `evm_dapp_signing_enabled`, `polkadot_dapp_signing_enabled` and `ton_dapp_signing_enabled` can veto signing. TON uses TON Connect, including its transaction and `ton_proof` paths.
- Forget wallet disconnects sessions granting its accounts. Logout clears local sessions and pairings before attempting peer notifications.

## Local validation

The evidence root in the Fearless workspace is `build/reports/ios-key-exposure-fixes-20261107/`. WalletConnect-specific evidence is in `build/reports/walletconnect-on-4.2.1-20261108/` within the WalletConnect implementation worktree. These checks ran locally.

| Check | Source | Result |
| --- | --- | --- |
| Full `fearless.tests`, iOS 27.0 simulator | `7f8276acf` | 3,846 tests, zero failures, 76 skipped |
| Focused WalletConnect and related hosted tests | `7f8276acf` | 390 tests, zero failures; two require the live-relay environment |
| Live real-signature verification | `7f8276acf` | Passed against the reference dApp |
| Production-project relay interoperability | `698f42236` | Passed: pairing, response, refusal, ping, disconnect and proposal rejection |
| Release numbering, identity, artifact, signing, service configuration and usability checks | `698f42236` | Passed |
| Historical 4.0.4 Keychain continuity (G5) | `698f42236` | 12 cells × six tests; zero failures or skips |

`698f42236` changes only release numbering and release-script files on top of `7f8276acf`; it does not change the application or WalletConnect logic covered by the full suite. The full suite is attributed to its actual tested commit, while the G5 tests and archive checks ran at the exact release commit.

Independent security review ran through three rounds and a final check. Fixes included the app-lock bypass, misleading approval/permit displays, incomplete nested-call displays, stale requests, session cleanup, pairing-key replacement and typed-data values whose displayed form could differ from their hash. The final check at `7f8276acf` found no further defect in that change set.

### Historical upgrade evidence and scope

G5 covers six 4.0.4 writer profiles—mnemonic roots, curves/derivation paths, raw seeds, JSON, per-chain and TON—on iOS 26.5 and 27.0. Each test runs on a clone; the original fixtures are never booted. At `698f42236`, every cell passed its six mapper, migration, signing, export and PIN checks, preserving the historical snapshot and store.

**G5 does not exercise normal startup.** Its test scheme passes `-UNITTEST`, which returns early from `AppDelegate`. The earlier 2026.11.7 note overstated this coverage and has been corrected.

Separate normal-launch checks install the release source's Debug simulator app without `-UNITTEST`, allow startup through the existing-wallet PIN screen, and compare the Keychain before and after. **All 12 cells passed**, combining 11 original passes with the completed `chain-26` retry. The app's wallet-key rows remained byte-identical, with none removed or added.

`chain-26` initially could not launch under severe host load and subsequently lost its simulator boot state. After the host restarted, the same retained clone and installed app launched successfully, stayed alive, and visibly reached the unlock PIN screen. All 16 Keychain key rows were unchanged, including all 14 in the app's access group; app generic passwords remained at zero. No source change was needed. Evidence is under `g5/launch-698f42236/` and `g5/takeover-chain-26/`, including `result.json` and `chain-26-launch.png`.

The host restart removed the temporary simulator build directory. The final retry therefore uses the earlier install receipt and the retained installed app as provenance, rather than a fresh rebuild. Its Debug simulator executable SHA-256 is `c754cde56dd442d1852f1811d6db23f503b17ae56d7b13cae864f8a862a2b521`. This is distinct from the signed production executable and IPA recorded above.

## Limits

- No physical-device or funded-wallet validation was performed for this release. Simulator signing and relay checks are not on-device transaction validation of the uploaded IPA.
- Normal-launch checks stop at the PIN screen. They do not cover post-unlock startup or the WalletConnect importer. The WalletConnect lane separately tested importing real Reown 4.2.x simulator storage across a normal launch.
- iOS 18.1 could not host the simulator tests because of a pre-existing `libswiftCompatibilitySpan.dylib` compatibility issue; the full suite ran on iOS 27.0.
- Unknown contracts may be identified only by selector, XCM `Transact` byte payloads are not decoded, and a page can occupy five proposal slots until they expire. A Keychain read failure during logout leaves WalletConnect cleanup incomplete and is logged.
- What's New still describes the earlier Polkaswap changes. Public release remains manual.

## Evidence receipts

Relative to the evidence root:

- `asc-takeover-status-20261108.json`: fresh read of build and review status.
- `takeover-artifact-integrity-20261108.json`: reverified artifact hashes and code signature.
- `asc-swap2-1-cancel-review.json` through `asc-swap2-4-verify.json`: review replacement and submission receipts.
- `release/698f422367-20261108T003317Z/signed-archive-audit.json` and `upload-receipt.json`: source and artifact binding.
- `g5/cells-head-698f42236/`: exact-release G5 results.
- `wc-live-698f42236/`: exact-release relay interoperability check.
