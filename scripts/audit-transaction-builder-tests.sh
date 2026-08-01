#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${IOS_TX_BUILDER_AUDIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))}"

failures=()

record_failure() {
  failures+=("$1")
  echo "[ios-transaction-builder-audit][warn] $1" >&2
}

require_file() {
  local file="$1"
  local description="$2"
  [[ -f "$file" ]] || record_failure "$description missing: $file"
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if [[ ! -f "$file" ]]; then
    return
  fi
  if ! grep -Eq -- "$pattern" "$file"; then
    record_failure "$description missing in $file"
  fi
}

require_multiline_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if [[ ! -f "$file" ]]; then
    return
  fi
  if ! perl -0ne 'BEGIN { $pattern = shift @ARGV } if (/$pattern/) { $found = 1; last } END { exit($found ? 0 : 1) }' "$pattern" "$file"; then
    record_failure "$description missing in $file"
  fi
}

reject_multiline_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if [[ ! -f "$file" ]]; then
    return
  fi
  if perl -0ne 'BEGIN { $pattern = shift @ARGV } if (/$pattern/) { $found = 1; last } END { exit($found ? 0 : 1) }' "$pattern" "$file"; then
    record_failure "$description present in $file"
  fi
}

require_exact_pattern_count() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local description="$4"
  if [[ ! -f "$file" ]]; then
    return
  fi
  local actual
  actual="$(grep -Ec -- "$pattern" "$file" || true)"
  if [[ "$actual" != "$expected" ]]; then
    record_failure "$description expected exactly $expected occurrences in $file, found $actual"
  fi
}

bitcoin_tests="$ROOT_DIR/fearlessTests/BitcoinTransactionBuilderTests.swift"
solana_tests="$ROOT_DIR/fearlessTests/SolanaTransferTransactionBuilderTests.swift"
routing_tests="$ROOT_DIR/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
ton_tests="$ROOT_DIR/fearlessTests/TonTransferTransactionBuilderTests.swift"
ton_builder="$ROOT_DIR/fearless/Common/Model/TonTransferTransactionBuilder.swift"
ton_send_service="$ROOT_DIR/fearless/Common/Model/TonSendService.swift"
ton_fee_quote="$ROOT_DIR/fearless/Common/Model/TonTransferFeeQuote.swift"
ton_pending_journal="$ROOT_DIR/fearless/Common/Model/TonPendingIntentJournal.swift"
ton_pending_journal_tests="$ROOT_DIR/fearlessTests/TonPendingIntentJournalTests.swift"
chain_model="$ROOT_DIR/fearless/Common/Model/ChainRegistry/ChainModel.swift"
chain_registry="$ROOT_DIR/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
transfer_service="$ROOT_DIR/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
send_container="$ROOT_DIR/fearless/Modules/Send/SendDependencyContainer.swift"
send_confirm_interactor="$ROOT_DIR/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmInteractor.swift"
send_confirm_protocols="$ROOT_DIR/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmProtocols.swift"
send_confirm_presenter="$ROOT_DIR/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
send_confirm_wireframe="$ROOT_DIR/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmWireframe.swift"
send_confirm_tests="$ROOT_DIR/fearlessTests/Modules/WalletSendConfirm/WalletSendConfirmTests.swift"
number_formatter="$ROOT_DIR/fearless/Common/Extension/NumberFormatter+Default.swift"
release_checklist="$ROOT_DIR/docs/release-checklist.md"

require_file "$bitcoin_tests" "Bitcoin transaction builder tests"
require_pattern "$bitcoin_tests" 'final class BitcoinTransactionBuilderTests' "Bitcoin transaction builder test class"
require_pattern "$bitcoin_tests" 'testBuildsAndSignsMainnetP2wpkhTransactionMatchingWebVector' "Bitcoin canonical P2WPKH vector test"
require_pattern "$bitcoin_tests" 'testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning' "Bitcoin unsafe UTXO/output/fee adversarial test"
require_pattern "$bitcoin_tests" 'testRejectsUtxosThatDoNotMatchDerivedBip84KeyOrWitnessScript' "Bitcoin BIP84 witness mismatch adversarial test"
require_pattern "$bitcoin_tests" 'testRejectsEmptyMnemonicBeforeSigning' "Bitcoin empty mnemonic adversarial test"

require_file "$solana_tests" "Solana transfer transaction builder tests"
require_pattern "$solana_tests" 'final class SolanaTransferTransactionBuilderTests' "Solana transaction builder test class"
require_pattern "$solana_tests" 'testBuildsCanonicalLegacySystemTransferTransactionEnvelope' "Solana native transfer envelope test"
require_pattern "$solana_tests" 'testRejectsMalformedTransferParameters' "Solana malformed native transfer adversarial test"
require_pattern "$solana_tests" 'testBuildsCanonicalSPLTokenTransferCheckedTransactionEnvelope' "Solana SPL Token transfer-checked test"
require_pattern "$solana_tests" 'testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder' "Solana Token-2022 extra-account ordering test"
require_pattern "$solana_tests" 'testBuildsTokenSendWithIdempotentAssociatedTokenAccountCreateThenTransferChecked' "Solana ATA create plus transfer builder test"

