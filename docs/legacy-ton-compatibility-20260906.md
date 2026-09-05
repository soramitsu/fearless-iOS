# Native TON compatibility investigation — 6 September 2026

Status: native TON, Jetton, TonConnect and migration implementation qualification is complete, with 526 unique iOS tests and 41 separate SDK tests passing. The final additional swap-history and released manifest/link compatibility follow-up is recorded in `legacy-upgrade-audit-20260906.md`. Historical intermediate runs below are retained as diagnostic evidence and are superseded by the final combined run.

## Released storage contract

The iOS `4.1.0` tag pins `shared-features-spm` revision `b3e2bf1bc380d0e046b603921cbb63dcefb920cf`. Its TON creation/import operation uses native TonSwift `Mnemonic`, Wallet V4R2 and the `.v4R2` contract version. The keychain entries are `<metaId>-tonSecretKey` (64-byte Ed25519 seed plus public key) and `<metaId>-entropy` (the exact UTF-8 native TON phrase). They are not the BIP39 entropy/SLIP-0010 format used by newer universal TON accounts. The original `tonAddress` bytes are JSON-encoded `TonSwift.Address` with workchain and hash; arbitrary 36-byte fixtures do not model a released address.

The old SSF model can read `.v5R1`, but no reachable app writer or version selector was found in released 4.1.0. Its create/import/onboarding/confirmation paths and the pinned SSF factory all construct V4R2. Tags 4.0.2, 4.0.4 and 4.0.5 also contain no V5 writer. Unknown contract versions remain preserved, safely unsupported, without replacing their addresses.

## Implemented compatibility

- Real optional Substrate roots allow a valid native TON-only wallet without a fabricated Substrate identity. Mapper validation checks the native public key against its exact V4R2 address and preserves the original address bytes on saves and edits.
- Repository filtering now delegates supported-root decisions to the tolerant mapper, retaining TON-only selection and startup access. TON account fetches return the original account identifier; address parsing accepts the released JSON representation for balance and existing address-conversion paths.
- Original 64-byte keys are validated against both stored public key and address. A genuinely absent key may be recovered from the original native phrase; corrupt existing keys never silently switch derivation. Native phrase export preserves exact stored UTF-8 text, including casing.
- Universal BIP39 enrollment skips native TON-only entropy. It cannot reinterpret a native TON phrase or invent new recovery material.
- Native TON send uses the original key with exact sender binding through the existing rendered fee confirmation, unsigned template, signed emulation and durable pending-BOC recovery. Unqualified new universal TON send remains separately gated. No transaction has been submitted to a live service during this audit.

## Verification status

`ton-compat-fourth.log` compiled the whole app and test bundle. All 107 preexisting selected tests passed; three new native fixtures had four assertion failures (uppercase normalization, simulator keychain availability, and a missing required fixture property). The fixes retain exact stored phrase text while normalizing only native derivation, inject the real durable journal codec backed by a synthetic test keystore, and populate required Core Data fixture fields.

`ton-core-verified.log` compiled the app but failed compiling an unrelated concurrently changed UI test's view visibility. The UI task subsequently corrected the visibility. `ton-core-final.log` was deliberately interrupted before execution to avoid concurrent import-source changes. These incomplete runs are not counted as passing regression evidence.

New tests cover exact SQLite v13-to-v14 migration and two independent reopens, mapper rename/save and repository lookup, optional-root Codable and replacement helpers, exact wallet/per-address phrase export, old key-only and phrase-only retrieval, corrupt-key rejection, no automatic universal derivation, production quote-before-secret access, exact signed BOC persistence and broadcast through a fake transport.

## Previously identified gaps — resolved and qualified below

- Re-ran all initial migration/sign/export suites plus native compatibility and recovery import tests in the 516-case combined run.
- Restored Jetton transfers with typed TEP-74 intent binding through the same quote/journal coordinator. Historical asset IDs name sender Jetton wallets; current injected IDs name Jetton masters, so reviewed owner-wallet resolution is necessary.
- The original native emulation rejected every child trace, excluding legitimate delivered transfers. Qualified bounded linked traces without weakening exact root message binding or allowing additional asset risk.
- Restored TON history provider routing with exact account-events transport and legacy/current token identifiers.
- Restored TonConnect runtime/session functionality, routing and Profile selection, with the original stored session identity.

All test material comes from public synthetic upstream vectors. No production keychain or wallet secrets were read.

### Combined core qualification

`ton-core-import-verified.xcresult` compiled the complete Release app and test targets and executed 421 selected cases: **419 passed**, with two new fixture failures. All 352 previously verified migration/selection/sign/export cases pass again, including the enabled 113,989-row scale case. The eight native key/export/production-send tests, 34 selection tests, 23 TON builder tests and four durable pending-journal tests pass. Failures are an expected public-key hex string containing an extra `0x` in the new import test, and the new SQLite native reader attempting to change a model class after opening a store made that model immutable. Both require fixture correction and a rerun; they are not counted as passed. Machine-readable suite counts are in `build/legacy-upgrade-20260906/ton-core-import-results.json`.

Released native import accepted SDK-valid phrases of up to 24 words, rather than exactly 24. A public deterministic 12-word native fixture (`abandon` repeated eleven times, then `ankle`) derives public key `f6e89217cdc90b46e58d646b9616b7c163ed87911ebd1783b209c3595749a469`. Recovery validation must retain that released range.

## Jetton and combined migration qualification

The Release `ton-jetton-second.xcresult` run executed 438 tests. All initial 352 migration/storage/sign/export checks, native TON recovery/model tests, 33 import tests, original builder and pending-journal tests, and six new Jetton tests passed. Two history test helpers produced six assertion failures while asserting expected errors; the helper was corrected without changing history behavior.

