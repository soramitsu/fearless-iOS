# Roadmap — Fearless Wallet iOS

## Historical branch runtime fixes — 25 October 2026

Adapt nine bounded fixes from the reviewed modernize/fw-adoptation branches:
ABI signature/anonymous-event bounds, short TON NFT preview arrays, operation
start/cancel ownership, accumulated wallet-currency subscriptions, runtime ready
status, queryless OKLink endpoints, normalized scam labels, strict hex colors and
locale/calendar-independent network dates. Price subscription state now belongs
to Main, with queued background updates and reentrant revision protection.

Original-source and overlap regressions reproduced the affected behavior,
including four array-access crashes and cancellation during factory creation.
Review also reproduced and replaced an intermediate price-subscription lock
inversion. Final Debug build-for-testing and all 58 focused tests pass with zero
failures or skips (21 new regressions and 37 existing price/history controls).
Pinned SwiftFormat passes; scoped SwiftLint has no new rule/file occurrences
versus its 20 inherited findings. Native ownership and all 16 adversarial guard
tests pass; no Native source or binary bytes changed. Intermediate failed runs
and two corrected fixture assertions remain in the historical-runtime-fixes
validation receipts. Tests use local fixtures, with no network writes.

This does not merge the historical SDK/UI restructuring or qualify unverified
provider migrations, live providers, signed devices or store distribution.

## Connection issues and subscription setup completion — 25 October 2026

App and Native issue centers now classify unreachable WebSocket connections as
network issues, notify once, and clear the issue when connected. Subscription
setup reports failure/cancellation to current waiters, releases pending state for
retry, and ignores delayed completion belonging to a detached request.

Two reachability regressions and three subscription completion regressions fail
against the prior behavior. The final cached app build and all 11 focused
reachability, subscription, listener and chain-registry tests pass with no skips.
Tests use local mocks, including the transport; no network writes are performed.
Native ownership verification and all 16 adversarial guard tests pass. Existing
signed-device/distribution qualification gates are unchanged.

## Public recovery integration — 25 October 2026

Integrate the missing-account restoration from public commit `bb9c50d29` into the
app-owned native release line. Mnemonic import and stored-root enrollment include
Bitcoin testnet and BIP39 TON while preserving independent aliases, native TON,
strict Bitcoin/Taira root recovery, seed-bridge provenance and concurrent edits.
The newer Solana behavior remains: malformed rows are retained alongside the valid
derived account. Restored addresses remain available without runtime catalogs;
Nexus is presentation-only, with no network endpoints or transfer actions.
Google Drive recovery now verifies BIP39 TON derivation and stored-row structure,
so independent or malformed TON accounts remain in the unrecoverable-account warning.
Validation passed Debug build-for-testing and 430 focused recovery/import/export,
identity, address, keystore and backup tests; the same run passed six separately
owned payout tests. One existing unsigned-system-keychain case was excluded after
reproducing its recorded baseline failure. SwiftFormat passes; scoped SwiftLint
retains 29 inherited findings with no new rule/file occurrences. Detailed receipts
and the original failed run are retained in repository-consolidation output.

## Shared package keystore framing validation — 2026-10-25

The release source contract now pins reviewed shared-features-spm commit `293b3cb5cd8ab276cbd041093cf6a195d7be3ed6`, tree `14f3a15c7e3c044dda3df8ec163164c7d3b339ea`, from the merged PR #88 stack. Incomplete encrypted JSON keystores are rejected before key derivation or nonce access. Drive restore can try an older generation for explicitly malformed framing, while authentication/password failures still stop restore. All pin sites move together; the guarded transport pin and native binary provenance remain unchanged.

Validation passed: 30 source-verifier regression cases, delta-report regressions, dependency contracts, exact verification of 1,301 SDK/transport files before and after the build, and Debug simulator build-for-testing. All 36 focused backup, authorization-router, keystore import/export and read-only XCM tests passed with zero failures or skips on iOS 27.0. This is focused simulator qualification; the existing full-suite baseline and separate signed/device/store release gates remain unchanged. Rollback identities are recorded in `docs/shared-features-pinned-source.md`.

## Test matrix dependency verification correction — 2026-10-24