require_file "$ton_builder" "TON Wallet V4R2 transaction builder"
require_pattern "$ton_builder" 'struct TonSignedExternalMessage' "TON signed external-message type"
require_pattern "$ton_builder" 'struct TonUnsignedEmulationMessage' "TON unsigned emulation-only type"
require_pattern "$ton_builder" 'static func buildForFeeEstimation' "TON private-key-free fee preview builder"
require_pattern "$ton_builder" 'maximumAddressInputBytes = 128' "TON cheap address-input byte cap"
require_pattern "$ton_builder" 'maximumAmountDigits = 37' "TON cheap builder amount-digit cap"
require_pattern "$ton_builder" 'maximumCommentBytes = 256' "TON cheap comment-input byte cap"
require_pattern "$ton_builder" 'let signingPayloadHashHex: String' "TON signing-payload binding field"
require_pattern "$ton_builder" 'let publicKey: Data' "TON persisted-message public-key binding field"
require_pattern "$ton_builder" 'static func rebuildSignedMessage' "TON fixed-signature canonical restore builder"
require_pattern "$ton_builder" 'static func inspectSignedMessage' "TON strict persisted-BOC inspector"
require_pattern "$ton_builder" 'TonCapturingTransferSigner' "TON signing-payload capture signer"
require_pattern "$ton_builder" 'TonFixedSignatureSigner' "TON fixed-signature restore signer"

require_file "$ton_fee_quote" "TON exact transfer fee quote"
require_pattern "$ton_fee_quote" 'struct TonTransferFeeQuote: Equatable, Sendable' "TON typed fee quote"
require_pattern "$ton_fee_quote" 'maximumAgeSeconds: UInt64 = 30' "TON 30-second fee quote freshness bound"
require_pattern "$ton_fee_quote" 'fearless\.ton\.fee-quote\.v1\\0' "TON domain-separated fee quote digest"
require_pattern "$ton_fee_quote" 'TonAPIClientFactory\.isReviewedProductionSendServerURL' "TON fee quote reviewed-origin binding"
require_pattern "$ton_fee_quote" 'unsignedMessage\.signingPayloadHashHex' "TON fee quote unsigned signing-payload binding"
require_pattern "$ton_fee_quote" 'SHA256\.hash\(data: unsignedMessage\.boc\)' "TON fee quote exact unsigned-BOC digest"
require_pattern "$ton_fee_quote" 'func validate\(at now: UInt64' "TON fee quote submission-time validation"

require_file "$ton_pending_journal" "TON durable pending-intent journal"
require_pattern "$ton_pending_journal" 'final class TonKeychainPendingIntentJournal' "TON Keychain pending-intent journal"
require_pattern "$ton_pending_journal" 'jp\.co\.soramitsu\.fearless\.ton\.pending\.v1\.' "TON versioned sender-scoped journal key"
require_pattern "$ton_pending_journal" 'maximumRecordBytes = 48 \* 1024' "TON bounded journal record"
require_pattern "$ton_pending_journal" 'case utf8Lexicographic' "TON runtime-independent canonical journal ordering"
require_pattern "$ton_pending_journal" 'case legacyFoundation17' "TON iOS 17 legacy journal migration order"
require_pattern "$ton_pending_journal" 'lhs\.0\.utf8\.lexicographicallyPrecedes\(rhs\.0\.utf8\)' "TON canonical journal UTF-8 comparator"
require_pattern "$ton_pending_journal" 'data == canonicalData \|\| data == legacyData' "TON strict canonical-or-legacy journal envelope gate"
require_pattern "$ton_pending_journal" 'case 0x22:' "TON canonical journal quote escaping"
require_pattern "$ton_pending_journal" 'case 0x5C:' "TON canonical journal backslash escaping"
require_pattern "$ton_pending_journal" 'isValidSignature\(inspection\.signature, for: signingHash\)' "TON persisted signature verification"
require_pattern "$ton_pending_journal" 'rebuildSignedMessage' "TON persisted BOC byte-for-byte rebuild"
require_pattern "$ton_pending_journal" 'guard rebuiltSigned\.boc == signedBoc' "TON persisted BOC exact equality gate"
require_pattern "$ton_pending_journal" 'guard let quote = pending\.feeQuote' "TON journal requires exact quote"
require_pattern "$ton_pending_journal" 'phase = "confirmed"' "TON confirmed journal tombstone phase"
require_pattern "$ton_pending_journal" 'var journalPhaseRank: Int' "TON journal phase ranking"
require_exact_pattern_count "$ton_pending_journal" 'pending\.journalPhaseRank >= existing\.journalPhaseRank' 2 "TON journal phase-monotonic save guards"
require_pattern "$ton_pending_journal" 'func hasSameBearer\(as other: TonPendingSignedIntent\)' "TON journal exact-bearer comparator"
require_exact_pattern_count "$ton_pending_journal" 'pending\.hasSameBearer\(as: existing\)' 2 "TON journal same-bearer overwrite guards"

