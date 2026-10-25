# Solana confirmation selection authority checkpoint

Qualified source: `27d90a24a01af000e7166326c842e5ce9fe9515f`, thirteen changed files relative to accepted base `3712b5249c43a8c9c991e9abf0da8c7c216cf0e7`. The candidate manifest SHA-256 is `2735342fb75156cb6f9b16d6ae68dc67769a347d0d89693088d6c262b991cbb0`. Independent acceptance and integration remain the parent reviewer’s responsibility.

A retained Solana confirmation could read old wallet keys, send, retry, or present a receipt after the selected wallet registered a new visible value but before asynchronous UIKit notification arrived. Eight actual pipeline tests reproduced six failures and two healthy controls. A later held retained-store-read test reproduced one additional old-key access between an earlier authorization check and mnemonic access.

Each `SelectedWalletSettings` instance now owns a revision authority. Registration, setup publication and rollback advance it before the corresponding value becomes visible. A→B→A and failed-save rollback never revive an old lease. Only name and backup-marker updates explicitly preserve identity; changed account/key identity under the same wallet ID and other metadata conservatively revoke. Unrelated settings instances remain independent.

The confirmation interactor captures this authority at construction and carries its lease through the real task with TaskLocal binding. Checks cover preparation, mnemonic access after the retained-store read, signing, journal admission and the final RPC transport boundary. Current-selection checks also reject stale UI delivery and retained recovery retry. No authority lock spans key access, I/O, signing, transport or suspension. Previously admitted output retains exact durable journal ownership and acknowledgement settlement even when its UI is suppressed; cancellation does not prove that output never happened.

## Qualification and evidence

One frozen 950-file reader, built for iOS 18.1, passed **964 regression/private executions**: 318 exact methods on each of iOS 27.0, 26.5 and 18.1, plus ten unchanged private Solana validator methods. All passed without skips. The 318-method inventory includes eighteen new selection controls and thirty-eight existing settings tests. A separate eighteen-method focused run and one unchanged clipboard diagnostic passed; neither is added to the 964 headline.

All 4,672 current/Git source files and 77 dependency entries remained exact through these runs. The 192 original PNGs cover existing normal/AX5 recovery regressions. Six English, Russian and Japanese frames were inspected. Normal Copy ID is fully visible; normal Close begins below the initial viewport. AX5 control captures show both labels, with existing Russian midword wrapping retained. This does not establish complete screen-design acceptance.

Private validation uses a pinned executable wrapper with the supported `--ticks-per-slot 8` option, an isolated ledger and loopback endpoints. Original assertions, actual finality/status/expiry checks and transaction counts remain unchanged. No public transaction was sent. The manifest records all raw results, named inventories, reader/source/dependency hashes, capture indices, source-move proof and preserved prior evidence.

## Baseline continuity and retained diagnostics

The prior 61 method bodies remain exact. All eight original selection assertions remain unchanged apart from the documented helper-call adaptation that injects the exact isolated `SelectedWalletSettings` exercised by the test. The baseline passed only its selected wallet value and did not yet connect that authority dependency. Both held-read bodies and the entire existing settings-test file remain exact.

The held-read baseline ran eighteen methods: sixteen passed, one exposed the key-access gap, and one had an overstrong new expectation that a pre-output cancellation must leave no record. The broadcaster safely treats cancellation as ambiguous. That expectation now asserts the exact unchanged unreported pending bytes while retaining the zero-output and zero-UI assertions. It is disclosed as a test-contract correction, not a product failure fixed. The final 79-method test file is byte-exact to the passing `efbe9a599` checkpoint.

Initial formatting failures and an interrupted intermediate cleanup build ran no tests. Existing settings state/error declarations were extracted to remove a newly introduced file-length warning; the source-move proof establishes unchanged bytes and access levels except one terminal separator. Only final-build-v3 supplies the accepted candidate reader.

The first final iOS 27 run blocked in an unchanged native clipboard assertion behind an actual OS permission prompt from `dtpasteboardd`. A process sample and screenshot preserve it. The host Mac was locked, so no permission was granted; the owned xcodebuild was interrupted. Its 111 raw results contain 110 passes and one “Testing was canceled” and are excluded from final qualification. The unchanged reader/test then passed with only the owned simulator’s desktop clipboard bridge temporarily unloaded. All final runtime runs record isolation and successful restoration in `finally`. The native pasteboard daemon, OS permission policy and host global clipboard settings were unchanged.

Scoped lint compares eleven changed production Swift files against their baseline: 55 issues including nine errors, with unchanged path/rule/severity multiplicities. These are inherited, not a blanket lint pass. The explicit accepted-base raw-colour guard and seven runner guard tests pass.

## Remaining boundaries

Capture starts at confirmation-interactor construction. Upstream form ABA before construction, authoritative registry changes, destination/form/amount-session ownership and other direct service consumers remain separate. Each check admits the following synchronous effect without holding an authority lock over it; complete cross-thread atomicity at every physical operation is not claimed. Tests use actual isolated settings/CoreData and held event delivery, not a physical wallet picker. Physical-device, distribution, power-loss, global lifecycle and chain dispatch/finality qualification remain outside this checkpoint. Earlier durable-journal/process evidence remains preserved and is not counted as newly executed.

Independent root review accepts this bounded checkpoint after exact source/dependency/evidence and raw-result checks. Review SHA256 `8e918b6190765ccb3fc1815ebee3e6f106c76503e43c8104ac7c19f838ad14a8`; source integration verification follows. No production-readiness or publication claim.