The Debug/Release test runner called a removed `verify_native_crypto_state` function and exited before its first test build. It now runs the existing immutable shared-features source verifier before each configuration, using the same local package directory as dependency resolution. Four isolated runner regressions cover success, verification failure before either configuration and resolution failure; the original runner fails three of these with command-not-found. This tooling correction does not qualify the current app build or runtime.

## TON source audit formatting correction — 2026-10-24

The readiness source audit now recognizes both equivalent Swift spellings of the throwing V4R2 address comparison, including the current SwiftFormat output. Its address-mismatch fixture mutates the current spelling; an added positive/negative pair covers the parenthesized spelling. No app source, runtime send policy or readiness evidence changed. The current-source baseline failed at this syntax check; the corrected 86-case adversarial suite and source audit both pass. The separate Iroha source audit passes all 15 invariants at the same candidate. Full production readiness remains open.

## Send warning recipient/context ownership — independently accepted, 2026-10-19

Qualified source `ce1994196d88ea50e132f0f2f61cd57c406b5389` clears pending and displayed scam-warning state when the recipient or selected chain changes. Interactor request identity rejects retired lookup results and obsolete work before lower fetch starts; presenter delivery identity prevents an already-queued warning from repainting after Clear/change. The underlying service work is not cancelled by this bounded fix.

The unchanged original baseline has one healthy pass and two genuine visibility failures on each iOS27/18.1 across one ownership boundary. All634 final executions pass without skips:209 restyled and108 legacy perruntime. All prior199/98 outcomes and155 previous method bodies remain exact, including the original three baseline methods. Seven additional controls exercise visible Clear, queued delivery, recipient round trips, chain replacement with visible or held warnings, current nil refresh and invalidation before task start. Preliminary20 focused executions and2 cleanup-only executions are excluded from634.

Candidate `9b38a95040d4f7285da68c133cc5f737388de05ea7277d0669fd0248b8083a57` and independent final review `7fb56892fd1afd00b3633706128604b3552a6add317938f7464f5eb4c3837bdf` bind4692 source files,77 dependencies,11149 evidence pins, two950-file readers and1306 final regression PNGs. Warning tests exercise actual Send presenter/interactor/factory/controller, real Clear target and rendered warning visibility/labels with controlled lower lookups. The queued-delivery control explicitly inspects the intermediate callback order. No physical tap, live-provider, hosted warning geometry or full confirmation/signing claim.

Initial whole-file test formatting was rejected before build; the accepted prefix is exact. Initial two new lint identities were removed from appended code; final strict lint retains190 inherited identities and is not clean. Changed production and appended controls pass pinned SwiftFormat. First broad preflight stopped before tests because owned clipboards were empty; the bounded wrapper now preserves empty or exact public fixture state and restores each desktop bridge. Any native cleanup uses unchanged same-reader tests and remains separately counted. No permission policy changes.

Provider privacy/eligibility/address matching, full native journeys, other visual/design work, historical upgrades, physical/biometric, signed/store and release gates remain open. See `docs/send-scam-warning-ownership-validation.json`.

## Send-all native row geometry — independently accepted, 2026-10-19

Qualified source `e693e5e544f6fc7c6bedeb3f36790870261ef163` fixes the legacy Send-all row's outward label padding and compressed, partly offscreen native switch. The row now reserves intrinsic switch width, accounts for native alignment insets, uses inward label padding and has a minimum height. The existing restyled constraints and callbacks remain covered.

The original three-case baseline executes one healthy and two failing methods on each iOS27/18.1, with24 geometry assertions perruntime across one row boundary. All594 final executions now pass without skips:199 restyled and98 legacy perruntime, preserving all prior195/94 outcomes. The entire previous accepted test-file prefix remains exact. The three new baseline methods retain their assertions, ordering and deadlines with only a local identifier rename and whitespace; a fourth control checks intrinsic width after live locale/text-size changes. Preliminary8 focused and one separate unchanged Copy-ID cleanup execution are excluded from594.

Candidate `e25210f134ad3b8ba62e1ec0ca0895476af7d671ca0ee2045c84ac51b79373f6` and independent final review `8a030d30d81fa0a7e02cd099710adee21e105d94ccf5029720d32a00e2fe6142` bind4,690 tracked source files,77 dependencies, two950-file final readers,11,224 evidence pins and1,306 final native PNGs. Direct raw-image review corroborates the row correction without accepting full-screen design. Pinned SwiftFormat passes; strict lint retains101 prior finding identities (2production/99test), including changed body/file-length counts. This is not a clean strict-lint claim.