require_file "$ton_send_service" "TON fail-closed send coordinator"
require_pattern "$ton_send_service" 'actor TonPendingIntentCoordinator' "TON per-sender pending-intent coordinator"
require_multiline_pattern "$ton_send_service" 'static let shared = TonPendingIntentCoordinator\([[:space:]]*productionJournal: TonKeychainPendingIntentJournal\(\)[[:space:]]*\)' "TON production coordinator Keychain journal binding"
require_pattern "$ton_send_service" 'journal\.load\(senderRaw: identity\.sender\)' "TON journal-first sender recovery"
require_multiline_pattern "$ton_send_service" 'try journal\.save\(pending\)[[:space:]]+statesBySender\[pending\.identity\.sender\] = \.pending' "TON durable reserve before in-memory exposure state"
require_pattern "$ton_send_service" 'try journal\.delete' "TON durable exact-confirmation cleanup"
require_pattern "$ton_send_service" 'func recordConfirmed\(' "TON durable confirmed tombstone write"
require_pattern "$ton_send_service" 'func acknowledgeConfirmed\(' "TON explicit confirmed tombstone acknowledgement"
require_pattern "$ton_send_service" 'case priorIntentConfirmed\(identity: TonTransferIntentIdentity, messageHashHex: String\)' "TON typed prior-confirmed recovery outcome"
require_multiline_pattern "$ton_send_service" 'func acknowledgeConfirmed\([\s\S]{0,900}guard pending\.confirmed,[[:space:]]*pending\.identity == identity,[[:space:]]*pending\.message\.messageHashHex == messageHashHex' "TON exact identity/hash confirmed acknowledgement"
require_multiline_pattern "$ton_send_service" 'func acknowledgeConfirmedTransfer\([\s\S]{0,500}guard let sender = try\? TonSwift\.Address\.parse\(senderAddress\),[[:space:]]*sender\.toRaw\(\) == identity\.sender' "TON friendly sender canonicalization before acknowledgement"
require_pattern "$ton_send_service" 'func requireStoredEndpointForRecovery' "TON stored-origin recovery gate"
require_pattern "$ton_send_service" 'storedOrigin == currentOrigin' "TON exact stored/current recovery-origin equality"
require_multiline_pattern "$ton_send_service" 'pendingCoordinator\.begin\(identity\)[\s\S]{0,1200}let credentials = try signingCredentials\(\)' "TON recovery-before-signing-credentials ordering"
require_multiline_pattern "$ton_send_service" 'if requiresFeeQuote \{[[:space:]]*return try await recoverPendingWithoutRebroadcast\(pending\)' "TON ordinary-submit no pending-BOC autorebroadcast"
require_pattern "$ton_send_service" 'pending = try await pendingCoordinator\.recordConfirmed\(pending\)' "TON tombstone-before-success return"
require_multiline_pattern "$ton_send_service" 'if storedPending\.confirmed \|\|[\s\S]{0,260}retained = storedPending' "TON stale recovery preserves confirmed phase"
require_multiline_pattern "$ton_send_service" 'try journal\.save\(retained\)[[:space:]]*statesBySender\[pending\.identity\.sender\] = \.pending\(retained\)' "TON retained pending durable-save-before-state ordering"
require_pattern "$ton_send_service" 'case broadcastOutcomeUnknown\(messageHashHex: String\)' "TON exact-hash unknown outcome"
require_pattern "$ton_send_service" 'func emulateUnsigned' "TON unsigned preview emulation seam"
require_pattern "$ton_send_service" 'func emulateSigned' "TON signed submission emulation seam"
require_pattern "$ton_send_service" 'func reconcile' "TON on-chain reconciliation seam"
require_pattern "$ton_send_service" 'case productionSendDisabled' "TON Release service fail-closed error"
require_multiline_pattern "$ton_send_service" '(?:^|\n)[ \t]*#if !DEBUG[ \t]*\r?\n(?:[ \t]*//[^\r\n]*\r?\n){0,4}[ \t]*throw TonSendServiceError\.productionSendDisabled[ \t]*\r?\n[ \t]*#else' "TON Release service compile-time fail-closed guard"
require_pattern "$ton_send_service" 'request\.amountNanotons\.utf8\.count <= 19' "TON cheap service amount-input cap"
require_pattern "$ton_send_service" 'comment\.utf8\.count > TonTransferTransactionBuilder\.maximumCommentBytes' "TON cheap pending-intent comment cap"
require_pattern "$ton_send_service" 'case untrustedSignedOperationEndpoint' "TON untrusted signed-operation error"
require_exact_pattern_count "$ton_send_service" 'try requireTrustedSignedOperationEndpoint\(\)' 3 "TON every signed remote operation endpoint guard"
require_multiline_pattern "$ton_send_service" '#if DEBUG[[:space:]]+init\(trustedTestClient client: any APIProtocol\)' "TON DEBUG-only signed-operation test capability"
require_pattern "$ton_send_service" 'func quote\(_ request: TonNativeEstimateRequest\)' "TON exact fee quote API"
require_pattern "$ton_send_service" 'case feeQuoteRequired' "TON fresh unquoted-send rejection"
require_pattern "$ton_send_service" 'requiresFeeQuote: true' "TON application send quote requirement"
require_multiline_pattern "$ton_send_service" '#if DEBUG[[:space:]]+///[^\n]*[[:space:]]+///[^\n]*[[:space:]]+func sendUnquotedForTesting' "TON DEBUG-only unquoted test seam"
require_pattern "$ton_send_service" 'rebuiltUnsigned == feeQuote\.unsignedMessage' "TON exact unsigned-template reproduction"
require_pattern "$ton_send_service" 'walletState == feeQuote\.walletState' "TON quote wallet-state drift rejection"
require_pattern "$ton_send_service" 'signedMessage\.signingPayloadHashHex == feeQuote\.unsignedMessage\.signingPayloadHashHex' "TON signed BOC template binding"
require_pattern "$ton_send_service" 'emulation\.totalFeeNanotons != feeQuote\.feeNanotons' "TON exact signed-emulation fee equality"

