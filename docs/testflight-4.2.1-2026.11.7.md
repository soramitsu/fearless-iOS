# TestFlight 4.2.1 (2026.11.7)

**Status:** submitted for App Review on 8 November 2026 at 01:11 JST (16:11 UTC on 7 November). It is Waiting for Review, with manual release. Review submission `b97d39c9-6972-4bff-af3b-0c0952d28644`.

- **Upload:** 01:00 JST. Processed by 01:09 JST (VALID). Delivery `2a6d0ad4-26c1-49d0-910b-9538cc4acef0`.
- **TestFlight:** internal testing IN_BETA_TESTING. Not submitted for external beta.
- **Export compliance:** complete; no non-exempt encryption.

## Why 2026.11.7 replaced 2026.11.6 in review

4.2.1 (2026.11.6) was Waiting for Review. Like 4.2.0, it still contained the emergency recovery screen that exported every stored wallet secret, including deleted wallets' secrets, as plain text.

On 7 November the owner asked for every key-exposure finding to be fixed and for no closed-source library to remain. They chose to replace the build in review.

The swap was:
1. 4.2.1 was removed from review (Developer Rejected).
2. Build 2026.11.7 was attached. What's New stayed byte-identical; release stayed manual.
3. 4.2.1 was resubmitted.

The only iOS version in flight is 4.2.1 with 2026.11.7; 4.0.4 is still live.

## Candidate

- **Branch:** `hotfix/4.2.0-polkaswap-usability` at `66178be055a8fe12bd280e3197431cb8817aaad2`, which includes PR #1321. PR #1315 takes it to `master`.
- **Bundle and version:** `jp.co.soramitsu.fearlesswallet`, 4.2.1 (2026.11.7), iPhone and iPad.
- **Service settings:** from `soramitsu/fearless-keys` 0.1.5, without the WalletConnect project ID, which the app no longer uses. They were written to the ignored `fearless/env-vars.sh` and removed after the archive.

## What changed since 2026.11.6

See PR #1321 for details.

**Closed-source and non-open-source code removed:**
- The Kotlin/Native `sorawallet` framework. Polkaswap pool APY is now Swift.
- WalletConnect (`reown-swift`, WalletConnect Community License), with the prebuilt `yttrium` binary. A one-time clean-up deletes only WalletConnect's own Keychain session items and defaults.
- `ton-api-swift` (no licence). It is replaced by `Packages/TonAPI`, generated here from the MIT opentonapi spec; the generated code is byte-identical to the old client.

**Key-exposure fixes:**
- The emergency export is a password-encrypted file; `scripts/recovery/decrypt-emergency-material.py` opens it.
- Forget wallet (now PIN-gated) and logout erase backed-up wallets' Keychain secrets.
- PIN lockout with backoff, and biometric enrollment checks.
- A 5-minute monotonic re-lock.
- PIN or biometrics before every fund-moving submission.
- Protected, removed export files, and an 8-character JSON export minimum.
- An SVG filter before SVGKit.
- Seed share without Copy; secrets hidden during screen capture; keyboard extensions refused.
- TON Connect never signs a proof for a site its manifest does not come from, and has a veto-only kill switch.

**Build supply chain:** every SwiftPM checkout is verified against its pin, and the pods plus the `rswift` and `swiftformat` executables are pinned by digest, before any build tool runs.

## Verification

All checks ran locally; this project does not use hosted CI. Evidence is in the workspace's `build/reports/ios-key-exposure-fixes-20261107/`.

- **Full `fearless.tests`** (iOS 27.0 simulator, Xcode 27.2): 3,647 tests, 76 skipped, 4 failed.
  - 3 are the known unsigned-build Keychain tests.
  - 1 was an over-strict new assertion, fixed and re-run.
- **After the in-repo TonAPI switch:** 563 tests in 44 classes pass.
- **Release scripts:** the build-number check, the identity, signed-artifact and signing-contract audits, and the usability gate pass.
- **Archive at `66178be05`:** the clean-HEAD, identity and service-configuration gates pass.
  - The signed audit shows the production team, profile and entitlements.
  - Archive tree `48a55d78…01dfb0`, executable `e65916f3…f1b3`.
  - The app embeds no `sorawallet`, Reown, WalletConnect or `yttrium` file, link or symbol.
- **IPA:** SHA-256 `e1142ef2795026cac6846e668e5c04179387f515382143f2be4609763f840222`, 93,955,869 bytes. The uploaded temporary IPA is byte-identical.
- **4.0.4 Keychain continuity (G5) at `52b2e26b6`: 12 of 12 cells pass.** The cells cover six 4.0.4 writer profiles on iOS 26.5 and 27.0, each with the 6 named tests passing, none skipped, and the old snapshot and store byte-identical. The test host runs this build's launch clean-ups against the Keychain 4.0.4 wrote.

## Not verified

- Not run on a physical device or with a funded wallet.
- Each intermediate commit was not built on its own; the final tree was.