The first corrected legacy build used uncommitted source, was withdrawn/interrupted and contributes no accepted artifact. Original baseline metadata labels are clarified against the exact selected source and actual compiled flags. Legacy27 command-line clipboard restoration failed; the existing same-reader in-app Copy-ID control restored the original public88-byte fixture. Both desktop bridges/plists and post-bridge fixture readbacks are verified exact. No permission policy or host clipboard changes.

Legacy native center hit testing and drawing containment are qualified; no newly expanded44-point legacy touch target or physical-touch claim. Other legacy geometry, numeric/action typography, actual VoiceOver/native journeys, historical upgrades, physical/biometric, signing/store and release gates remain open. See `docs/send-all-geometry-validation.json`.

## Account score response ownership — independently accepted, 2026-10-19

Qualified source `8f2270f27b7e93010bd301e2bb8075265e315205` preserves production correction `201f2430e2bc2842e9e8aa6b33809b7d5ad54dbb`. A reused or cleared AccountScoreView now detaches the previous model, revokes its binding and cancels its consumer task. Every asynchronous response checks the binding UUID on main-thread delivery. Cleanup from a previous view cannot cancel a model moved to another view; weak task captures permit model deallocation, and settings callbacks cannot revive a detached binding.

The unchanged three-case baseline reproduced one stale-binding boundary with two failing methods on each iOS27/18.1: stale20 replaced current80 or repopulated cleared N/A. All578 final executions pass with zero skips:195 restyled and94 legacy cases on each runtime, preserving all prior182/81 outcomes. The13 component cases include the original3 and ten lifecycle/current-response controls. Independent focused26 passes are preliminary and excluded from578. Two950-file final readers,4,688 source/77dependency/10,437 evidence pins and exact Git content bind candidate `a81de6e34301553697207475ce4326d6ea043354662cef4ee59e9dc5d89a2407`. Independent final review `e1f4d55b998727092d370a717a736403d3dd88a5d4819fd4363a2ff9dfa835dd` accepts only this scope. Pinned SwiftFormat/scoped strict SwiftLint pass. See `docs/account-score-binding-validation.json`.

Retained diagnostics include an initial18 loader-only missing-SwiftSpan failure, fixed by rebuilding the same source for18, and eight new methods failing solely because their helper registered unused return expectations. One helper construction line corrected the latter; all13 method bodies/assertions and production bytes remain exact. Legacy27 passed94 but command-line clipboard cleanup failed. One separately counted unchanged in-app Copy ID test restored the exact88-byte public fixture and desktop bridge; it is excluded from578. The failed cleanup/recovery preflight and raw attempts remain preserved. No permission-policy or host-clipboard changes.

Cancellation of the model consumer does not establish cancellation of the unchanged fetcher's HTTP Task. Existing disabled-score request admission is preserved. Factory-selected recipient/account/chain provenance, response-address validation, native interaction, VoiceOver, complete visual/authentication journeys, historical migrations and signed/store gates remain open. No complete production-readiness or publication claim.

## Full unfocused amount visibility — independently accepted, 2026-10-19

Qualified source `b2fb9b0a2ff4f37bdcc6a85646596d6e4523821b` (initial production `aabae3c308828a9de9835fc33ebba89ac0989e6d`) preserves the native amount field, delegate, model, font and editing behavior. Outside editing, the configured Send/Request amount view displays the exact full value in a full-size multiline readout. The readout yields to the native single-line editor during focus; empty zero remains only a placeholder. Unconfigured legacy/swap views keep native rendering. One ellipsis defect was reproduced by three valid AX5 baseline methods; all ten baseline assertions concerned visible-value geometry.