require_file "$ton_tests" "TON transaction builder and send tests"
require_pattern "$ton_tests" 'final class TonTransferTransactionBuilderTests' "TON transaction builder test class"
require_pattern "$ton_tests" 'testBuildsCanonicalWalletV4R2ExternalMessageGoldenVector' "TON canonical Wallet V4R2 golden vector"
require_pattern "$ton_tests" 'testSequenceZeroIncludesStateInitAndProducesStableDeploymentMessage' "TON deployment state-init vector"
require_pattern "$ton_tests" 'testFeeEstimationMessageHasCompileTimeDistinctInvalidSignature' "TON invalid-signature fee preview proof"
require_pattern "$ton_tests" 'testUnquotedPendingNeverRetriesWithoutStoredEndpointBinding' "TON unbound pending no-retry test"
require_pattern "$ton_tests" 'testRetryNeverRebroadcastsAfterReconciliationError' "TON reconciliation-error no-rebroadcast test"
require_pattern "$ton_tests" 'testMessageExpiringDuringEmulationIsNeverBroadcast' "TON pre-broadcast expiry adversarial test"
require_pattern "$ton_tests" 'testTonAPIRemoteClientFailsClosedForMalformedAndMismatchedRawBodies' "TON raw-message intent-binding adversarial test"
require_pattern "$ton_tests" 'testRejectsOversizedTextInputsAtCheapClassifierBounds' "TON cheap builder input-bound adversarial test"
require_pattern "$ton_tests" 'testTonAPIUnsignedEmulationUsesExactTraceEndpointBodyAndSignatureBypassQuery' "TON generated unsigned-emulation contract test"
require_pattern "$ton_tests" 'testTonAPIBroadcastUsesExactPathAndOneFieldBodyAndRejectsNon2xx' "TON generated broadcast contract test"
require_pattern "$ton_tests" 'testTonAPIReconciliationUsesExactMessageHashPathAndConfirmsExactIntent' "TON generated exact-hash reconciliation contract test"
require_pattern "$ton_tests" 'testTonAPIReconciliationTreatsOnly404AsNotFound' "TON 404-only rebroadcast authorization test"
require_pattern "$ton_tests" 'testTonAPIReconciliationFailsClosedForMalformedOrMismatchedTransactions' "TON generated reconciliation fail-closed adversarial test"
require_pattern "$ton_tests" 'testTonAPIWalletStateMapsLiveNullFieldsAndExactAccountSeqnoPaths' "TON generated live-null wallet-state mapping test"
require_pattern "$ton_tests" 'testTonAPIWalletAndMemoMappingRejectsExplicitDangerAndPreservesNullContract' "TON generated account-danger and memo mapping test"
require_pattern "$ton_tests" 'testReleaseSendFailsBeforeAnyValidationOrRemoteWork' "TON Release send fail-closed behavior test"
require_pattern "$ton_tests" 'testBoundQuoteReproducesExactTemplateAndExactFeeBeforeBroadcast' "TON exact quote/template/fee test"
require_pattern "$ton_tests" 'testFreshSendRequiresQuoteBeforeMnemonicDerivationOrRemoteWork' "TON unquoted fresh-send no-work test"
require_pattern "$ton_tests" 'testQuoteMutationExpiryWalletDriftAndFeeDriftAllFailClosed' "TON quote mutation/drift adversarial test"
require_pattern "$ton_tests" 'testProcessRestartLoadsJournalAndReconcilesBeforeAnyRebroadcast' "TON process-restart reconcile-first test"
require_pattern "$ton_tests" 'testJournalWriteFailurePreventsEverySignedRemoteExposure' "TON journal-write zero-exposure test"
require_pattern "$ton_tests" 'testFreshDisplayedQuoteNeverRebroadcastsOlderPendingBoc' "TON fresh-quote old-BOC no-rebroadcast test"
require_pattern "$ton_tests" 'testPersistedRecoveryRequiresStoredCredentialedEndpointBeforeRemoteWork' "TON persisted endpoint mismatch zero-work test"
require_pattern "$ton_tests" 'testPersistedRecoveryRunsBeforeSigningCredentialsAreRequested' "TON mnemonic-free persisted recovery test"
require_multiline_pattern "$ton_tests" 'stalePending\.confirmed = false[\s\S]{0,260}XCTAssertThrowsError\(try journal\.save\(stalePending\)\)[\s\S]{0,700}retainPending\(stalePending\)[\s\S]{0,260}XCTAssertTrue\([^\n]*\.confirmed\)' "TON deterministic confirmed-phase downgrade regression"
require_multiline_pattern "$ton_tests" 'let friendlySender[\s\S]{0,240}\.toFriendly\(\)[\s\S]{0,300}acknowledgeConfirmedTransfer\([\s\S]{0,240}senderAddress: friendlySender' "TON friendly-address acknowledgement regression"