The final focused Release run `build/legacy-upgrade-20260906/ton-jetton-history-verified.xcresult` passed **62/62**: AccountImport 33, native TON upgrade 8, history 10, Jetton 7, pending journal 4. The seventh Jetton test exercises the actual transfer-service fee listener, rejects an unacknowledged/wrong quote, acknowledges the exact rendered quote, signs with the original native key through a fake transport, verifies the independent TEP-74 payload, and durably acknowledges the confirmed pending intent. All fixtures and API credentials are synthetic; no live transfer occurred.

Jetton transfer compatibility now resolves either the released per-owner Jetton-wallet asset identifier or the master identifier from the reviewed owner balance response, binds the canonical master/recipient/token quantity into the quote and durable journal, preserves the released 0.64 TON upfront attachment budget and 1-nanoton notification, and validates exact emulation risks/events plus bounded linked contract traces. Independent @ton/core 0.63.1 TEP-74 body hashes cover comment/no-comment encoding. Native TON signing vectors remain unchanged.

The later combined qualification below also verifies TonConnect restoration and global balance alias reconciliation.

## TonConnect compatibility boundary and SDK qualification

The restored session/reply protocol foundation and history passed **32/32** Release XCTest checks (`tonconnect-foundation-verified.xcresult`: 22 protocol/store/transport/service checks plus 10 history checks). The integrated transaction boundary subsequently passed the combined qualification below.

TonConnect accepts one through four immutable reviewed V4R2 messages and binds their order, canonical destination, native amount, original friendly-address bounce flag (raw addresses default to bounce), payload and StateInit cell hashes, exact deadline, original account public key, network, and session/RPC replay identifier into the fee quote and durable pending journal. StateInit must hash to its target address. Recovery uses the existing common pending coordinator before requesting credentials; a durably stored bridge reply precedes idempotent journal acknowledgement. The testnet namespace preserves existing mainnet journal identifiers and bytes.

The removed released DRadmir TonConnect message helper is no longer publicly retrievable; bounce behavior therefore follows TON friendly-address semantics and the raw-address default, with independent @ton/core vectors rather than an unsupported claim about inaccessible source. Both explicit TonAPI REST origins are documented by the provider: [TonAPI REST endpoints](https://docs.tonapi.io/tonapi/rest-api), [shared mainnet/testnet token limits](https://docs.tonapi.io/tonapi). No registry/custom origin receives signed operations or the API credential.

Untrusted BOC preflight now bounds wire lengths, roots, references, graph depth and cell count before entering the SDK. It accepts qualified ordinary, library-reference, pruned-branch, Merkle-proof and Merkle-update cells, including library-backed StateInit. The pinned SDK previously trapped on invalid reference/root indexes and rejected library-reference cells; it also misread multi-level pruned hash/depth arrays and higher-hash descriptors. Exact TonSwift 1.0.4 sources are now repo-owned in `Packages/ton-swift`, with the Apache 2.0 license and a scoped patch/rollback manifest. The ordinary level-zero V4 key/signing path is unchanged.

The isolated patched SDK passed **41/41** tests (all 31 upstream tests plus 10 compatibility regressions). A separate isolated app-builder run passed **2/2** tests: all eight independent exotic/StateInit vectors and one exact original-key V4R2 signed BOC containing four messages (nonbounce payload, library StateInit, zero-TON self-call, and masterchain recipient). Evidence: `ton-sdk-all-verified.log`, `tonconnect-builder-typecheck.log`, `tonconnect-cell-vectors.json`, and `tonconnect-transfer-vector.json` under `build/legacy-upgrade-20260906`. The first integrated app compile stopped on an Int32 action-count conversion; that narrow compile error was corrected before tests.

## Combined qualification — 2026-09-06

`legacy-full-tonconnect-verified.xcresult` completed successfully: **516 tests, 0 failures**, 51.419 seconds. This run includes the initial migration/storage/selection/signing/export suites with phone-scale qualification enabled, native TON import, native and Jetton send, pending journals, independently generated V4R2 message vectors, generated TonAPI transport, the TonConnect transaction boundary, protocol/store/transport/service/coordinator and actual WKWebView tests, history, balances and legacy Jetton catalog. It includes the cached-reply acknowledgement regression (an older acknowledged request must not clear or block a newer pending request). The repo-owned SDK separately passed all **41 tests** (31 upstream and 10 compatibility). Logs and result bundles are under `build/legacy-upgrade-20260906/`. This records the tested source before the subsequent root-owned Jetton swap history and released TonConnect manifest/app-name compatibility follow-ups. No live transaction was submitted.

The root-owned `ton-history-links-verified.xcresult` subsequently passes all 55
focused tests: legacy token-wallet swap history at zero balance, both token
amounts/symbols, native fees, transfer-only filter isolation, bounded owner/master
BOC parsing, token decimal validation, released TonConnect app identity and CDN
manifest compatibility, and the existing coordinator/HTTP/WKWebView and catalog
checks. This brings combined unique iOS coverage to 525, with the separate 41 SDK
cases unchanged. Final source snapshot: `ton-history-links-source.sha256.json`.

The final `ton-session-restore-verified.xcresult` passes 24/24 and preserves public
JS restoration of released empty/long app names and HTTP icon metadata without
rewriting those records or relaxing origin/key checks. Combined unique coverage
is now 526 iOS cases, counting the renamed manifest test once, plus 41 SDK cases.
`verified-regression-case-inventory.json` records the exact case union and rename;
`ton-session-restore-source.sha256.json` matches the final app/test source tree.
Distribution-signed installation acceptance remains a separate release gate.