All526 final executions pass without skips:182 restyled cases on each iOS27/18.1 and81 compiled legacy cases on each runtime. Both950-file frozen readers use the same source, with Send/Receive presentation YES/NO and AccountConfirm YES. Prior167/75 outcomes and16 prior network/presentation bodies remain exact. Nine/five Receive/Request cases exercise the shared component. Candidate `cf55651be54fde1ef73206583daa4179709757a4505d7104bd9fcc0bca8fb1c2` and independent final review `097b72bd7e2c8066922ba3b681295027c5456b366d1492004606635c2f9b6a59` bind4,686 source/77 dependency/21,567 evidence pins and1,242 raw PNGs. Pinned SwiftFormat and scoped strict SwiftLint pass. Root inspected12 final images; independent review adds its own evidence. See `docs/send-amount-readability-validation.json`.

Retained diagnostics include the first direct insertText fixture assumption, two lint failures before a behavior-preserving layout-method move, preflight-only device-name/clipboard checks and the initial181/182 iOS18 result caused by a new test hardcoding a focused accessibility flag. Final test-only correction captures/preserves the native flag and traits; production bytes are unchanged. The legacy27 final81 passed, but post-test command-line clipboard restoration did not change the public fixture. One separate unchanged app Copy ID recovery test restored the original88-byte public fixture and the desktop bridge; it is excluded from526. No source/build or permission-policy change, no host clipboard access, and all failures remain pinned.

Character wrapping exposes all digits but can split numeric groups and decimal digits. Available-balance/action-label typography, legacy Send-all geometry and full design acceptance remain open. Focused delegate/control tests do not qualify physical touch/keyboard or VoiceOver. This slice adds no26.5/physical, signer/RPC/private-validator, registry/destination or historical/signed/store qualification. The audit remains active; no production-readiness/publication claim.

## Recipient Continue state — independently accepted, 2026-10-18

Qualified source `2b7dbbbf59be3d106eac516b057be3c8c54051ba` (production `8507fcddfe7cef3a10f03439bc51f108006b19b4`) disables Continue synchronously before native recipient Clear invokes its output callback. Both recipient and AccountScore bindings refresh the existing Continue predicate after changing the displayed address. The reproduced defect was an enabled button after Clear; empty-recipient validation already refused confirmation in the baseline.

All 484 final executions pass without skips: 167 restyled cases on each iOS 27/18.1 and 75 legacy cases on each runtime. Two 950-file readers use the same source with sendPresentation YES/NO and accountConfirm YES. All 151 valid baseline method bodies and prior 159 restyled/66 legacy outcomes remain exact. One genuine failing method is resolved; seven other new recipient controls pass. The final legacy inventory adds the unchanged existing Copy-ID control before the prior 74 cases to establish a same-process public clipboard fixture. Candidate `8f31a10cc8f235c5e8cf8d99b63dedf7f8bb3355f4588e3c0b3cfee91021f6dd` and independent final review `e823d4731f28dacefb81feb37c765f7999c9a8875cf5f87559e66bc43c77a1ae` bind 4,684 source, 77 dependency, 12,842 evidence pins and 814 PNGs. See `docs/solana-form-recipient-authority-validation.json`.

Retained diagnostics include an unsupported forced keyboard deletion after focus rejection, a formatting-only failed build, and incomplete legacy runs blocked by OS paste prompts during the previous-clipboard snapshot. None is counted as an additional product finding or a final pass. The accepted keyboard-display control preserves focus rejection, exact display and confirmation assertions; the final clipboard qualification preserves app code, assertions and OS permission policy. The owned public fixture clipboard and desktop bridge are restored exactly. Bundled SwiftFormat and scoped strict SwiftLint pass for the changed controller.

Non-nil AccountScore binding is source-reviewed only; the fixture returns nil. Controlled native button dispatch and queued Contacts callbacks do not establish physical timing, every callback lifetime or registry/destination authority. This slice adds no 26.5, physical-device, RPC, signer or private-validator qualification. Sampled screenshots retain AX5 amount ellipsis, numeric/midword action-label wrapping and legacy geometry issues. Full design, historical migration, signed/store and release gates remain open. No production-readiness or publication claim.

## Native amount input ownership — independently accepted, 2026-10-18

Qualified source `40bc3f2e1ad6b4cf8cf9b7b8858703eb3f0fb43a` synchronizes the visible amount draft before Continue, rejects obsolete queued amount models, removes replaced input observers and binds deferred fee work to the edit revision and original form lifetime. Back, actual departure, inactivity or Solana wallet reselection revoke delayed work; ordinary fee/balance updates preserve a current edit. The existing debounce remains in place.