require_file "$ton_pending_journal_tests" "TON durable journal tests"
require_pattern "$ton_pending_journal_tests" 'testVersionedJournalRoundTripRebuildsExactBearerWithoutSecrets' "TON journal exact round-trip/no-secret test"
require_pattern "$ton_pending_journal_tests" 'testCodecRejectsNoncanonicalCorruptAndCrossSenderRecords' "TON journal corruption/cross-sender adversarial test"
require_pattern "$ton_pending_journal_tests" 'testJournalConflictAndKeychainFailuresFailClosed' "TON journal conflict/Keychain failure test"
require_pattern "$ton_pending_journal_tests" 'maximumRecordBytes \+ 1' "TON oversized journal-record adversarial fixture"
require_pattern "$ton_pending_journal_tests" 'AlwaysFailingKeystore' "TON unavailable Keychain adversarial fixture"
require_pattern "$ton_pending_journal_tests" '0eb547b83019bdb5d66d62e35bc31053c00cbd68ba80599e9af1ccddd17e6958' "TON quote-ID known-answer vector"
require_pattern "$ton_pending_journal_tests" '3238980e4f69c2fdd20fa2666a713771b4bec2ee4154255f154f827679a05067' "TON journal canonical SHA-256 vector"
require_pattern "$ton_pending_journal_tests" 'b3d3d3d094dd14e4990e20f2ae569af11c02c50d6d9269d773ff591d1cda4500' "TON iOS 17 legacy journal SHA-256 vector"
require_pattern "$ton_pending_journal_tests" 'legacyFoundation17Encoding' "TON exact legacy journal migration fixture"
require_pattern "$ton_pending_journal_tests" 'testCanonicalEncodingEscapesUnicodeMemoAndOmitsNilMemo' "TON canonical journal escaping/optional-field regression"
require_pattern "$ton_pending_journal_tests" 'replacingWithStructurallyValidInvalidSignature' "TON structurally valid invalid-signature journal attack"

require_file "$chain_model" "TON canonical chain classifier"
require_pattern "$chain_model" '"-239"' "TON canonical mainnet chain-id classifier"
require_pattern "$chain_model" '"ton:mainnet"' "TON canonical CAIP-like mainnet classifier"

require_file "$chain_registry" "TON bounded authenticated transport"
require_pattern "$chain_registry" 'maximumResponseBytes' "TON response byte limit"
require_pattern "$chain_registry" 'withTaskCancellationHandler' "TON transport cancellation propagation"
require_pattern "$chain_registry" 'completionHandler\(nil\)' "TON redirect rejection"
require_pattern "$chain_registry" 'static let reviewedProductionSendOrigins = \[canonicalAuthenticatedOrigin\]' "TON binary-owned production endpoint allowlist"
require_pattern "$chain_registry" 'guard TonAPIClientFactory\.isReviewedProductionSendServerURL\(baseURL\)' "TON send-only exact-origin factory guard"
require_pattern "$chain_registry" 'static func isValidAuthorizationToken' "TON bounded visible-ASCII credential validator"
require_pattern "$chain_registry" '\(0x21 \.\.\. 0x7E\)\.contains\(byte\)' "TON credential control/whitespace rejection"
require_pattern "$chain_registry" 'hasReviewedProductionSendCredential' "TON reviewed credential capability"

