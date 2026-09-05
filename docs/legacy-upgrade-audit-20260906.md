# Legacy upgrade audit — 6 September 2026

Status: implementation and local regression qualification complete. **526 unique iOS tests and 41 separate TonSwift SDK tests pass.** Final app/test source hashes match the qualified snapshot. This source and synthetic-fixture audit does not certify distribution-signed upgrade acceptance.

## Fixed in the initial audit

- Legacy/partial universal-wallet snapshots permit normal account access. Export descriptors retain their wire format and no longer determine whether the original account can sign.
- Automatic Bitcoin/Taira enrollment adds only absent networks from the established stored recovery root. Existing dedicated keys/aliases, including independently imported keys, remain intact. Missing/unavailable recovery material leaves the legacy wallet usable and permits a later retry.
- Individual provisioning helpers reject replacement of an existing account rather than removing its row and inserting a different public key. Explicit root recovery retains its stronger phrase/identity checks.
- Derivation runs off the launch/selection thread. A conditional save checks the original wallet and the absence of pending user saves under the storage lock, so stale enrichment cannot overwrite an edited wallet or switch back to an earlier selection. Late completions do not republish a wallet after selection changes.

## Verification

Supported arm64 Release simulator: `E17D82E5-AE17-41BD-8B71-4E0704CE9DF3`, iOS 18.1. Build/test commands are recorded in each log. Artifacts are under `build/legacy-upgrade-20260906/`.

- `migration-tests-retry.xcresult`: 351 cases executed. 349 passed, one phone-scale profile skipped, one old expectation failed because it required destructive Taira replacement. All storage, selection, historical key migration and signing cases passed.
- `provisioning-verified.xcresult`: corrected the obsolete replacement expectation; all 51 account provisioning/address cases pass, with no new production changes after the preceding run.
- `scale-export-verified.xcresult`: enabled `FEARLESS_RUN_SUBSTRATE_PHONE_SCALE_PROFILE=1`; the 113,989-row historical migration and account-export case both pass.

Combined unique verified cases: **352 passed**, zero remaining failures/skips among these selected cases. Suites: SelectedAccountSettings (33), SigningWrapper (9), SingleToMultiassetUserMigration (23), SubstrateStorageMigrationSafety (115), UniversalWalletAccountAddressResolver (51), UniversalWalletMigrationContract (17), UserStorageCompatibilityMigration (103), AccountExportPassword (1).

New regressions cover stale edited/switched wallets, failure followed by successful persistence retry, pending-save rejection, independent Bitcoin/Taira keys, malformed preexisting network rows, additive enrollment and idempotence. Historical suites exercise compatibility fingerprints, crash/restart boundaries, key staging/verification, intact database replacement and exact wallet/account preservation.

The initial compile failure in `migration-tests.log` was confined to new test callback assertions and corrected before execution. The separate UX task's existing fresh-directory preparation changes were preserved. Tests use synthetic data; no production wallets, keys or transaction submissions were used.

## Native TON and TonConnect restoration

The custom wallet model now retains native TON-only legacy wallets without fabricating a Substrate identity. It uses the original v4R2 JSON address, public key, native secret and recovery phrase. Explicit native TON import supports the released valid phrase lengths up to 24 words, including an independently checked 12-word fixture. Fresh import keys are committed only after wallet persistence and rolled back if storage fails.

`ton-jetton-second.xcresult` executed 438 cases: 436 passed; two history error-path tests reported XCTest helper failures, subsequently corrected. The focused rerun passed all 62 cases: AccountImport 33, native TON 8, history 10, Jetton 7, and native pending journal 4. All initial 352 cases had passed in the broader rerun as well. The Jetton tests include independently generated TEP-74 payload vectors and intercepted TonAPI transport; no live transactions were submitted.

`tonconnect-foundation-verified.xcresult` passed all 32 cases: 22 TonConnect protocol/storage/HTTP transport/durable-reply tests plus all 10 history cases. Restored sessions retain their original keys; malformed historical rows remain preserved. The coordinator, approval/session UI, JS bridge, startup/Profile routing, `tc:` scheme and released `/ton-connect` link format are now integrated. The combined app compiles successfully. `legacy-full-tonconnect-verified.xcresult` passes all **516 tests**, zero failures, including the 113,989-row phone-scale fixture, native TON import, Jetton transfers, coordinator authorization, actual injected WKWebView provider, token-catalog aliases and transaction recovery. Test execution took 51.419 seconds. The local pinned TonSwift package separately passes **41/41** SDK tests, including independent exotic-cell vectors. Pre-4.0.4 sessions lack `connectionType`; released source proves that HTTP peers used 32-byte hex IDs and JS peers used UUIDs, allowing in-memory recovery without rewriting those records. See `legacy-tonconnect-restoration-plan-20260906.md`.