All 1,336 final executions pass without skips: 398 on each iOS 27/26.5/18.1, ten private-validator cases, and 66 legacy-send cases on each 27/18.1. Two 950-file readers share the same source, with sendPresentation YES/NO and accountConfirm YES. Final evidence includes 1,205 PNGs, 4,682 source, 77 dependency and 15,821 evidence pins. All 65 focused cases pass, including seven genuine reproduced failures; all 132/140/143 prior method bodies remain exact, with one additional healthy fee/balance-update qualification. Candidate `5ebac5578cb402ed04950e10a7289b47d8dffa118c636acf153fdb9bf3e3e159` and independent final review `027731792c93f70ff3ca3aaf9b891ae336ded0b0dffdf6fbbdc24f1efadbfee8` bind this checkpoint; see `docs/solana-form-input-authority-validation.json`.

The first navigation push/pop probe lacked actual departure proof and is excluded from product findings; the strengthened fixture retains every assertion and passes without a navigation correction. Scoped lint retains 19 inherited findings (three errors), with none introduced. Actual native control/delegate dispatch and injected lifecycle notifications do not qualify physical typing or full OS/multi-scene behavior. The legacy flag test qualifies routes, not full geometry or readable recipient display.

Sampled screenshots retain AX5 amount ellipsis, long numeric line wrapping and midword action labels; legacy normal-size captures also retain switch clipping and shortened confirmation recipients. Full typography/readability, recovery Close/scroll placement and native design gates remain open. Current cached fee identity, other queued UI work, registry/destination/independent consumer authority, historical migration, physical/biometric and signed/store gates remain open. No production readiness or publication claim.

## Solana amount warnings and form inactivity — independently accepted, 2026-10-18

Qualified source `6748043fd` makes amount-warning actions consume a current form receipt before mutation. Changed inputs, departure or selection revoke retained actions. Existing warning content uses the exact owned presentation, so external dismissal revokes its actions while native Proceed, Max and Cancel remain usable. Application inactivity and owned-scene deactivation suspend the form; fresh continuation requires a live foreground scene and visible form. Shared sheet dismissal ordering and existing amount update ordering remain unchanged.

The final matrix passes 1,123 cases without skips: 371 each on iOS 27/26.5/18.1 plus ten private-validator cases, using one 950-file reader and 192 recovery captures. Twelve genuine baseline failures now pass. All 111/125/129 earlier method bodies remain exact; the final three full-validation button controls are qualification only. Independent review `d97134fefe879427a438e96ecdff2d73108e3a53b08961b03e56ef7ec356214d` verifies seven changed files, 4,680 source blobs, 77 dependencies and 6,424 evidence pins; candidate `4a36a8a8b58ef7512a3f9ac43a57aa2bb7706fcc0c4a333b7a73d7497c58b444`.

Scoped lint retains 16 inherited findings (three errors), with none introduced. The initial PBX identifier collision and missed first review are retained; unique replacement identifiers and successful final build were verified. Actual warning UIControl dispatch and injected scene/app events do not establish physical input or full OS/multi-scene qualification. Existing recovery clipping/scroll-placement and large-text wrapping limits remain. Other input/registry/destination/consumer authority, queued UI delivery, reentrancy, physical/historical migration, signing/store and full design gates remain open. This is a bounded checkpoint; production readiness and publication remain pending.

## Solana upstream form authority — independently accepted, 2026-10-18

Source `3f731ac00` (production `021679ff9`) binds each form to its original selected-wallet lease and each Continue operation to a single-use receipt. Input/context changes, navigation, background and unowned presentation revoke retained callbacks. The exact owned warning remains usable; a fresh visible action can resume after return. The original lease reaches confirmation without recapture. Existing typography/switch declarations are moved unchanged and shared sheet dismissal ordering is preserved.

Final qualification passes 1,060 cases without skips: 350 on each iOS 27/26.5/18.1 plus ten private-validator methods, all on one 950-file reader with 192 recovery captures. Independent review `a07570beab497483b9b9cfe653f1b775c2b5e016086ce5bd731306a5fe020255` rehashes 13 changed/4,677 source/77 dependency/11,336 evidence pins. The original79 and later93/99/105 test method bodies remain exact; six final additions qualify lease/factory/pipeline and untouched overlay return. Nineteen distinct failing methods across retained baseline stages include correction-stage availability regressions; the actual-button ordering hypothesis was withdrawn after source review and healthy button controls. Fixture/build failures remain retained.