require_file "$transfer_service" "Iroha transfer service signer seam"
require_pattern "$transfer_service" 'protocol IrohaTransferSigning' "Iroha transfer signer seam"
require_pattern "$transfer_service" 'struct IrohaTransferSigningRequest' "Iroha transfer signing request contract"
require_pattern "$transfer_service" 'struct IrohaSignedTransfer' "Iroha signed transfer contract"
require_pattern "$transfer_service" 'case tonProductionSendDisabled' "TON Release integration fail-closed error"
require_multiline_pattern "$transfer_service" '(?:^|\n)[ \t]*#if !DEBUG[ \t]*\r?\n(?:[ \t]*//[^\r\n]*\r?\n){0,4}[ \t]*throw TransferServiceError\.tonProductionSendDisabled[ \t]*\r?\n[ \t]*#else' "TON Release integration compile-time fail-closed guard"
require_pattern "$transfer_service" 'private final class TonTransferFeeQuoteStore: @unchecked Sendable' "TON synchronous transfer-service quote store"
require_pattern "$transfer_service" 'private let lock = NSLock\(\)' "TON quote-store synchronization"
require_pattern "$transfer_service" 'generation = generation == UInt64\.max \? 1 : generation \+ 1' "TON stale asynchronous quote generation guard"
require_pattern "$transfer_service" 'feeQuoteStore\.consume\(identity: identity\)' "TON atomic one-use quote consumption"
require_pattern "$transfer_service" 'sendService\.quote\(estimateRequest\)' "TON displayed fee sourced from exact quote"
require_pattern "$transfer_service" 'feeQuote: feeQuote' "TON exact quote propagation into send service"
require_pattern "$transfer_service" 'quote\.quoteIDHex == presentationID' "TON exact quote-ID presentation activation"
require_multiline_pattern "$transfer_service" 'func unsubscribe\(\) \{[[:space:]]*feeQuoteStore\.invalidate\(\)[[:space:]]*feeTask\?\.cancel\(\)' "TON synchronous unsubscribe quote revocation"
require_exact_pattern_count "$transfer_service" 'readyForSubmission: false' 2 "TON every fee-estimate path stages a non-submittable quote"
reject_multiline_pattern "$transfer_service" 'prepareFee\([\s\S]{0,180}readyForSubmission: true' "TON submittable fee-estimate path"
require_pattern "$transfer_service" 'case tonPriorTransferConfirmed\(identity: TonTransferIntentIdentity, messageHashHex: String\)' "TON typed integration prior-confirmed outcome"
require_multiline_pattern "$transfer_service" 'if case let \.priorIntentConfirmed\(identity, messageHashHex\) = error \{[\s\S]{0,300}throw TransferServiceError\.tonPriorTransferConfirmed\([[:space:]]*identity: identity,[[:space:]]*messageHashHex: messageHashHex' "TON prior-confirmed service-to-integration mapping"

require_file "$routing_tests" "Universal wallet send routing tests"
require_pattern "$routing_tests" 'testIrohaTransferServiceBuildsSignerRequestAndSubmitsNorito' "Iroha signer request and Torii submission test"
require_pattern "$routing_tests" 'testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation' "Iroha default signer fail-closed test"
require_pattern "$routing_tests" 'testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls' "Iroha mnemonic mismatch adversarial test"
require_pattern "$routing_tests" 'testProductionTonSendPolicyIsImmutableDisabledAndCannotBeBypassedByInjection' "TON immutable production-disable routing test"
require_pattern "$routing_tests" 'testTonCompatibilityChainDetectionByCanonicalIdWithoutMetadataHints' "TON canonical-id metadata-independent classifier test"
require_pattern "$routing_tests" 'testProductionTonSendPolicyRejectsCanonicalIdWithoutTonMetadataHints' "TON canonical-id production-disable routing test"
require_pattern "$routing_tests" 'testTonFeeEstimateNeverRequestsMnemonicOrProducesSignedEmulation' "TON mnemonic-free fee estimate test"
require_pattern "$routing_tests" 'testReleaseTonTransferSubmitFailsBeforeMnemonicOrRemoteWork' "TON Release integration no-secret/no-remote behavior test"
require_pattern "$routing_tests" 'testTonTransferServicePreservesExactUnknownOutcomeHash' "TON typed unknown-outcome propagation test"
require_pattern "$routing_tests" 'testCancellingTonApiTransportCancelsSessionTaskAndClearsState' "TON transport cancellation adversarial test"
require_pattern "$routing_tests" 'testHostileTonApiOriginCannotReceiveSignedOperations' "TON hostile-origin zero-request signed-operation test"
require_pattern "$routing_tests" 'testCanonicalTonApiFactoryIsRequiredForSignedOperations' "TON canonical-factory signed-operation capability test"
require_pattern "$routing_tests" 'testPrepareDependenciesCachesOneTonServiceAcrossConcurrentEstimateAndSubmit' "TON concurrent dependency-cache integration test"
require_pattern "$routing_tests" 'testTonQuoteCannotSubmitUntilExactPresentationIsAcknowledged' "TON undisplayed-quote zero-submit test"
require_pattern "$routing_tests" 'testTonUnsubscribeSynchronouslyRevokesQuoteBeforeImmediateSubmit' "TON immediate unsubscribe revocation test"
require_pattern "$routing_tests" 'testTonRestartRecoverySucceedsWithoutMnemonicAndWithoutNewBearer' "TON integration restart-without-mnemonic test"
require_pattern "$routing_tests" 'testCanonicalTonApiOriginStillRejectsMissingOrMalformedCredentialsForSignedOperations' "TON malformed credential zero-request test"
require_pattern "$routing_tests" 'testTonDirectEstimateNeverAuthorizesSubmission' "TON direct-estimate zero-submit regression"
require_pattern "$routing_tests" 'testTonDifferentIntentRecoveryNeverReturnsThePriorHashAsNewSuccess' "TON different-intent prior-confirmed integration regression"
require_pattern "$routing_tests" 'testTonFeePaymentAssetIgnoresAdditionalUnorderedUtilityAssets' "TON unordered utility-asset registry-confusion regression"