## Production identity

Apple's public lookup for app 1537251089 reports bundle identifier `jp.co.soramitsu.fearlesswallet`, matching current Release settings. Snapshot: `build/legacy-upgrade-20260906/app-store-identity.json`. The public 4.1.0 source tag's development bundle setting differs from the shipped identity, so it must not replace the verified production identifier. The existing signed-release audit also checks bundle, signing team and default Keychain access. Distribution-signed in-place upgrade acceptance remains required; simulator tests alone do not establish it.


## Additional compatibility findings

The all-assets TON balance path now reconciles an existing owner's Jetton-wallet asset ID with its authoritative master/wallet pair. It funds one existing row and zeros redundant known aliases, preserving the original row and avoiding duplicate totals. Newly discovered assets use master addresses only; another owner's private Jetton-wallet address is never introduced into global token metadata. Balance requests and catalog price/token injection now use the original chain snapshot rather than a later network-toggle selection. Catalog/alias regression tests pass in the 516-case combined run.

The released SSFQRService revision `b3e2bf1bc380d0e046b603921cbb63dcefb920cf` accepted both `tc:` and `/ton-connect` links. That source is the compatibility authority for link restoration. The current public TON wallet list no longer contains Fearless, so it is not used to infer or change historical wallet identity.

## Final compatibility follow-up

TON history now includes Jetton swaps, with both token amounts and decimal scales,
native TON network fees, pending/failure status and symbols retained after a token
balance reaches zero. A released owner-specific token-wallet identifier resolves
its master through the standard `get_wallet_data` owner/master fields; the owner
must match the selected account. Failed or malformed responses preserve cached
history for retry. All externally supplied BOCs use the bounded parser. Invalid
token decimal counts throw before conversion can trap.

TonConnect preserves the released protocol app name `Fearless`, `window.Fearless`
provider, `tc:` and `/ton-connect` entry points. A manifest may be hosted on a
separate HTTPS CDN, as allowed by the released implementation and the
[manifest specification](https://github.com/ton-blockchain/ton-connect/blob/main/spec/manifest.md).
Approval displays both application and manifest URLs when their origins differ.
JS requests remain bound to the displayed main-frame application origin.

`ton-history-links-final.xcresult` passed 53 of 54 cases. One new presentation
case expected two decimal places although the existing formatter renders three;
its expectations were corrected. The follow-up also adds a transfer-only filter
regression so unavailable swap alias lookup cannot block filtered transfers.
Final focused result: **55/55 passed**, zero failures, 1.599 seconds, in
`ton-history-links-verified.xcresult`. Combined with the initial 516-case run,
this verifies **525 unique iOS cases**, plus the separate **41 SDK cases**.
The final app/test source snapshot is `ton-history-links-source.sha256.json`.
The final focused run includes all original history and the updated TonConnect
protocol/coordinator/HTTP/WKWebView plus balance/catalog cases.

## Persisted session cosmetics

Released 4.1.0 `TonConnectManifest` decoding and `TonWebBridgePresenter` persistence
accepted empty/long names and HTTP icon URLs. Its reconnect response used the
stored account and ignored those cosmetic fields. The restored coordinator now
likewise keeps the original metadata unchanged and uses only the validated app
origin for public JS restore. Fresh connection manifest validation stays intact;
session public/private key binding, original wallet/network and main-frame origin
remain required. A targeted regression covers empty and long names, HTTP icons,
original testnet/address, no secret read or approval, unchanged stored session and
wrong-origin rejection. `ton-session-restore-verified.xcresult` passes **24/24**, zero failures, 0.629 seconds.
The final combined inventory verifies **526 unique iOS tests** (counting the
renamed manifest case once), with **41 separate SDK tests**. Machine-readable
case inventory: `verified-regression-case-inventory.json`. All final source
hashes match the captured snapshot; `git diff --check` passes.
Final source snapshot: `ton-session-restore-source.sha256.json`.