Scoped lint has 22 inherited findings (three errors), no introduced findings. Per-owned-simulator desktop-pasteboard isolation/restoration and supported eight-tick local validator genesis are explicit. Earlier amount-warning callbacks, inactive/scene events, registry/destination/amount and independent-consumer authority, full physical/native/design, historical migration and release gates remain open. Three sampled recovery captures retain normal Close clipping/scroll placement and largest-text wrapping limits. Candidate SHA `6c0dff40b0d942ca12f7dd44798e5e7b1735c3266439fb77eb6277f0b840991e`. This is a bounded checkpoint, not production-readiness or publication approval.


This document mirrors the structure used in the Android repository’s roadmap and adapts it for iOS. The authoritative product roadmap and delivery plans are maintained in Aha! and on the public dev board.

## PIN accessibility — scoped dual-runtime checkpoint, 2026-10-13

Source `eaa6bfe23` passes the same ten native checks on iOS 27.0 and 18.1 (20 executions, zero failures/skips), with 398 raw captures. The existing PIN control now sits below fully wrapping localized headings in scrollable content. Text and SF tabular keypad digits scale with Dynamic Type; keys retain at least 56-point targets. Eight locales, Large/AX5, setup/change/unlock/authorization presentations, optional Cancel, live locale/type/Bold Text changes and existing input callbacks are covered. The tests exercise the native Back control after its animation finishes. [The validation record](docs/pin-accessibility-validation.json) pins all three changed files, supporting source, 32 prior PIN screenshots, final evidence and superseded attempts. This resolves the PIN overlap/fixed-typography issue recorded below. Physical touch/VoiceOver, real Keychain/biometric continuity, the full Sora screen sweep, onboarding/localization and release acceptance remain open. The existing Indonesian change-PIN title still needs a separate wording correction.

## About accessibility — scoped dual-runtime checkpoint, 2026-10-13

Source `4866fdaf5` passes the same nine native checks on iOS 27.0 and 18.1 (18 executions, zero failures/skips), with 198 raw captures. About's existing header scrolls with its rows and remeasures after live text-size and locale changes. The full licence row fits its actual scrolling viewport at AX5 in all eight locales. Disclosure icons retain their asset dimensions, and the full localized licence heading wraps inside the document body when the compact native navigation bar abbreviates it. [The validation record](docs/about-accessibility-validation.json) pins source, captures, commands and earlier failed attempts. The About viewport defect reported below is addressed by this follow-on; PIN overlap, onboarding typography/localization and the wider Sora screen sweep remain open.

## Font migration — scoped dual-runtime checkpoint, 2026-10-12

I-A3 replaces the four legacy Sora rc004 resources with the exact Android Sora 2.000 binaries and bundles JetBrains Mono 2.304 Regular/Medium. Existing Sora styles retain their sizes; handwritten and Interface Builder names use the new PostScript names. New design roles keep system fonts for amounts/body and locale-safe title/HUD fallbacks. About exposes both exact bundled OFL texts offline. Normal and maximum-text baseline captures of actual About, onboarding and PIN screens passed before replacement. Source `573703435` now passes the same 28 focused tests on iOS 27.0 and 18.1 (56 executions, zero failures/skips), with 290 raw captures across font resources, the offline licence route, actual legacy About/onboarding/PIN and selected production consumers. [The validation record](docs/font-migration-validation.json) pins all 31 direct legacy reference files, source and evidence hashes, binary/glyph provenance, per-screen coverage and preserved failed attempts. Final licence captures wait for navigation completion; earlier iOS 18 transition captures are diagnostic only. I-A3 remains open: every Sora screen before/after coverage, compact PIN title overlap, fixed About-header accessibility viewport, compact Portuguese navigation-title truncation, and onboarding localization/fixed typography are not accepted as complete. This checkpoint does not establish release readiness.

## Native design foundations — 2026-10-12