require_file "$send_confirm_presenter" "TON unknown-outcome recovery presenter"
require_pattern "$send_confirm_presenter" 'struct TonUnknownOutcomeRecoveryModel' "TON unknown-outcome recovery model"
require_pattern "$send_confirm_presenter" 'messageHashHex\.utf8\.count == 64' "TON unknown-outcome exact lowercase hash validation"
require_pattern "$send_confirm_presenter" 'TransferServiceError\.tonBroadcastOutcomeUnknown\(messageHashHex\)' "TON unknown-outcome dedicated presenter routing"
require_pattern "$send_confirm_presenter" 'key: "ton\.transfer\.unknown\.message"' "TON unknown-outcome no-resend recovery message"
require_pattern "$send_confirm_presenter" 'UIPasteboard\.general\.string = recovery\.messageHashHex' "TON unknown-outcome exact-hash copy action"
require_pattern "$send_confirm_presenter" 'TransferServiceError\.tonPriorTransferConfirmed\(identity, messageHashHex\)' "TON prior-confirmed presenter routing"
require_pattern "$send_confirm_presenter" 'presentTonPriorTransferConfirmed' "TON prior-confirmed acknowledgement UX"
require_pattern "$send_confirm_presenter" 'key: "ton\.transfer\.prior_confirmed\.acknowledge"' "TON prior-confirmed explicit acknowledgement action"
require_multiline_pattern "$send_confirm_presenter" 'chainAsset\.chain\.isTonCompatibilityChain[[:space:]]*\?[[:space:]]*\.exactCrypto\(fractionDigits: Int\(utilityAsset\.asset\.precision\)\)[[:space:]]*:[[:space:]]*\.detailsCrypto' "TON exact precision fee rendering"
require_multiline_pattern "$send_confirm_presenter" 'guard let completionWireframe = wireframe as\? WalletSendConfirmCompletionPresenting else \{[^}]*wireframe\.complete\([\s\S]{0,260}return[[:space:]]*\}' "TON no-callback success path retains confirmed tombstone"
reject_multiline_pattern "$send_confirm_presenter" 'guard let completionWireframe = wireframe as\? WalletSendConfirmCompletionPresenting else \{[^}]*acknowledgeSubmittedTransfer' "TON no-callback success path premature acknowledgement"
require_multiline_pattern "$send_confirm_presenter" 'completionWireframe\.completeAfterPresentation\([\s\S]{0,400}\) \{ \[weak self\] in[\s\S]{0,260}self\?\.interactor\.acknowledgeSubmittedTransfer' "TON success receipt callback-before-acknowledgement ordering"

require_file "$send_confirm_tests" "TON unknown-outcome recovery presenter tests"
require_pattern "$send_confirm_tests" 'testTonUnknownOutcomeRecoveryAcceptsExactLowercaseHash' "TON unknown-outcome exact-hash recovery test"
require_pattern "$send_confirm_tests" 'testTonUnknownOutcomeRecoveryRejectsMalformedOrDisplaySpoofedHashes' "TON unknown-outcome display-spoof adversarial test"
require_pattern "$send_confirm_tests" 'testTonExactFeeFormatterPreservesTheNinthDecimalAcrossLocales' "TON ninth-decimal locale rendering regression"
require_pattern "$send_confirm_tests" '\.exactCrypto\(fractionDigits: 9\)' "TON nine-decimal formatter test configuration"

require_file "$send_confirm_protocols" "TON visible-receipt completion protocol"
require_pattern "$send_confirm_protocols" 'protocol WalletSendConfirmCompletionPresenting: AnyObject' "TON visible-receipt completion capability"
require_pattern "$send_confirm_protocols" 'func completeAfterPresentation\(' "TON post-presentation completion callback contract"

require_file "$send_confirm_wireframe" "TON visible-receipt completion wireframe"
require_pattern "$send_confirm_wireframe" 'extension WalletSendConfirmWireframe: WalletSendConfirmCompletionPresenting' "TON production visible-receipt wireframe capability"
require_multiline_pattern "$send_confirm_wireframe" 'func completeAfterPresentation\([\s\S]{0,500}presentationCompletion: completion' "TON production presentation callback propagation"

require_file "$number_formatter" "TON exact crypto number formatter"
require_pattern "$number_formatter" 'case exactCrypto\(fractionDigits: Int\)' "TON exact crypto formatter usage case"
require_multiline_pattern "$number_formatter" 'case let \.exactCrypto\(fractionDigits\):[[:space:]]*return NumberFormatter\.defaultExactCryptoFormatter\(' "TON exact crypto formatter dispatch"