I-A2 replaces registered effects, glass, chrome, glow, neumorphic and font placeholders with paint-only helpers. Automatic follows accessibility and low-power signals; Lite/Reduced are persisted ordinary UI preferences. Calm and High Contrast suppress translucent paint and glow. New number styles use scaled SF Pro tabular digits, with locale-safe title/HUD fallback and optional future Sora 2/JetBrains Mono names.

Source `bdd14af7f` passes the same 12 focused tests on iOS 27.0 and 18.1 (24 executions, zero failures/skips), with 38 reviewed real-window normal/maximum-text captures across all paint modes and mixed scripts. [The validation record](docs/design-foundation-validation.json) pins the source, commands, results, captures, geometry and preserved attempts. Six new production files lint clean. No production screen consumes these helpers yet; glow placement is unit-qualified only. Global palette migration, font-file replacement, Appearance settings, hitch-based automatic Lite selection, physical-device accessibility and release sweeps remain separate gates.

## Token-group native actions qualification — 2026-10-12

Group Send and Receive use the exact-network native picker; Send choices are ordered by transferable balance. Group Hide has a feature-local, scrollable confirmation with a fixed close control. Final actions recheck the current wallet session, exact group member and spendable balance; Hide requires the visible members to match the reviewed list and writes once after dismissal.

Source `e4490a833` passes 126 selected tests on each of iOS 27.0 and 18.1 (252 executions, zero failures/skips). Forty-two English/Russian/Japanese compact normal/maximum-text captures were reviewed; real-window tests prove full captions, hit targets, cancellation and stale-action rejection. [The validation record](docs/token-group-actions-validation.json) pins the source, commands, native results, captures and preserved fixture failures and native-bar diagnostics. New Hide controller lint passes. Complete imported-wallet navigation, design primitive implementation and signed-release gates remain open.

## Empty-wallet funding qualification — 2026-10-12

Empty wallets now show Receive and Buy with an exact asset/network picker and a clear unavailable state. The shared asset picker also selects by chain/asset ID when symbols and display names collide. Wallet switches, a new deposit, changed provider metadata and stale callbacks invalidate pending funding choices. Buy remains limited to repository-proven native DOT on Polkadot and explicitly declared existing providers; MoonPay configuration is unchanged.

Source `5907745e6` passes the same 120 selected tests on iOS 27.0 and 18.1 (240 executions, zero failures/skips), with 48 normal/maximum-text captures across English, Russian and Japanese. The eight shipped locales and the legacy unbundled Portuguese resource have the new copy. [The validation record](docs/empty-wallet-funding-validation.json) pins source, commands, captures, results, the separate exact-picker fix and earlier attempts. New production files lint clean; existing factory lint debt remains explicitly recorded. This is a scoped simulator gate, with native group sheets, broader design primitives, complete navigation and signed-release checks still open.

## Manage assets qualification — 2026-10-12

Approved-group visibility controls, conditional Reset order persistence, the scrolling Manage header, and action-button Dynamic Type now pass the same 256 focused tests on iOS 27.0 and 18.1 (zero failures or skips). The tests cover stale wallet/confirmation callbacks, preservation of visibility, first-pass header sizing, eight shipped locales, and font changes while visible. Source, commands, result bundles, ten reviewed captures, and earlier failed attempts are pinned in [the validation record](docs/manage-assets-group-reset-validation.json).

The actual native Reset order sheet now passes 26 Manage tests on each runtime at source `4e23044494b5`, including real presenter/router presentation, confirm-once persistence, stale-wallet rejection, and cancellation. Eighteen normal/maximum-text captures across English, Russian and Japanese were visually reviewed. The feature-local sheet stays within a compact presenting window, keeps close reachable, and scrolls full captions without compressing them. Exact source, commands, results and preserved failures are pinned in [the sheet validation record](docs/manage-assets-reset-sheet-validation.json). The earlier 256-test checkpoint remains separate evidence.

These checkpoints do not establish complete imported-wallet navigation, manual assistive-technology acceptance, or final signed-release readiness; the remaining audit and integration work stays open.

## Full support for Polkadot SDK release: polkadot-stable2503

Why: Align the wallet with the latest stable Polkadot SDK, ensuring type/metadata compatibility and correct decoding/encoding across chains.

Scope: Substrate runtime alignment across Polkadot/Kusama/Westend/AssetHub and major parachains used by the app (per chain registry).

Acceptance criteria:
- App runs without SCALE decode errors on target chains.
- Balances, transfers, fees, and staking screens load and execute extrinsics successfully on Polkadot and Kusama.
- Chain sync stable: connections establish, runtime providers load, subscriptions update on version bumps.
- No regressions in unit/integration tests; lint/format checks green.
- If APIs changed (e.g., extrinsic names/signatures), code updated or guarded by capability checks.

Suggested steps:
1) Registry alignment:
   - Refresh chain/type registries consumed by the app to stable2503.
   - If registries are bundled JSONs in the app, replace them with stable2503‑aligned versions and verify diffs in PR.
   - If registries are provided by SSF libraries or remote endpoints, coordinate with maintainers to bump the dependency or adjust the configured URLs for Debug/QA builds and verify.
   - Capture the exact sources/versions used in the PR description.
2) Utils/runtime integration:
   - Pin or update iOS runtime/utils dependencies (e.g., SSFChainRegistry/SSFRuntimeCodingService or equivalents) to versions compatible with stable2503.
   - Verify that SCALE encoding/decoding and metadata parsing succeed on target chains in debug logs.
3) Build + checks:
   - `pod install`
   - `swiftformat . && swiftlint`
   - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -configuration Debug -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' build`
   - `xcodebuild -workspace fearless.xcworkspace -scheme fearless -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15' test`
4) Runtime smoke tests (manual):
   - Verify initial network connections and metadata load (debug logs).
   - Balances show assets and fiat values.
   - Send: compute fee and submit a small transfer on Westend/Kusama (test account).
   - Staking: validators/nominators decode without crashes.
5) Address API deltas:
   - Update runtime‑extrinsic assumptions and storage paths; add capability checks as needed.
6) Update defaults (optional):
   - If stable2503 becomes default, update configuration and docs with the new registry sources.
7) Document:
   - Add notes on the exact registry sources/versions and verification results in the PR description and update this roadmap if needed.

Verification matrix (execute manually):
- Polkadot: balances load, transfer fee computed, send succeeds on test account.
- Kusama: as above; staking validator list loads.
- AssetHub: asset enumeration works; transfers succeed to another account.
- Westend: basic transfer path for low‑risk checks.

## iOS Backlog (illustrative)
- [ ] WalletConnect: improve session reconnection reliability and error surfacing.
- [ ] EVM chains: handle gas estimation failures gracefully; improve fee UI for L2s.
- [ ] Staking: optimize validators list loading and caching on slow networks.
- [ ] Localization: audit new/changed strings across all `.lproj`; fill gaps.
- [ ] Performance: reduce cold start time; trim excessive logging in Release.
- [ ] Fearless Utils (upstream hygiene):
  - Align podspec with modern toolchains (iOS 13+, drop armv7). No functional changes.
  - Add optional SwiftPM manifest to enable SPM consumption (side‑by‑side with CocoaPods).
  - Verify IrohaCrypto consumption consistency across app and utils (prefer single source to avoid duplicate modules).
  - Ensure CI builds on Xcode 16/18 with iPhoneOS SDK 18.x (no armv7, correct module visibility).
  - Target: open PR to soramitsu/fearless-utils-iOS with minimal, non‑breaking changes; coordinate release tagging.

## Xcode & App Store Compliance
- Keep Xcode and Swift toolchain aligned with supported App Store requirements.
- Update deployment targets and signing settings as needed; verify Release builds on CI.
- Ensure third‑party libraries and binary artifacts meet App Store policies.
 - CI hygiene for iOS 18 SDK:
   - Deduplicate SwiftPM packages (e.g., Web3) to a single source to avoid resolver conflicts.
   - Patch or bump modules with brittle module.modulemap (e.g., IrohaCrypto via shared‑features‑spm) and upstream fixes.
   - Make private keys/pods optional in PR builds (e.g., gate FearlessKeys by env and limit to Release).

## Sources of Truth
- Product roadmap (Aha!): https://soramitsucoltd.aha.io/shared/97bc3006ee3c1baa0598863615cf8d14
- Dev status board: https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2
- Issues: https://github.com/soramitsu/fearless-iOS/issues
- README: ./README.md
- Contributing: ./CONTRIBUTING.md

For the most accurate and up‑to‑date details, always refer to the Aha! roadmap and dev board links above.