for locale in en id ja pt-PT pt ru tr vi zh-Hans; do
  localization="$ROOT_DIR/fearless/$locale.lproj/Localizable.strings"
  require_file "$localization" "TON unknown-outcome $locale localization"
  require_pattern "$localization" '^"ton\.transfer\.unknown\.title"' "TON unknown-outcome $locale title"
  require_pattern "$localization" '^"ton\.transfer\.unknown\.message".*%@' "TON unknown-outcome $locale exact-hash recovery message"
  require_pattern "$localization" '^"ton\.transfer\.unknown\.copy_hash"' "TON unknown-outcome $locale copy action"
  require_pattern "$localization" '^"ton\.transfer\.prior_confirmed\.title"' "TON prior-confirmed $locale title"
  require_pattern "$localization" '^"ton\.transfer\.prior_confirmed\.message".*%@' "TON prior-confirmed $locale exact-hash message"
  require_pattern "$localization" '^"ton\.transfer\.prior_confirmed\.acknowledge"' "TON prior-confirmed $locale acknowledgement action"
done

require_file "$send_container" "Send dependency container"
require_pattern "$send_container" 'static let production = TonProductionSendReleasePolicy\(isEnabled: false\)' "TON hard-disabled production release policy"
require_pattern "$send_container" 'private init\(isEnabled: Bool\)' "TON private release-policy initializer"
require_multiline_pattern "$send_container" '#if DEBUG[[:space:]]+static let enabledForTests = TonProductionSendReleasePolicy\(isEnabled: true\)[[:space:]]+#endif' "TON DEBUG-enclosed enablement policy"
require_pattern "$send_container" 'releasePolicy: \.production' "TON production initializer policy binding"
require_pattern "$send_container" 'tonProductionSendDisabled' "TON production fail-closed error"
require_pattern "$send_container" '@MainActor' "Send dependency cache main-actor serialization"
require_pattern "$send_container" 'cachedDependencies\[dependenciesKey\] = dependencies' "Send dependency cache population"
require_pattern "$send_container" 'currentDependenciesKey = dependenciesKey' "Send dependency active-key tracking"

require_file "$send_confirm_interactor" "TON quote-presentation interactor"
require_pattern "$send_confirm_interactor" 'TonTransferFeePresentationListener' "TON opaque quote-presentation callback"
require_pattern "$send_confirm_interactor" 'confirmFeePresentation' "TON rendered-fee acknowledgement bridge"
require_pattern "$send_confirm_interactor" 'acknowledgeSubmittedTransfer' "TON confirmed-receipt acknowledgement bridge"
require_multiline_pattern "$send_confirm_interactor" 'static func resolveFeePaymentChainAsset\(for chainAsset: ChainAsset\?\) -> ChainAsset\? \{[\s\S]{0,500}if chainAsset\.chain\.isTonCompatibilityChain \{[[:space:]]*return chainAsset[[:space:]]*\}[\s\S]{0,300}chainAsset\.chain\.utilityAssets\(\)\.first' "TON selected native fee asset pinned before unordered registry fallback"

require_pattern "$send_confirm_presenter" 'chainAsset\.chain\.isTonCompatibilityChain \? nil : feeViewModel' "TON stale incoming fee discarded"
require_pattern "$send_confirm_presenter" 'confirmPendingTonFeePresentationIfNeeded' "TON post-render fee acknowledgement"
require_multiline_pattern "$send_confirm_presenter" 'view\?\.didReceive\(state: \.loaded\(viewModel\)\)[[:space:]]*confirmPendingTonFeePresentationIfNeeded\(\)' "TON view-before-quote activation ordering"
require_pattern "$send_confirm_presenter" '!chainAsset\.chain\.isTonCompatibilityChain \|\| loadingCollector\.isReady' "TON confirmation readiness guard"

require_file "$release_checklist" "iOS release checklist"
require_pattern "$release_checklist" 'pending intents survive process' "TON durable restart-recovery release blocker"
require_pattern "$release_checklist" 'confirmation binds a fresh 30-second fee quote' "TON exact fee-quote binding release blocker"
require_pattern "$release_checklist" 'versioned, bounded, canonical Keychain journal' "TON implemented durable journal release truth"
require_pattern "$release_checklist" 'fresh 30-second fee quote' "TON implemented exact quote freshness truth"
require_pattern "$release_checklist" 'exact-hash unknown outcomes have explicit user-visible recovery UX' "TON unknown-outcome UX release blocker"
require_pattern "$release_checklist" 'immutable reviewed endpoint allowlist' "TON trusted endpoint provenance release blocker"
require_pattern "$release_checklist" 'current TonAPI schemas pass the bounded transport' "TON current-schema release blocker"
require_pattern "$release_checklist" 'exact fee parity with the corresponding signed Wallet V4R2' "TON unsigned/signed fee-parity release blocker"
require_pattern "$release_checklist" 'funded mainnet Wallet V4R2 transfer' "TON funded-mainnet evidence release blocker"
require_multiline_pattern "$release_checklist" 'confirmed terminal tombstone remains in[[:space:]]+the journal' "TON confirmed tombstone release truth"
require_pattern "$release_checklist" 'finalized-chain absence proof' "TON expired-pending recovery blocker"

if ((${#failures[@]} > 0)); then
  echo "[ios-transaction-builder-audit][error] iOS transaction-builder coverage audit failed:" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "[ios-transaction-builder-audit] iOS transaction-builder coverage audit passed."
