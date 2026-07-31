#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit-transaction-builder-tests.sh"
EXPECTED_DESTRUCTIVE_FIXTURES=120
executed_destructive_fixtures=0

fail() {
  echo "[ios-transaction-builder-audit-test][error] $*" >&2
  exit 1
}

write_file() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

write_valid_fixture() {
  local root="$1"

  write_file "$root/fearlessTests/BitcoinTransactionBuilderTests.swift" \
    "final class BitcoinTransactionBuilderTests {" \
    "  func testBuildsAndSignsMainnetP2wpkhTransactionMatchingWebVector() {}" \
    "  func testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning() {}" \
    "  func testRejectsUtxosThatDoNotMatchDerivedBip84KeyOrWitnessScript() {}" \
    "  func testRejectsEmptyMnemonicBeforeSigning() {}" \
    "}"

  write_file "$root/fearlessTests/SolanaTransferTransactionBuilderTests.swift" \
    "final class SolanaTransferTransactionBuilderTests {" \
    "  func testBuildsCanonicalLegacySystemTransferTransactionEnvelope() {}" \
    "  func testRejectsMalformedTransferParameters() {}" \
    "  func testBuildsCanonicalSPLTokenTransferCheckedTransactionEnvelope() {}" \
    "  func testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder() {}" \
    "  func testBuildsTokenSendWithIdempotentAssociatedTokenAccountCreateThenTransferChecked() {}" \
    "}"

  write_file "$root/fearless/Common/Model/TonTransferTransactionBuilder.swift" \
    "struct TonSignedExternalMessage { let signingPayloadHashHex: String; let publicKey: Data }" \
    "struct TonUnsignedEmulationMessage { let signingPayloadHashHex: String; let publicKey: Data }" \
    "let maximumAddressInputBytes = 128" \
    "let maximumAmountDigits = 37" \
    "let maximumCommentBytes = 256" \
    "enum TonTransferTransactionBuilder {" \
    "  static func buildForFeeEstimation() {}" \
    "  static func rebuildSignedMessage() {}" \
    "  static func inspectSignedMessage() {}" \
    "}" \
    "final class TonCapturingTransferSigner {}" \
    "struct TonFixedSignatureSigner {}"

  write_file "$root/fearless/Common/Model/TonTransferFeeQuote.swift" \
    "struct TonTransferFeeQuote: Equatable, Sendable {" \
    "  static let maximumAgeSeconds: UInt64 = 30" \
    '  let domain = Data("fearless.ton.fee-quote.v1\0".utf8)' \
    "  let unsignedMessage: TonUnsignedEmulationMessage" \
    "  init() {" \
    "    _ = TonAPIClientFactory.isReviewedProductionSendServerURL(endpointURL)" \
    "    _ = unsignedMessage.signingPayloadHashHex" \
    "    _ = SHA256.hash(data: unsignedMessage.boc)" \
    "  }" \
    "  func validate(at now: UInt64, endpointOrigin: String?) {}" \
    "}"

  write_file "$root/fearless/Common/Model/TonPendingIntentJournal.swift" \
    "private extension TonPendingSignedIntent {" \
    "  var journalPhaseRank: Int { confirmed ? 2 : 1 }" \
    "  func hasSameBearer(as other: TonPendingSignedIntent) -> Bool { identity == other.identity }" \
    "}" \
    "final class TonKeychainPendingIntentJournal {}" \
    'let identifierPrefix = "jp.co.soramitsu.fearless.ton.pending.v1."' \
    "let maximumRecordBytes = 48 * 1024" \
    "encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]" \
    "let valid = publicKey.isValidSignature(inspection.signature, for: signingHash)" \
    "let rebuiltSigned = TonTransferTransactionBuilder.rebuildSignedMessage()" \
    "guard rebuiltSigned.boc == signedBoc else { return }" \
    "guard let quote = pending.feeQuote else { return }" \
    'let phase = "confirmed"' \
    "guard pending.hasSameBearer(as: existing)," \
    "      pending.journalPhaseRank >= existing.journalPhaseRank else { return }" \
    "guard pending.hasSameBearer(as: existing)," \
    "      pending.journalPhaseRank >= existing.journalPhaseRank else { return }"

  write_file "$root/fearless/Common/Model/TonSendService.swift" \
    "protocol TonTransferRemoteProtocol {" \
    "  func emulateUnsigned()" \
    "  func emulateSigned()" \
    "  func reconcile()" \
    "}" \
    "enum TonSendServiceError { case productionSendDisabled; case feeQuoteRequired; case broadcastOutcomeUnknown(messageHashHex: String); case priorIntentConfirmed(identity: TonTransferIntentIdentity, messageHashHex: String) }" \
    "enum TonTransferRemoteError { case untrustedSignedOperationEndpoint }" \
    "actor TonPendingIntentCoordinator {" \
    "  static let shared = TonPendingIntentCoordinator(" \
    "    productionJournal: TonKeychainPendingIntentJournal()" \
    "  )" \
    "  func recover() throws {" \
    "    _ = try journal.load(senderRaw: identity.sender)" \
    "    try journal.save(pending)" \
    "    statesBySender[pending.identity.sender] = .pending(pending)" \
    "    try journal.delete(senderRaw: identity.sender)" \
    "  }" \
    "  func recordConfirmed(_ pending: TonPendingSignedIntent) throws {}" \
    "  func retainPending(_ pending: TonPendingSignedIntent) throws {" \
    "    let retained: TonPendingSignedIntent" \
    "    if storedPending.confirmed ||" \
    "       (storedPending.emulation != nil && pending.emulation == nil) {" \
    "      retained = storedPending" \
    "    } else {" \
    "      retained = pending" \
    "    }" \
    "    try journal.save(retained)" \
    "    statesBySender[pending.identity.sender] = .pending(retained)" \
    "  }" \
    "  func acknowledgeConfirmed(senderRaw: String, identity: TonTransferIntentIdentity, messageHashHex: String) throws {" \
    "    guard pending.confirmed," \
    "          pending.identity == identity," \
    "          pending.message.messageHashHex == messageHashHex else { return }" \
    "  }" \
    "}" \
    "func acknowledgeConfirmedTransfer(senderAddress: String, identity: TonTransferIntentIdentity) throws {" \
    "  guard let sender = try? TonSwift.Address.parse(senderAddress)," \
    "        sender.toRaw() == identity.sender else { return }" \
    "}" \
    "func requireStoredEndpointForRecovery() throws {" \
    "  guard storedOrigin == currentOrigin else { return }" \
    "}" \
    "func performSend() async throws {" \
    "  var pending = try await pendingCoordinator.begin(identity)" \
    "  if requiresFeeQuote {" \
    "    return try await recoverPendingWithoutRebroadcast(pending)" \
    "  }" \
    "  let credentials = try signingCredentials()" \
    "  pending = try await pendingCoordinator.recordConfirmed(pending)" \
    "}" \
    "func quote(_ request: TonNativeEstimateRequest) {}" \
    "let required = TonSendServiceError.feeQuoteRequired" \
    "performSend(requiresFeeQuote: true)" \
    "guard rebuiltUnsigned == feeQuote.unsignedMessage else { return }" \
    "guard walletState == feeQuote.walletState else { return }" \
    "guard signedMessage.signingPayloadHashHex == feeQuote.unsignedMessage.signingPayloadHashHex else { return }" \
    "guard emulation.totalFeeNanotons != feeQuote.feeNanotons else { return }" \
    "guard request.amountNanotons.utf8.count <= 19 else { return }" \
    "guard comment.utf8.count > TonTransferTransactionBuilder.maximumCommentBytes else { return }" \
    "try requireTrustedSignedOperationEndpoint()" \
    "try requireTrustedSignedOperationEndpoint()" \
    "try requireTrustedSignedOperationEndpoint()" \
    "#if DEBUG" \
    "init(trustedTestClient client: any APIProtocol) {}" \
    "#endif" \
    "#if DEBUG" \
    "/// Explicitly test-only compatibility seam." \
    "/// Application integration requires a quote." \
    "func sendUnquotedForTesting() {}" \
    "#endif" \
    "#if !DEBUG" \
    "throw TonSendServiceError.productionSendDisabled" \
    "#else" \
    "let debugOnlyTonSend = true" \
    "#endif"

  write_file "$root/fearless/Common/Model/ChainRegistry/ChainModel.swift" \
    "let canonicalTonChainIds = [\"-239\", \"ton:mainnet\"]"

  write_file "$root/fearless/Common/Services/ChainRegistry/ChainRegistry.swift" \
    "static let canonicalAuthenticatedOrigin = URL(string: \"https://tonapi.io\")!" \
    "static let reviewedProductionSendOrigins = [canonicalAuthenticatedOrigin]" \
    "static func isReviewedProductionSendServerURL(_ url: URL) -> Bool { true }" \
    "static func isValidAuthorizationToken(_ token: String) -> Bool {" \
    "  token.utf8.allSatisfy { byte in (0x21 ... 0x7E).contains(byte) }" \
    "}" \
    "let hasReviewedProductionSendCredential = true" \
    "guard TonAPIClientFactory.isReviewedProductionSendServerURL(baseURL) else { return }" \
    "let maximumResponseBytes = 2097152" \
    "func send() async { await withTaskCancellationHandler(operation: {}, onCancel: {}) }" \
    "func redirect(completionHandler: (Any?) -> Void) { completionHandler(nil) }"

  write_file "$root/fearlessTests/TonTransferTransactionBuilderTests.swift" \
    "final class TonTransferTransactionBuilderTests {" \
    "  func testBuildsCanonicalWalletV4R2ExternalMessageGoldenVector() {}" \
    "  func testSequenceZeroIncludesStateInitAndProducesStableDeploymentMessage() {}" \
    "  func testFeeEstimationMessageHasCompileTimeDistinctInvalidSignature() {}" \
    "  func testUnquotedPendingNeverRetriesWithoutStoredEndpointBinding() {}" \
    "  func testRetryNeverRebroadcastsAfterReconciliationError() {}" \
    "  func testMessageExpiringDuringEmulationIsNeverBroadcast() {}" \
    "  func testTonAPIRemoteClientFailsClosedForMalformedAndMismatchedRawBodies() {}" \
    "  func testRejectsOversizedTextInputsAtCheapClassifierBounds() {}" \
    "  func testTonAPIUnsignedEmulationUsesExactTraceEndpointBodyAndSignatureBypassQuery() {}" \
    "  func testTonAPIBroadcastUsesExactPathAndOneFieldBodyAndRejectsNon2xx() {}" \
    "  func testTonAPIReconciliationUsesExactMessageHashPathAndConfirmsExactIntent() {}" \
    "  func testTonAPIReconciliationTreatsOnly404AsNotFound() {}" \
    "  func testTonAPIReconciliationFailsClosedForMalformedOrMismatchedTransactions() {}" \
    "  func testTonAPIWalletStateMapsLiveNullFieldsAndExactAccountSeqnoPaths() {}" \
    "  func testTonAPIWalletAndMemoMappingRejectsExplicitDangerAndPreservesNullContract() {}" \
    "  func testReleaseSendFailsBeforeAnyValidationOrRemoteWork() {}" \
    "  func testBoundQuoteReproducesExactTemplateAndExactFeeBeforeBroadcast() {}" \
    "  func testFreshSendRequiresQuoteBeforeMnemonicDerivationOrRemoteWork() {}" \
    "  func testQuoteMutationExpiryWalletDriftAndFeeDriftAllFailClosed() {}" \
    "  func testProcessRestartLoadsJournalAndReconcilesBeforeAnyRebroadcast() {" \
    "    var stalePending = tombstone" \
    "    stalePending.confirmed = false" \
    "    XCTAssertThrowsError(try journal.save(stalePending))" \
    "    try await staleCoordinator.retainPending(stalePending)" \
    "    XCTAssertTrue(try XCTUnwrap(journal.load(senderRaw: sender)).confirmed)" \
    "    let friendlySender = try TonSwift.Address.parse(raw: sender)" \
    "      .toFriendly()" \
    "      .toString()" \
    "    try await recoveryService.acknowledgeConfirmedTransfer(" \
    "      senderAddress: friendlySender," \
    "      identity: identity," \
    "      messageHashHex: hash" \
    "    )" \
    "  }" \
    "  func testJournalWriteFailurePreventsEverySignedRemoteExposure() {}" \
    "  func testFreshDisplayedQuoteNeverRebroadcastsOlderPendingBoc() {}" \
    "  func testPersistedRecoveryRequiresStoredCredentialedEndpointBeforeRemoteWork() {}" \
    "  func testPersistedRecoveryRunsBeforeSigningCredentialsAreRequested() {}" \
    "}"

  write_file "$root/fearlessTests/TonPendingIntentJournalTests.swift" \
    "func testVersionedJournalRoundTripRebuildsExactBearerWithoutSecrets() {}" \
    "func testCodecRejectsNoncanonicalCorruptAndCrossSenderRecords() {" \
    "  _ = TonPendingIntentJournalCodec.maximumRecordBytes + 1" \
    "}" \
    "func testJournalConflictAndKeychainFailuresFailClosed() {}" \
    'let quoteIDGolden = "0eb547b83019bdb5d66d62e35bc31053c00cbd68ba80599e9af1ccddd17e6958"' \
    'let journalSHAGolden = "3238980e4f69c2fdd20fa2666a713771b4bec2ee4154255f154f827679a05067"' \
    "func replacingWithStructurallyValidInvalidSignature() {}" \
    "final class AlwaysFailingKeystore {}"

  write_file "$root/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift" \
    "protocol IrohaTransferSigning {}" \
    "struct IrohaTransferSigningRequest {}" \
    "struct IrohaSignedTransfer {}" \
    "enum TransferServiceError { case tonProductionSendDisabled; case tonPriorTransferConfirmed(identity: TonTransferIntentIdentity, messageHashHex: String) }" \
    "private final class TonTransferFeeQuoteStore: @unchecked Sendable {" \
    "  private let lock = NSLock()" \
    "  var generation: UInt64 = 0" \
    "  func next() { generation = generation == UInt64.max ? 1 : generation + 1 }" \
    "  func activate(quote: TonTransferFeeQuote, presentationID: String) {" \
    "    guard quote.quoteIDHex == presentationID else { return }" \
    "  }" \
    "}" \
    "let quote = sendService.quote(estimateRequest)" \
    "let consumed = feeQuoteStore.consume(identity: identity)" \
    "let result = sendService.send(request, feeQuote: feeQuote)" \
    "try await prepareFee(for: transfer, readyForSubmission: false).fee" \
    "let presentation = try await self.prepareFee(" \
    "  for: transfer," \
    "  readyForSubmission: false" \
    ")" \
    "if case let .priorIntentConfirmed(identity, messageHashHex) = error {" \
    "  throw TransferServiceError.tonPriorTransferConfirmed(" \
    "    identity: identity," \
    "    messageHashHex: messageHashHex" \
    "  )" \
    "}" \
    "func unsubscribe() {" \
    "  feeQuoteStore.invalidate()" \
    "  feeTask?.cancel()" \
    "}" \
    "#if !DEBUG" \
    "throw TransferServiceError.tonProductionSendDisabled" \
    "#else" \
    "let debugTonIntegrationSend = true" \
    "#endif"

  write_file "$root/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift" \
    "final class SendDependencyContainerUniversalWalletRoutingTests {" \
    "  func testIrohaTransferServiceBuildsSignerRequestAndSubmitsNorito() {}" \
    "  func testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation() {}" \
    "  func testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls() {}" \
    "  func testProductionTonSendPolicyIsImmutableDisabledAndCannotBeBypassedByInjection() {}" \
    "  func testTonCompatibilityChainDetectionByCanonicalIdWithoutMetadataHints() {}" \
    "  func testProductionTonSendPolicyRejectsCanonicalIdWithoutTonMetadataHints() {}" \
    "  func testTonFeeEstimateNeverRequestsMnemonicOrProducesSignedEmulation() {}" \
    "  func testReleaseTonTransferSubmitFailsBeforeMnemonicOrRemoteWork() {}" \
    "  func testTonTransferServicePreservesExactUnknownOutcomeHash() {}" \
    "  func testCancellingTonApiTransportCancelsSessionTaskAndClearsState() {}" \
    "  func testHostileTonApiOriginCannotReceiveSignedOperations() {}" \
    "  func testCanonicalTonApiFactoryIsRequiredForSignedOperations() {}" \
    "  func testPrepareDependenciesCachesOneTonServiceAcrossConcurrentEstimateAndSubmit() {}" \
    "  func testTonQuoteCannotSubmitUntilExactPresentationIsAcknowledged() {}" \
    "  func testTonUnsubscribeSynchronouslyRevokesQuoteBeforeImmediateSubmit() {}" \
    "  func testTonRestartRecoverySucceedsWithoutMnemonicAndWithoutNewBearer() {}" \
    "  func testCanonicalTonApiOriginStillRejectsMissingOrMalformedCredentialsForSignedOperations() {}" \
    "  func testTonDirectEstimateNeverAuthorizesSubmission() {}" \
    "  func testTonDifferentIntentRecoveryNeverReturnsThePriorHashAsNewSuccess() {}" \
    "  func testTonFeePaymentAssetIgnoresAdditionalUnorderedUtilityAssets() {}" \
    "}"

  write_file "$root/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmInteractor.swift" \
    "protocol TonTransferFeePresentationListener {}" \
    "func confirmFeePresentation(id: String, fee: Decimal) {}" \
    "func acknowledgeSubmittedTransfer(hash: String, transfer: Transfer) {}" \
    "static func resolveFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {" \
    "  guard let chainAsset else { return nil }" \
    "  if chainAsset.chain.isTonCompatibilityChain {" \
    "    return chainAsset" \
    "  }" \
    "  if let utilityAsset = chainAsset.chain.utilityAssets().first {" \
    "    return ChainAsset(chain: chainAsset.chain, asset: utilityAsset)" \
    "  }" \
    "  return chainAsset" \
    "}"

  write_file "$root/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmProtocols.swift" \
    "protocol WalletSendConfirmCompletionPresenting: AnyObject {" \
    "  func completeAfterPresentation(" \
    "    on view: ControllerBackedProtocol?," \
    "    title: String," \
    "    chainAsset: ChainAsset," \
    "    completion: @escaping () -> Void" \
    "  )" \
    "}"

  write_file "$root/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift" \
    "struct TonUnknownOutcomeRecoveryModel {" \
    "  let messageHashHex: String" \
    "  init?(messageHashHex: String) {" \
    "    guard messageHashHex.utf8.count == 64 else { return nil }" \
    "    self.messageHashHex = messageHashHex" \
    "  }" \
    "}" \
    "let displayedFee = chainAsset.chain.isTonCompatibilityChain ? nil : feeViewModel" \
    "func confirmPendingTonFeePresentationIfNeeded() {}" \
    "view?.didReceive(state: .loaded(viewModel))" \
    "confirmPendingTonFeePresentationIfNeeded()" \
    "let confirmationReady = !chainAsset.chain.isTonCompatibilityChain || loadingCollector.isReady" \
    "let feeUsageCase = chainAsset.chain.isTonCompatibilityChain" \
    "  ? .exactCrypto(fractionDigits: Int(utilityAsset.asset.precision))" \
    "  : .detailsCrypto" \
    "func presentTonPriorTransferConfirmed() {" \
    '  let action = tonRecoveryLocalizedString(key: "ton.transfer.prior_confirmed.acknowledge", fallback: "Acknowledge")' \
    "}" \
    "func completeTransferAfterVisibleReceipt() {" \
    "  guard let completionWireframe = wireframe as? WalletSendConfirmCompletionPresenting else {" \
    "    wireframe.complete(on: view, title: hash, chainAsset: chainAsset)" \
    "    return" \
    "  }" \
    "  completionWireframe.completeAfterPresentation(" \
    "    on: view," \
    "    title: hash," \
    "    chainAsset: chainAsset" \
    "  ) { [weak self] in" \
    "    self?.interactor.acknowledgeSubmittedTransfer(hash: hash)" \
    "  }" \
    "}" \
    "if case let TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex) = error {}" \
    "if case let TransferServiceError.tonPriorTransferConfirmed(identity, messageHashHex) = error {}" \
    'let message = tonRecoveryLocalizedString(key: "ton.transfer.unknown.message", fallback: "Do not resend")' \
    "UIPasteboard.general.string = recovery.messageHashHex"

  write_file "$root/fearlessTests/Modules/WalletSendConfirm/WalletSendConfirmTests.swift" \
    "func testTonUnknownOutcomeRecoveryAcceptsExactLowercaseHash() {}" \
    "func testTonUnknownOutcomeRecoveryRejectsMalformedOrDisplaySpoofedHashes() {}" \
    "func testTonExactFeeFormatterPreservesTheNinthDecimalAcrossLocales() {" \
    "  _ = NumberFormatter.formatter(for: .exactCrypto(fractionDigits: 9), locale: locale)" \
    "}"

  write_file "$root/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmWireframe.swift" \
    "extension WalletSendConfirmWireframe: WalletSendConfirmCompletionPresenting {" \
    "  func completeAfterPresentation(" \
    "    on view: ControllerBackedProtocol?," \
    "    title: String," \
    "    chainAsset: ChainAsset," \
    "    completion: @escaping () -> Void" \
    "  ) {" \
    "    complete(" \
    "      on: view," \
    "      title: title," \
    "      chainAsset: chainAsset," \
    "      presentationCompletion: completion" \
    "    )" \
    "  }" \
    "}"

  write_file "$root/fearless/Common/Extension/NumberFormatter+Default.swift" \
    "enum NumberFormatterUsageCase {" \
    "  case exactCrypto(fractionDigits: Int)" \
    "}" \
    "switch usageCase {" \
    "case let .exactCrypto(fractionDigits):" \
    "  return NumberFormatter.defaultExactCryptoFormatter(" \
    "    locale: locale," \
    "    fractionDigits: fractionDigits" \
    "  )" \
    "}"

  local locale
  for locale in en id ja pt-PT pt ru tr vi zh-Hans; do
    write_file "$root/fearless/$locale.lproj/Localizable.strings" \
      '"ton.transfer.unknown.title" = "Transfer status is unknown";' \
      '"ton.transfer.unknown.message" = "Do not send it again: %@";' \
      '"ton.transfer.unknown.copy_hash" = "Copy message hash";' \
      '"ton.transfer.prior_confirmed.title" = "Previous transfer confirmed";' \
      '"ton.transfer.prior_confirmed.message" = "Review the previous hash: %@";' \
      '"ton.transfer.prior_confirmed.acknowledge" = "Acknowledge";'
  done

  write_file "$root/fearless/Modules/Send/SendDependencyContainer.swift" \
    "struct TonProductionSendReleasePolicy {" \
    "  private init(isEnabled: Bool) { self.isEnabled = isEnabled }" \
    "  static let production = TonProductionSendReleasePolicy(isEnabled: false)" \
    "  let isEnabled: Bool" \
    "}" \
    "#if DEBUG" \
    "static let enabledForTests = TonProductionSendReleasePolicy(isEnabled: true)" \
    "#endif" \
    "let productionContainer = makeContainer(releasePolicy: .production)" \
    "enum UniversalWalletSendRoutingError { case tonProductionSendDisabled }" \
    "@MainActor func prepareDepencies() {" \
    "  cachedDependencies[dependenciesKey] = dependencies" \
    "  currentDependenciesKey = dependenciesKey" \
    "}"

  write_file "$root/docs/release-checklist.md" \
    "a versioned, bounded, canonical Keychain journal means pending intents survive process termination" \
    "confirmation binds a fresh 30-second fee quote to the exact signed BOC" \
    "exact-hash unknown outcomes have explicit user-visible recovery UX" \
    "signed emulation and broadcast require an immutable reviewed endpoint allowlist" \
    "a confirmed terminal tombstone remains in the journal until explicit acknowledgement" \
    "expired never-confirmed records require finalized-chain absence proof before quarantine" \
    "current TonAPI schemas pass the bounded transport adversarial suites and prove exact fee parity with the corresponding signed Wallet V4R2 template" \
    "a funded mainnet Wallet V4R2 transfer has independently verified evidence"
}

run_audit() {
  local root="$1"
  IOS_TX_BUILDER_AUDIT_ROOT="$root" bash "$AUDIT_SCRIPT"
}

expect_success() {
  local root="$1"
  if ! run_audit "$root" >/dev/null; then
    fail "valid fixture unexpectedly failed"
  fi
}

expect_failure() {
  local name="$1"
  local root="$2"
  local expected="$3"
  local output

  set +e
  output="$(run_audit "$root" 2>&1)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "$output" >&2
    fail "$name unexpectedly passed"
  fi

  if [[ "$output" != *"$expected"* ]]; then
    echo "$output" >&2
    fail "$name did not report expected text: $expected"
  fi

  executed_destructive_fixtures=$((executed_destructive_fixtures + 1))
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

valid="$tmp_dir/valid"
write_valid_fixture "$valid"
expect_success "$valid"

missing_bitcoin="$tmp_dir/missing-bitcoin"
write_valid_fixture "$missing_bitcoin"
perl -0pi -e 's/testRejectsUnsafeUtxosOutputsFeesAndChangeHandlingBeforeSigning/testRejectsSomeBitcoinInput/' "$missing_bitcoin/fearlessTests/BitcoinTransactionBuilderTests.swift"
expect_failure "missing Bitcoin adversarial test" "$missing_bitcoin" "Bitcoin unsafe UTXO/output/fee adversarial test"

missing_solana="$tmp_dir/missing-solana"
write_valid_fixture "$missing_solana"
perl -0pi -e 's/testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder/testBuildsToken2022Transfer/' "$missing_solana/fearlessTests/SolanaTransferTransactionBuilderTests.swift"
expect_failure "missing Solana Token-2022 test" "$missing_solana" "Solana Token-2022 extra-account ordering test"

missing_iroha="$tmp_dir/missing-iroha"
write_valid_fixture "$missing_iroha"
perl -0pi -e 's/testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation/testIrohaTransferServiceDefaultSigner/' "$missing_iroha/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing Iroha fail-closed test" "$missing_iroha" "Iroha default signer fail-closed test"

missing_ton="$tmp_dir/missing-ton"
write_valid_fixture "$missing_ton"
perl -0pi -e 's/isEnabled: false/isEnabled: true/' "$missing_ton/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "enabled TON production policy" "$missing_ton" "TON hard-disabled production release policy"

public_ton_policy_initializer="$tmp_dir/public-ton-policy-initializer"
write_valid_fixture "$public_ton_policy_initializer"
perl -0pi -e 's/private init\(isEnabled: Bool\)/init(isEnabled: Bool)/' "$public_ton_policy_initializer/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "public TON release-policy initializer" "$public_ton_policy_initializer" "TON private release-policy initializer"

missing_ton_debug_policy="$tmp_dir/missing-ton-debug-policy"
write_valid_fixture "$missing_ton_debug_policy"
perl -0pi -e 's/enabledForTests = TonProductionSendReleasePolicy\(isEnabled: true\)/enabledForTests = TonProductionSendReleasePolicy(isEnabled: false)/' "$missing_ton_debug_policy/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "missing TON DEBUG enablement policy" "$missing_ton_debug_policy" "TON DEBUG-enclosed enablement policy"

escaped_ton_debug_policy="$tmp_dir/escaped-ton-debug-policy"
write_valid_fixture "$escaped_ton_debug_policy"
perl -0pi -e 's/#if DEBUG\nstatic let enabledForTests = TonProductionSendReleasePolicy\(isEnabled: true\)\n#endif/#if DEBUG\nlet decoyDebugMarker = true\n#endif\nstatic let enabledForTests = TonProductionSendReleasePolicy(isEnabled: true)/' "$escaped_ton_debug_policy/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "TON enablement escaped DEBUG block" "$escaped_ton_debug_policy" "TON DEBUG-enclosed enablement policy"

bypass_ton_production_initializer="$tmp_dir/bypass-ton-production-initializer"
write_valid_fixture "$bypass_ton_production_initializer"
perl -0pi -e 's/releasePolicy: \.production/releasePolicy: .enabledForTests/' "$bypass_ton_production_initializer/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "bypassed TON production initializer" "$bypass_ton_production_initializer" "TON production initializer policy binding"

missing_ton_binding="$tmp_dir/missing-ton-binding"
write_valid_fixture "$missing_ton_binding"
perl -0pi -e 's/testTonAPIRemoteClientFailsClosedForMalformedAndMismatchedRawBodies/testTonAPIRemoteClientAcceptsAnyRawBody/' "$missing_ton_binding/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON raw-body binding test" "$missing_ton_binding" "TON raw-message intent-binding adversarial test"

missing_ton_unsigned_type="$tmp_dir/missing-ton-unsigned-type"
write_valid_fixture "$missing_ton_unsigned_type"
perl -0pi -e 's/TonUnsignedEmulationMessage/TonBroadcastablePreviewMessage/' "$missing_ton_unsigned_type/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "missing TON unsigned preview type" "$missing_ton_unsigned_type" "TON unsigned emulation-only type"

missing_ton_unsigned_builder="$tmp_dir/missing-ton-unsigned-builder"
write_valid_fixture "$missing_ton_unsigned_builder"
perl -0pi -e 's/buildForFeeEstimation/buildAndSignFeePreview/' "$missing_ton_unsigned_builder/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "missing TON unsigned preview builder" "$missing_ton_unsigned_builder" "TON private-key-free fee preview builder"

missing_ton_coordinator="$tmp_dir/missing-ton-coordinator"
write_valid_fixture "$missing_ton_coordinator"
perl -0pi -e 's/TonPendingIntentCoordinator/TonUncoordinatedSender/' "$missing_ton_coordinator/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON pending-intent coordinator" "$missing_ton_coordinator" "TON per-sender pending-intent coordinator"

missing_ton_unknown_hash="$tmp_dir/missing-ton-unknown-hash"
write_valid_fixture "$missing_ton_unknown_hash"
perl -0pi -e 's/broadcastOutcomeUnknown\(messageHashHex: String\)/broadcastFailed/' "$missing_ton_unknown_hash/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON exact unknown-outcome hash" "$missing_ton_unknown_hash" "TON exact-hash unknown outcome"

missing_ton_unsigned_seam="$tmp_dir/missing-ton-unsigned-seam"
write_valid_fixture "$missing_ton_unsigned_seam"
perl -0pi -e 's/emulateUnsigned/emulateSignedPreview/' "$missing_ton_unsigned_seam/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON unsigned emulation seam" "$missing_ton_unsigned_seam" "TON unsigned preview emulation seam"

missing_ton_retry="$tmp_dir/missing-ton-retry"
write_valid_fixture "$missing_ton_retry"
perl -0pi -e 's/testUnquotedPendingNeverRetriesWithoutStoredEndpointBinding/testUnquotedPendingRetriesWithoutEndpointBinding/' "$missing_ton_retry/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON unbound pending no-retry test" "$missing_ton_retry" "TON unbound pending no-retry test"

missing_ton_mnemonic_free_estimate="$tmp_dir/missing-ton-mnemonic-free-estimate"
write_valid_fixture "$missing_ton_mnemonic_free_estimate"
perl -0pi -e 's/testTonFeeEstimateNeverRequestsMnemonicOrProducesSignedEmulation/testTonFeeEstimateRequestsMnemonic/' "$missing_ton_mnemonic_free_estimate/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON mnemonic-free estimate" "$missing_ton_mnemonic_free_estimate" "TON mnemonic-free fee estimate test"

missing_ton_transport_cancellation_test="$tmp_dir/missing-ton-transport-cancellation-test"
write_valid_fixture "$missing_ton_transport_cancellation_test"
perl -0pi -e 's/testCancellingTonApiTransportCancelsSessionTaskAndClearsState/testCancellingTonApiTransportLeaksState/' "$missing_ton_transport_cancellation_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON transport cancellation test" "$missing_ton_transport_cancellation_test" "TON transport cancellation adversarial test"

missing_ton_transport_cancellation="$tmp_dir/missing-ton-transport-cancellation"
write_valid_fixture "$missing_ton_transport_cancellation"
perl -0pi -e 's/withTaskCancellationHandler/withoutTaskCancellationHandler/' "$missing_ton_transport_cancellation/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "missing TON transport cancellation propagation" "$missing_ton_transport_cancellation" "TON transport cancellation propagation"

missing_ton_builder_input_cap="$tmp_dir/missing-ton-builder-input-cap"
write_valid_fixture "$missing_ton_builder_input_cap"
perl -0pi -e 's/maximumAddressInputBytes = 128/maximumAddressInputBytes = Int.max/' "$missing_ton_builder_input_cap/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "missing TON builder input cap" "$missing_ton_builder_input_cap" "TON cheap address-input byte cap"

missing_ton_pending_amount_cap="$tmp_dir/missing-ton-pending-amount-cap"
write_valid_fixture "$missing_ton_pending_amount_cap"
perl -0pi -e 's/request\.amountNanotons\.utf8\.count <= 19/request.amountNanotons.utf8.count <= Int.max/' "$missing_ton_pending_amount_cap/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON pending amount cap" "$missing_ton_pending_amount_cap" "TON cheap service amount-input cap"

bypassed_ton_release_service_guard="$tmp_dir/bypassed-ton-release-service-guard"
write_valid_fixture "$bypassed_ton_release_service_guard"
perl -0pi -e 's/#if !DEBUG/#if DEBUG/' "$bypassed_ton_release_service_guard/fearless/Common/Model/TonSendService.swift"
expect_failure "bypassed TON Release service guard" "$bypassed_ton_release_service_guard" "TON Release service compile-time fail-closed guard"

comment_decoy_ton_release_service_guard="$tmp_dir/comment-decoy-ton-release-service-guard"
write_valid_fixture "$comment_decoy_ton_release_service_guard"
perl -0pi -e 's/#if !DEBUG/#if DEBUG/; $_ .= "\n\/\/ #if !DEBUG\n\/\/ throw TonSendServiceError.productionSendDisabled\n\/\/ #else\n"' "$comment_decoy_ton_release_service_guard/fearless/Common/Model/TonSendService.swift"
expect_failure "comment-decoy TON Release service guard" "$comment_decoy_ton_release_service_guard" "TON Release service compile-time fail-closed guard"

missing_ton_release_behavior_test="$tmp_dir/missing-ton-release-behavior-test"
write_valid_fixture "$missing_ton_release_behavior_test"
perl -0pi -e 's/testReleaseSendFailsBeforeAnyValidationOrRemoteWork/testReleaseSendAllowsRemoteWork/' "$missing_ton_release_behavior_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON Release behavior test" "$missing_ton_release_behavior_test" "TON Release send fail-closed behavior test"

missing_ton_broadcast_contract_test="$tmp_dir/missing-ton-broadcast-contract-test"
write_valid_fixture "$missing_ton_broadcast_contract_test"
perl -0pi -e 's/testTonAPIBroadcastUsesExactPathAndOneFieldBodyAndRejectsNon2xx/testTonAPIBroadcastAcceptsAnyResponse/' "$missing_ton_broadcast_contract_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON broadcast contract test" "$missing_ton_broadcast_contract_test" "TON generated broadcast contract test"

bypassed_ton_release_integration_guard="$tmp_dir/bypassed-ton-release-integration-guard"
write_valid_fixture "$bypassed_ton_release_integration_guard"
perl -0pi -e 's/#if !DEBUG/#if DEBUG/' "$bypassed_ton_release_integration_guard/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "bypassed TON Release integration guard" "$bypassed_ton_release_integration_guard" "TON Release integration compile-time fail-closed guard"

missing_ton_release_integration_behavior_test="$tmp_dir/missing-ton-release-integration-behavior-test"
write_valid_fixture "$missing_ton_release_integration_behavior_test"
perl -0pi -e 's/testReleaseTonTransferSubmitFailsBeforeMnemonicOrRemoteWork/testReleaseTonTransferSubmitLoadsMnemonic/' "$missing_ton_release_integration_behavior_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON Release integration behavior test" "$missing_ton_release_integration_behavior_test" "TON Release integration no-secret/no-remote behavior test"

missing_ton_canonical_id="$tmp_dir/missing-ton-canonical-id"
write_valid_fixture "$missing_ton_canonical_id"
perl -0pi -e 's/"-239"/"custom-mainnet"/' "$missing_ton_canonical_id/fearless/Common/Model/ChainRegistry/ChainModel.swift"
expect_failure "missing TON canonical chain id" "$missing_ton_canonical_id" "TON canonical mainnet chain-id classifier"

missing_ton_oversized_input_test="$tmp_dir/missing-ton-oversized-input-test"
write_valid_fixture "$missing_ton_oversized_input_test"
perl -0pi -e 's/testRejectsOversizedTextInputsAtCheapClassifierBounds/testAcceptsOversizedTextInputs/' "$missing_ton_oversized_input_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON oversized-input test" "$missing_ton_oversized_input_test" "TON cheap builder input-bound adversarial test"

missing_ton_generated_unsigned_test="$tmp_dir/missing-ton-generated-unsigned-test"
write_valid_fixture "$missing_ton_generated_unsigned_test"
perl -0pi -e 's/testTonAPIUnsignedEmulationUsesExactTraceEndpointBodyAndSignatureBypassQuery/testTonAPIUnsignedEmulationUsesAnyEndpoint/' "$missing_ton_generated_unsigned_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON generated unsigned-emulation test" "$missing_ton_generated_unsigned_test" "TON generated unsigned-emulation contract test"

missing_ton_exact_hash_reconciliation_test="$tmp_dir/missing-ton-exact-hash-reconciliation-test"
write_valid_fixture "$missing_ton_exact_hash_reconciliation_test"
perl -0pi -e 's/testTonAPIReconciliationUsesExactMessageHashPathAndConfirmsExactIntent/testTonAPIReconciliationUsesAnyTransaction/' "$missing_ton_exact_hash_reconciliation_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON exact-hash reconciliation test" "$missing_ton_exact_hash_reconciliation_test" "TON generated exact-hash reconciliation contract test"

missing_ton_404_only_test="$tmp_dir/missing-ton-404-only-test"
write_valid_fixture "$missing_ton_404_only_test"
perl -0pi -e 's/testTonAPIReconciliationTreatsOnly404AsNotFound/testTonAPIReconciliationTreatsEveryErrorAsNotFound/' "$missing_ton_404_only_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON 404-only reconciliation test" "$missing_ton_404_only_test" "TON 404-only rebroadcast authorization test"

missing_ton_reconciliation_mutation_test="$tmp_dir/missing-ton-reconciliation-mutation-test"
write_valid_fixture "$missing_ton_reconciliation_mutation_test"
perl -0pi -e 's/testTonAPIReconciliationFailsClosedForMalformedOrMismatchedTransactions/testTonAPIReconciliationAcceptsMismatchedTransactions/' "$missing_ton_reconciliation_mutation_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON reconciliation mutation test" "$missing_ton_reconciliation_mutation_test" "TON generated reconciliation fail-closed adversarial test"

missing_ton_live_null_mapping_test="$tmp_dir/missing-ton-live-null-mapping-test"
write_valid_fixture "$missing_ton_live_null_mapping_test"
perl -0pi -e 's/testTonAPIWalletStateMapsLiveNullFieldsAndExactAccountSeqnoPaths/testTonAPIWalletStateRejectsLiveNullFields/' "$missing_ton_live_null_mapping_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON live-null mapping test" "$missing_ton_live_null_mapping_test" "TON generated live-null wallet-state mapping test"

missing_ton_danger_memo_mapping_test="$tmp_dir/missing-ton-danger-memo-mapping-test"
write_valid_fixture "$missing_ton_danger_memo_mapping_test"
perl -0pi -e 's/testTonAPIWalletAndMemoMappingRejectsExplicitDangerAndPreservesNullContract/testTonAPIWalletAndMemoMappingIgnoresDanger/' "$missing_ton_danger_memo_mapping_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON danger/memo mapping test" "$missing_ton_danger_memo_mapping_test" "TON generated account-danger and memo mapping test"

missing_ton_canonical_classifier_test="$tmp_dir/missing-ton-canonical-classifier-test"
write_valid_fixture "$missing_ton_canonical_classifier_test"
perl -0pi -e 's/testTonCompatibilityChainDetectionByCanonicalIdWithoutMetadataHints/testTonCompatibilityChainDetectionRequiresMetadata/' "$missing_ton_canonical_classifier_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON canonical classifier test" "$missing_ton_canonical_classifier_test" "TON canonical-id metadata-independent classifier test"

missing_ton_canonical_release_gate_test="$tmp_dir/missing-ton-canonical-release-gate-test"
write_valid_fixture "$missing_ton_canonical_release_gate_test"
perl -0pi -e 's/testProductionTonSendPolicyRejectsCanonicalIdWithoutTonMetadataHints/testProductionTonSendPolicyIgnoresCanonicalId/' "$missing_ton_canonical_release_gate_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON canonical Release gate test" "$missing_ton_canonical_release_gate_test" "TON canonical-id production-disable routing test"

missing_ton_production_endpoint_allowlist="$tmp_dir/missing-ton-production-endpoint-allowlist"
write_valid_fixture "$missing_ton_production_endpoint_allowlist"
perl -0pi -e 's/reviewedProductionSendOrigins = \[canonicalAuthenticatedOrigin\]/reviewedProductionSendOrigins = []/' "$missing_ton_production_endpoint_allowlist/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "missing TON production endpoint allowlist" "$missing_ton_production_endpoint_allowlist" "TON binary-owned production endpoint allowlist"

bypassed_ton_send_endpoint_factory_guard="$tmp_dir/bypassed-ton-send-endpoint-factory-guard"
write_valid_fixture "$bypassed_ton_send_endpoint_factory_guard"
perl -0pi -e 's/guard TonAPIClientFactory\.isReviewedProductionSendServerURL\(baseURL\)/guard true/' "$bypassed_ton_send_endpoint_factory_guard/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "bypassed TON send endpoint factory guard" "$bypassed_ton_send_endpoint_factory_guard" "TON send-only exact-origin factory guard"

missing_ton_signed_operation_endpoint_guard="$tmp_dir/missing-ton-signed-operation-endpoint-guard"
write_valid_fixture "$missing_ton_signed_operation_endpoint_guard"
perl -0pi -e 's/try requireTrustedSignedOperationEndpoint\(\)//' "$missing_ton_signed_operation_endpoint_guard/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON signed operation endpoint guard" "$missing_ton_signed_operation_endpoint_guard" "TON every signed remote operation endpoint guard"

escaped_ton_signed_operation_test_capability="$tmp_dir/escaped-ton-signed-operation-test-capability"
write_valid_fixture "$escaped_ton_signed_operation_test_capability"
perl -0pi -e 's/#if DEBUG\ninit\(trustedTestClient/#if true\ninit(trustedTestClient/' "$escaped_ton_signed_operation_test_capability/fearless/Common/Model/TonSendService.swift"
expect_failure "escaped TON signed operation test capability" "$escaped_ton_signed_operation_test_capability" "TON DEBUG-only signed-operation test capability"

missing_ton_hostile_origin_zero_request_test="$tmp_dir/missing-ton-hostile-origin-zero-request-test"
write_valid_fixture "$missing_ton_hostile_origin_zero_request_test"
perl -0pi -e 's/testHostileTonApiOriginCannotReceiveSignedOperations/testHostileTonApiOriginReceivesUnsignedRequest/' "$missing_ton_hostile_origin_zero_request_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON hostile origin zero-request test" "$missing_ton_hostile_origin_zero_request_test" "TON hostile-origin zero-request signed-operation test"

missing_ton_canonical_factory_capability_test="$tmp_dir/missing-ton-canonical-factory-capability-test"
write_valid_fixture "$missing_ton_canonical_factory_capability_test"
perl -0pi -e 's/testCanonicalTonApiFactoryIsRequiredForSignedOperations/testAnyTonApiClientAllowsSignedOperations/' "$missing_ton_canonical_factory_capability_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON canonical factory capability test" "$missing_ton_canonical_factory_capability_test" "TON canonical-factory signed-operation capability test"

missing_ton_unknown_outcome_presenter_route="$tmp_dir/missing-ton-unknown-outcome-presenter-route"
write_valid_fixture "$missing_ton_unknown_outcome_presenter_route"
perl -0pi -e 's/TransferServiceError\.tonBroadcastOutcomeUnknown\(messageHashHex\)/TransferServiceError.transferFailed(reason)/' "$missing_ton_unknown_outcome_presenter_route/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "missing TON unknown outcome presenter route" "$missing_ton_unknown_outcome_presenter_route" "TON unknown-outcome dedicated presenter routing"

weakened_ton_unknown_outcome_hash_validation="$tmp_dir/weakened-ton-unknown-outcome-hash-validation"
write_valid_fixture "$weakened_ton_unknown_outcome_hash_validation"
perl -0pi -e 's/messageHashHex\.utf8\.count == 64/messageHashHex.utf8.count >= 1/' "$weakened_ton_unknown_outcome_hash_validation/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "weakened TON unknown outcome hash validation" "$weakened_ton_unknown_outcome_hash_validation" "TON unknown-outcome exact lowercase hash validation"

missing_ton_unknown_outcome_copy_action="$tmp_dir/missing-ton-unknown-outcome-copy-action"
write_valid_fixture "$missing_ton_unknown_outcome_copy_action"
perl -0pi -e 's/UIPasteboard\.general\.string = recovery\.messageHashHex/UIPasteboard.general.string = nil/' "$missing_ton_unknown_outcome_copy_action/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "missing TON unknown outcome copy action" "$missing_ton_unknown_outcome_copy_action" "TON unknown-outcome exact-hash copy action"

missing_ton_unknown_outcome_exact_hash_test="$tmp_dir/missing-ton-unknown-outcome-exact-hash-test"
write_valid_fixture "$missing_ton_unknown_outcome_exact_hash_test"
perl -0pi -e 's/testTonUnknownOutcomeRecoveryAcceptsExactLowercaseHash/testTonUnknownOutcomeRecoveryAcceptsAnyHash/' "$missing_ton_unknown_outcome_exact_hash_test/fearlessTests/Modules/WalletSendConfirm/WalletSendConfirmTests.swift"
expect_failure "missing TON unknown outcome exact hash test" "$missing_ton_unknown_outcome_exact_hash_test" "TON unknown-outcome exact-hash recovery test"

missing_ton_unknown_outcome_spoof_test="$tmp_dir/missing-ton-unknown-outcome-spoof-test"
write_valid_fixture "$missing_ton_unknown_outcome_spoof_test"
perl -0pi -e 's/testTonUnknownOutcomeRecoveryRejectsMalformedOrDisplaySpoofedHashes/testTonUnknownOutcomeRecoveryShowsMalformedHashes/' "$missing_ton_unknown_outcome_spoof_test/fearlessTests/Modules/WalletSendConfirm/WalletSendConfirmTests.swift"
expect_failure "missing TON unknown outcome spoof test" "$missing_ton_unknown_outcome_spoof_test" "TON unknown-outcome display-spoof adversarial test"

missing_ton_unknown_outcome_hash_localization="$tmp_dir/missing-ton-unknown-outcome-hash-localization"
write_valid_fixture "$missing_ton_unknown_outcome_hash_localization"
perl -0pi -e 's/Do not send it again: %@/Transfer failed/' "$missing_ton_unknown_outcome_hash_localization/fearless/en.lproj/Localizable.strings"
expect_failure "missing TON unknown outcome hash localization" "$missing_ton_unknown_outcome_hash_localization" "TON unknown-outcome en exact-hash recovery message"

missing_ton_restart_blocker="$tmp_dir/missing-ton-restart-blocker"
write_valid_fixture "$missing_ton_restart_blocker"
perl -0pi -e 's/pending intents survive process termination/pending intents are memory-only/' "$missing_ton_restart_blocker/docs/release-checklist.md"
expect_failure "missing TON restart-recovery blocker" "$missing_ton_restart_blocker" "TON durable restart-recovery release blocker"

missing_ton_fee_binding_blocker="$tmp_dir/missing-ton-fee-binding-blocker"
write_valid_fixture "$missing_ton_fee_binding_blocker"
perl -0pi -e 's/confirmation binds a fresh 30-second fee quote/confirmation displays an advisory fee/' "$missing_ton_fee_binding_blocker/docs/release-checklist.md"
expect_failure "missing TON fee-binding blocker" "$missing_ton_fee_binding_blocker" "TON exact fee-quote binding release blocker"

missing_ton_unknown_ux_blocker="$tmp_dir/missing-ton-unknown-ux-blocker"
write_valid_fixture "$missing_ton_unknown_ux_blocker"
perl -0pi -e 's/exact-hash unknown outcomes have explicit user-visible recovery UX/unknown outcomes use the generic error/' "$missing_ton_unknown_ux_blocker/docs/release-checklist.md"
expect_failure "missing TON unknown-outcome UX blocker" "$missing_ton_unknown_ux_blocker" "TON unknown-outcome UX release blocker"

missing_ton_endpoint_provenance_blocker="$tmp_dir/missing-ton-endpoint-provenance-blocker"
write_valid_fixture "$missing_ton_endpoint_provenance_blocker"
perl -0pi -e 's/immutable reviewed endpoint allowlist/any selected HTTPS endpoint/' "$missing_ton_endpoint_provenance_blocker/docs/release-checklist.md"
expect_failure "missing TON endpoint provenance blocker" "$missing_ton_endpoint_provenance_blocker" "TON trusted endpoint provenance release blocker"

missing_ton_current_schema_blocker="$tmp_dir/missing-ton-current-schema-blocker"
write_valid_fixture "$missing_ton_current_schema_blocker"
perl -0pi -e 's/current TonAPI schemas pass the bounded transport/current TonAPI schemas are assumed compatible/' "$missing_ton_current_schema_blocker/docs/release-checklist.md"
expect_failure "missing TON current-schema blocker" "$missing_ton_current_schema_blocker" "TON current-schema release blocker"

missing_ton_live_evidence_blocker="$tmp_dir/missing-ton-live-evidence-blocker"
write_valid_fixture "$missing_ton_live_evidence_blocker"
perl -0pi -e 's/a funded mainnet Wallet V4R2 transfer/a fixture-only Wallet V4R2 transfer/' "$missing_ton_live_evidence_blocker/docs/release-checklist.md"
expect_failure "missing TON funded-mainnet blocker" "$missing_ton_live_evidence_blocker" "TON funded-mainnet evidence release blocker"

missing_ton_signing_payload_field="$tmp_dir/missing-ton-signing-payload-field"
write_valid_fixture "$missing_ton_signing_payload_field"
perl -0pi -e 's/signingPayloadHashHex/signatureHashHex/g' "$missing_ton_signing_payload_field/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "missing TON signing payload field" "$missing_ton_signing_payload_field" "TON signing-payload binding field"

missing_ton_restore_builder="$tmp_dir/missing-ton-restore-builder"
write_valid_fixture "$missing_ton_restore_builder"
perl -0pi -e 's/rebuildSignedMessage/rebuildUncheckedMessage/g' "$missing_ton_restore_builder/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "missing TON canonical restore builder" "$missing_ton_restore_builder" "TON fixed-signature canonical restore builder"

missing_ton_fixed_signature_signer="$tmp_dir/missing-ton-fixed-signature-signer"
write_valid_fixture "$missing_ton_fixed_signature_signer"
perl -0pi -e 's/TonFixedSignatureSigner/TonUncheckedSignatureSigner/g' "$missing_ton_fixed_signature_signer/fearless/Common/Model/TonTransferTransactionBuilder.swift"
expect_failure "missing TON fixed signature signer" "$missing_ton_fixed_signature_signer" "TON fixed-signature restore signer"

missing_ton_fee_quote_file="$tmp_dir/missing-ton-fee-quote-file"
write_valid_fixture "$missing_ton_fee_quote_file"
rm "$missing_ton_fee_quote_file/fearless/Common/Model/TonTransferFeeQuote.swift"
expect_failure "missing TON fee quote file" "$missing_ton_fee_quote_file" "TON exact transfer fee quote missing"

weakened_ton_quote_age="$tmp_dir/weakened-ton-quote-age"
write_valid_fixture "$weakened_ton_quote_age"
perl -0pi -e 's/maximumAgeSeconds: UInt64 = 30/maximumAgeSeconds: UInt64 = 3600/' "$weakened_ton_quote_age/fearless/Common/Model/TonTransferFeeQuote.swift"
expect_failure "weakened TON quote age" "$weakened_ton_quote_age" "TON 30-second fee quote freshness bound"

changed_ton_quote_domain="$tmp_dir/changed-ton-quote-domain"
write_valid_fixture "$changed_ton_quote_domain"
perl -0pi -e 's/fearless\.ton\.fee-quote\.v1/fearless.ton.fee-quote.v0/' "$changed_ton_quote_domain/fearless/Common/Model/TonTransferFeeQuote.swift"
expect_failure "changed TON quote domain" "$changed_ton_quote_domain" "TON domain-separated fee quote digest"

bypassed_ton_quote_endpoint="$tmp_dir/bypassed-ton-quote-endpoint"
write_valid_fixture "$bypassed_ton_quote_endpoint"
perl -0pi -e 's/TonAPIClientFactory\.isReviewedProductionSendServerURL/allowAnyTonAPIURL/' "$bypassed_ton_quote_endpoint/fearless/Common/Model/TonTransferFeeQuote.swift"
expect_failure "bypassed TON quote endpoint" "$bypassed_ton_quote_endpoint" "TON fee quote reviewed-origin binding"

missing_ton_unsigned_boc_digest="$tmp_dir/missing-ton-unsigned-boc-digest"
write_valid_fixture "$missing_ton_unsigned_boc_digest"
perl -0pi -e 's/SHA256\.hash\(data: unsignedMessage\.boc\)/SHA256.hash(data: Data())/' "$missing_ton_unsigned_boc_digest/fearless/Common/Model/TonTransferFeeQuote.swift"
expect_failure "missing TON unsigned BOC digest" "$missing_ton_unsigned_boc_digest" "TON fee quote exact unsigned-BOC digest"

missing_ton_journal_file="$tmp_dir/missing-ton-journal-file"
write_valid_fixture "$missing_ton_journal_file"
rm "$missing_ton_journal_file/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "missing TON journal file" "$missing_ton_journal_file" "TON durable pending-intent journal missing"

weakened_ton_journal_bound="$tmp_dir/weakened-ton-journal-bound"
write_valid_fixture "$weakened_ton_journal_bound"
perl -0pi -e 's/maximumRecordBytes = 48 \* 1024/maximumRecordBytes = Int.max/' "$weakened_ton_journal_bound/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "weakened TON journal bound" "$weakened_ton_journal_bound" "TON bounded journal record"

missing_ton_journal_signature_verification="$tmp_dir/missing-ton-journal-signature-verification"
write_valid_fixture "$missing_ton_journal_signature_verification"
perl -0pi -e 's/isValidSignature\(inspection\.signature, for: signingHash\)/isValidSignature(Data(), for: Data())/' "$missing_ton_journal_signature_verification/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "missing TON journal signature verification" "$missing_ton_journal_signature_verification" "TON persisted signature verification"

missing_ton_journal_boc_equality="$tmp_dir/missing-ton-journal-boc-equality"
write_valid_fixture "$missing_ton_journal_boc_equality"
perl -0pi -e 's/guard rebuiltSigned\.boc == signedBoc/guard true/' "$missing_ton_journal_boc_equality/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "missing TON journal BOC equality" "$missing_ton_journal_boc_equality" "TON persisted BOC exact equality gate"

bypassed_ton_shared_keychain_journal="$tmp_dir/bypassed-ton-shared-keychain-journal"
write_valid_fixture "$bypassed_ton_shared_keychain_journal"
perl -0pi -e 's/productionJournal: TonKeychainPendingIntentJournal\(\)/productionJournal: TonInMemoryPendingIntentJournal()/' "$bypassed_ton_shared_keychain_journal/fearless/Common/Model/TonSendService.swift"
expect_failure "bypassed TON shared Keychain journal" "$bypassed_ton_shared_keychain_journal" "TON production coordinator Keychain journal binding"

missing_ton_journal_first_load="$tmp_dir/missing-ton-journal-first-load"
write_valid_fixture "$missing_ton_journal_first_load"
perl -0pi -e 's/journal\.load\(senderRaw: identity\.sender\)/memory.load(senderRaw: identity.sender)/' "$missing_ton_journal_first_load/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON journal-first load" "$missing_ton_journal_first_load" "TON journal-first sender recovery"

reordered_ton_durable_reserve="$tmp_dir/reordered-ton-durable-reserve"
write_valid_fixture "$reordered_ton_durable_reserve"
perl -0pi -e 's/try journal\.save\(pending\)\n[[:space:]]*statesBySender\[pending\.identity\.sender\] = \.pending\(pending\)/statesBySender[pending.identity.sender] = .pending(pending)\n    try journal.save(pending)/' "$reordered_ton_durable_reserve/fearless/Common/Model/TonSendService.swift"
expect_failure "reordered TON durable reserve" "$reordered_ton_durable_reserve" "TON durable reserve before in-memory exposure state"

bypassed_ton_quote_requirement="$tmp_dir/bypassed-ton-quote-requirement"
write_valid_fixture "$bypassed_ton_quote_requirement"
perl -0pi -e 's/requiresFeeQuote: true/requiresFeeQuote: false/' "$bypassed_ton_quote_requirement/fearless/Common/Model/TonSendService.swift"
expect_failure "bypassed TON quote requirement" "$bypassed_ton_quote_requirement" "TON application send quote requirement"

escaped_ton_unquoted_test_seam="$tmp_dir/escaped-ton-unquoted-test-seam"
write_valid_fixture "$escaped_ton_unquoted_test_seam"
perl -0pi -e 's/#if DEBUG\n\/\/\/ Explicitly test-only compatibility seam\./#if true\n\/\/\/ Explicitly test-only compatibility seam./' "$escaped_ton_unquoted_test_seam/fearless/Common/Model/TonSendService.swift"
expect_failure "escaped TON unquoted test seam" "$escaped_ton_unquoted_test_seam" "TON DEBUG-only unquoted test seam"

missing_ton_unsigned_template_comparison="$tmp_dir/missing-ton-unsigned-template-comparison"
write_valid_fixture "$missing_ton_unsigned_template_comparison"
perl -0pi -e 's/rebuiltUnsigned == feeQuote\.unsignedMessage/true/' "$missing_ton_unsigned_template_comparison/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON unsigned template comparison" "$missing_ton_unsigned_template_comparison" "TON exact unsigned-template reproduction"

missing_ton_wallet_state_drift_gate="$tmp_dir/missing-ton-wallet-state-drift-gate"
write_valid_fixture "$missing_ton_wallet_state_drift_gate"
perl -0pi -e 's/walletState == feeQuote\.walletState/true/' "$missing_ton_wallet_state_drift_gate/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON wallet state drift gate" "$missing_ton_wallet_state_drift_gate" "TON quote wallet-state drift rejection"

missing_ton_exact_fee_equality="$tmp_dir/missing-ton-exact-fee-equality"
write_valid_fixture "$missing_ton_exact_fee_equality"
perl -0pi -e 's/emulation\.totalFeeNanotons != feeQuote\.feeNanotons/emulation.totalFeeNanotons == feeQuote.feeNanotons/' "$missing_ton_exact_fee_equality/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON exact fee equality" "$missing_ton_exact_fee_equality" "TON exact signed-emulation fee equality"

missing_ton_quote_binding_test="$tmp_dir/missing-ton-quote-binding-test"
write_valid_fixture "$missing_ton_quote_binding_test"
perl -0pi -e 's/testBoundQuoteReproducesExactTemplateAndExactFeeBeforeBroadcast/testBoundQuoteAllowsFeeDrift/' "$missing_ton_quote_binding_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON quote binding test" "$missing_ton_quote_binding_test" "TON exact quote/template/fee test"

missing_ton_restart_recovery_test="$tmp_dir/missing-ton-restart-recovery-test"
write_valid_fixture "$missing_ton_restart_recovery_test"
perl -0pi -e 's/testProcessRestartLoadsJournalAndReconcilesBeforeAnyRebroadcast/testProcessRestartBuildsNewMessage/' "$missing_ton_restart_recovery_test/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON restart recovery test" "$missing_ton_restart_recovery_test" "TON process-restart reconcile-first test"

missing_ton_journal_corruption_test="$tmp_dir/missing-ton-journal-corruption-test"
write_valid_fixture "$missing_ton_journal_corruption_test"
perl -0pi -e 's/testCodecRejectsNoncanonicalCorruptAndCrossSenderRecords/testCodecAcceptsCorruptRecords/' "$missing_ton_journal_corruption_test/fearlessTests/TonPendingIntentJournalTests.swift"
expect_failure "missing TON journal corruption test" "$missing_ton_journal_corruption_test" "TON journal corruption/cross-sender adversarial test"

missing_ton_quote_consumption="$tmp_dir/missing-ton-quote-consumption"
write_valid_fixture "$missing_ton_quote_consumption"
perl -0pi -e 's/feeQuoteStore\.consume\(identity: identity\)/feeQuoteStore.peek(identity: identity)/' "$missing_ton_quote_consumption/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "missing TON quote consumption" "$missing_ton_quote_consumption" "TON atomic one-use quote consumption"

missing_ton_fee_parity_blocker="$tmp_dir/missing-ton-fee-parity-blocker"
write_valid_fixture "$missing_ton_fee_parity_blocker"
perl -0pi -e 's/exact fee parity with the corresponding signed Wallet V4R2/exact fees are assumed for the signed Wallet V4R2/' "$missing_ton_fee_parity_blocker/docs/release-checklist.md"
expect_failure "missing TON fee parity blocker" "$missing_ton_fee_parity_blocker" "TON unsigned/signed fee-parity release blocker"

missing_ton_confirmed_journal_phase="$tmp_dir/missing-ton-confirmed-journal-phase"
write_valid_fixture "$missing_ton_confirmed_journal_phase"
perl -0pi -e 's/phase = "confirmed"/phase = "pending"/' "$missing_ton_confirmed_journal_phase/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "missing TON confirmed journal phase" "$missing_ton_confirmed_journal_phase" "TON confirmed journal tombstone phase"

missing_ton_tombstone_before_success="$tmp_dir/missing-ton-tombstone-before-success"
write_valid_fixture "$missing_ton_tombstone_before_success"
perl -0pi -e 's/pendingCoordinator\.recordConfirmed\(pending\)/pendingCoordinator.finishInMemory(pending)/' "$missing_ton_tombstone_before_success/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON tombstone before success" "$missing_ton_tombstone_before_success" "TON tombstone-before-success return"

missing_ton_confirmed_acknowledgement="$tmp_dir/missing-ton-confirmed-acknowledgement"
write_valid_fixture "$missing_ton_confirmed_acknowledgement"
perl -0pi -e 's/func acknowledgeConfirmed\(senderRaw:/func clearConfirmed(senderRaw:/' "$missing_ton_confirmed_acknowledgement/fearless/Common/Model/TonSendService.swift"
expect_failure "missing TON confirmed acknowledgement" "$missing_ton_confirmed_acknowledgement" "TON explicit confirmed tombstone acknowledgement"

weakened_ton_stored_endpoint_equality="$tmp_dir/weakened-ton-stored-endpoint-equality"
write_valid_fixture "$weakened_ton_stored_endpoint_equality"
perl -0pi -e 's/storedOrigin == currentOrigin/storedOrigin.host == currentOrigin.host/' "$weakened_ton_stored_endpoint_equality/fearless/Common/Model/TonSendService.swift"
expect_failure "weakened TON stored endpoint equality" "$weakened_ton_stored_endpoint_equality" "TON exact stored/current recovery-origin equality"

signing_before_ton_recovery="$tmp_dir/signing-before-ton-recovery"
write_valid_fixture "$signing_before_ton_recovery"
perl -0pi -e 's/  var pending = try await pendingCoordinator\.begin\(identity\)/  let credentials = try signingCredentials()\n  var pending = try await pendingCoordinator.begin(identity)/; s/\n  let credentials = try signingCredentials\(\)\n  pending =/\n  pending =/' "$signing_before_ton_recovery/fearless/Common/Model/TonSendService.swift"
expect_failure "TON signing before pending recovery" "$signing_before_ton_recovery" "TON recovery-before-signing-credentials ordering"

ordinary_ton_submit_rebroadcasts_pending="$tmp_dir/ordinary-ton-submit-rebroadcasts-pending"
write_valid_fixture "$ordinary_ton_submit_rebroadcasts_pending"
perl -0pi -e 's/recoverPendingWithoutRebroadcast\(pending\)/retryPendingBroadcast(pending)/' "$ordinary_ton_submit_rebroadcasts_pending/fearless/Common/Model/TonSendService.swift"
expect_failure "ordinary TON submit rebroadcasts pending BOC" "$ordinary_ton_submit_rebroadcasts_pending" "TON ordinary-submit no pending-BOC autorebroadcast"

changed_ton_quote_id_golden="$tmp_dir/changed-ton-quote-id-golden"
write_valid_fixture "$changed_ton_quote_id_golden"
perl -0pi -e 's/0eb547b83019bdb5d66d62e35bc31053c00cbd68ba80599e9af1ccddd17e6958/1eb547b83019bdb5d66d62e35bc31053c00cbd68ba80599e9af1ccddd17e6958/' "$changed_ton_quote_id_golden/fearlessTests/TonPendingIntentJournalTests.swift"
expect_failure "changed TON quote-ID golden" "$changed_ton_quote_id_golden" "TON quote-ID known-answer vector"

changed_ton_journal_sha_golden="$tmp_dir/changed-ton-journal-sha-golden"
write_valid_fixture "$changed_ton_journal_sha_golden"
perl -0pi -e 's/3238980e4f69c2fdd20fa2666a713771b4bec2ee4154255f154f827679a05067/4238980e4f69c2fdd20fa2666a713771b4bec2ee4154255f154f827679a05067/' "$changed_ton_journal_sha_golden/fearlessTests/TonPendingIntentJournalTests.swift"
expect_failure "changed TON journal SHA golden" "$changed_ton_journal_sha_golden" "TON journal canonical SHA-256 vector"

missing_ton_structural_invalid_signature_attack="$tmp_dir/missing-ton-structural-invalid-signature-attack"
write_valid_fixture "$missing_ton_structural_invalid_signature_attack"
perl -0pi -e 's/replacingWithStructurallyValidInvalidSignature/replacingWithTruncatedSignature/' "$missing_ton_structural_invalid_signature_attack/fearlessTests/TonPendingIntentJournalTests.swift"
expect_failure "missing TON structural invalid-signature attack" "$missing_ton_structural_invalid_signature_attack" "TON structurally valid invalid-signature journal attack"

missing_ton_credential_validator="$tmp_dir/missing-ton-credential-validator"
write_valid_fixture "$missing_ton_credential_validator"
perl -0pi -e 's/static func isValidAuthorizationToken/static func acceptsAuthorizationToken/' "$missing_ton_credential_validator/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "missing TON credential validator" "$missing_ton_credential_validator" "TON bounded visible-ASCII credential validator"

weakened_ton_credential_ascii_range="$tmp_dir/weakened-ton-credential-ascii-range"
write_valid_fixture "$weakened_ton_credential_ascii_range"
perl -0pi -e 's/\(0x21 \.\.\. 0x7E\)\.contains\(byte\)/(0x00 ... 0x7F).contains(byte)/' "$weakened_ton_credential_ascii_range/fearless/Common/Services/ChainRegistry/ChainRegistry.swift"
expect_failure "weakened TON credential ASCII range" "$weakened_ton_credential_ascii_range" "TON credential control/whitespace rejection"

unlocked_ton_quote_store="$tmp_dir/unlocked-ton-quote-store"
write_valid_fixture "$unlocked_ton_quote_store"
perl -0pi -e 's/private let lock = NSLock\(\)/private let lock = NSObject()/' "$unlocked_ton_quote_store/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "unlocked TON quote store" "$unlocked_ton_quote_store" "TON quote-store synchronization"

asynchronous_ton_unsubscribe="$tmp_dir/asynchronous-ton-unsubscribe"
write_valid_fixture "$asynchronous_ton_unsubscribe"
perl -0pi -e 's/func unsubscribe\(\) \{\n  feeQuoteStore\.invalidate\(\)\n  feeTask\?\.cancel\(\)/func unsubscribe() {\n  feeTask?.cancel()\n  feeQuoteStore.invalidate()/' "$asynchronous_ton_unsubscribe/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "asynchronous TON unsubscribe revocation" "$asynchronous_ton_unsubscribe" "TON synchronous unsubscribe quote revocation"

bypassed_ton_quote_id_activation="$tmp_dir/bypassed-ton-quote-id-activation"
write_valid_fixture "$bypassed_ton_quote_id_activation"
perl -0pi -e 's/quote\.quoteIDHex == presentationID/true/' "$bypassed_ton_quote_id_activation/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "bypassed TON quote-ID activation" "$bypassed_ton_quote_id_activation" "TON exact quote-ID presentation activation"

unserialized_send_dependency_cache="$tmp_dir/unserialized-send-dependency-cache"
write_valid_fixture "$unserialized_send_dependency_cache"
perl -0pi -e 's/\@MainActor func prepareDepencies/func prepareDepencies/' "$unserialized_send_dependency_cache/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "unserialized send dependency cache" "$unserialized_send_dependency_cache" "Send dependency cache main-actor serialization"

missing_send_dependency_cache_population="$tmp_dir/missing-send-dependency-cache-population"
write_valid_fixture "$missing_send_dependency_cache_population"
perl -0pi -e 's/cachedDependencies\[dependenciesKey\] = dependencies/cachedDependencies.removeValue(forKey: dependenciesKey)/' "$missing_send_dependency_cache_population/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "missing send dependency cache population" "$missing_send_dependency_cache_population" "Send dependency cache population"

missing_send_dependency_active_key="$tmp_dir/missing-send-dependency-active-key"
write_valid_fixture "$missing_send_dependency_active_key"
perl -0pi -e 's/currentDependenciesKey = dependenciesKey/currentDependenciesKey = nil/' "$missing_send_dependency_active_key/fearless/Modules/Send/SendDependencyContainer.swift"
expect_failure "missing send dependency active key" "$missing_send_dependency_active_key" "Send dependency active-key tracking"

activated_ton_quote_before_view_render="$tmp_dir/activated-ton-quote-before-view-render"
write_valid_fixture "$activated_ton_quote_before_view_render"
perl -0pi -e 's/view\?\.didReceive\(state: \.loaded\(viewModel\)\)\nconfirmPendingTonFeePresentationIfNeeded\(\)/confirmPendingTonFeePresentationIfNeeded()\nview?.didReceive(state: .loaded(viewModel))/' "$activated_ton_quote_before_view_render/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "TON quote activated before view render" "$activated_ton_quote_before_view_render" "TON view-before-quote activation ordering"

bypassed_ton_confirmation_readiness="$tmp_dir/bypassed-ton-confirmation-readiness"
write_valid_fixture "$bypassed_ton_confirmation_readiness"
perl -0pi -e 's/!chainAsset\.chain\.isTonCompatibilityChain \|\| loadingCollector\.isReady/!chainAsset.chain.isTonCompatibilityChain \&\& loadingCollector.isReady/' "$bypassed_ton_confirmation_readiness/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "bypassed TON confirmation readiness" "$bypassed_ton_confirmation_readiness" "TON confirmation readiness guard"

missing_ton_finality_absence_blocker="$tmp_dir/missing-ton-finality-absence-blocker"
write_valid_fixture "$missing_ton_finality_absence_blocker"
perl -0pi -e 's/finalized-chain absence proof/local timeout/' "$missing_ton_finality_absence_blocker/docs/release-checklist.md"
expect_failure "missing TON finality absence blocker" "$missing_ton_finality_absence_blocker" "TON expired-pending recovery blocker"

submittable_ton_direct_estimate="$tmp_dir/submittable-ton-direct-estimate"
write_valid_fixture "$submittable_ton_direct_estimate"
perl -0pi -e 's/readyForSubmission: false/readyForSubmission: true/' "$submittable_ton_direct_estimate/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "submittable TON direct estimate" "$submittable_ton_direct_estimate" "TON every fee-estimate path stages a non-submittable quote"

missing_ton_direct_estimate_regression="$tmp_dir/missing-ton-direct-estimate-regression"
write_valid_fixture "$missing_ton_direct_estimate_regression"
perl -0pi -e 's/testTonDirectEstimateNeverAuthorizesSubmission/testTonDirectEstimateReturnsFee/' "$missing_ton_direct_estimate_regression/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON direct-estimate regression" "$missing_ton_direct_estimate_regression" "TON direct-estimate zero-submit regression"

downgraded_ton_prior_confirmed_mapping="$tmp_dir/downgraded-ton-prior-confirmed-mapping"
write_valid_fixture "$downgraded_ton_prior_confirmed_mapping"
perl -0pi -e 's/throw TransferServiceError\.tonPriorTransferConfirmed\(/throw TransferServiceError.tonBroadcastOutcomeUnknown(/' "$downgraded_ton_prior_confirmed_mapping/fearless/ApplicationLayer/Services/Transfer/Tokens/TransferService.swift"
expect_failure "downgraded TON prior-confirmed mapping" "$downgraded_ton_prior_confirmed_mapping" "TON prior-confirmed service-to-integration mapping"

missing_ton_different_intent_integration="$tmp_dir/missing-ton-different-intent-integration"
write_valid_fixture "$missing_ton_different_intent_integration"
perl -0pi -e 's/testTonDifferentIntentRecoveryNeverReturnsThePriorHashAsNewSuccess/testTonDifferentIntentReturnsSuccess/' "$missing_ton_different_intent_integration/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON different-intent integration" "$missing_ton_different_intent_integration" "TON different-intent prior-confirmed integration regression"

missing_ton_prior_confirmed_presenter_ux="$tmp_dir/missing-ton-prior-confirmed-presenter-ux"
write_valid_fixture "$missing_ton_prior_confirmed_presenter_ux"
perl -0pi -e 's/presentTonPriorTransferConfirmed/presentGenericTransferFailure/g' "$missing_ton_prior_confirmed_presenter_ux/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "missing TON prior-confirmed presenter UX" "$missing_ton_prior_confirmed_presenter_ux" "TON prior-confirmed acknowledgement UX"

bypassed_ton_confirmed_identity_ack="$tmp_dir/bypassed-ton-confirmed-identity-ack"
write_valid_fixture "$bypassed_ton_confirmed_identity_ack"
perl -0pi -e 's/pending\.identity == identity/true/' "$bypassed_ton_confirmed_identity_ack/fearless/Common/Model/TonSendService.swift"
expect_failure "bypassed TON confirmed identity acknowledgement" "$bypassed_ton_confirmed_identity_ack" "TON exact identity/hash confirmed acknowledgement"

missing_ton_friendly_ack_regression="$tmp_dir/missing-ton-friendly-ack-regression"
write_valid_fixture "$missing_ton_friendly_ack_regression"
perl -0pi -e 's/\.toFriendly\(\)/.toRaw()/' "$missing_ton_friendly_ack_regression/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON friendly acknowledgement regression" "$missing_ton_friendly_ack_regression" "TON friendly-address acknowledgement regression"

missing_ton_receipt_completion_protocol="$tmp_dir/missing-ton-receipt-completion-protocol"
write_valid_fixture "$missing_ton_receipt_completion_protocol"
perl -0pi -e 's/protocol WalletSendConfirmCompletionPresenting/protocol WalletSendConfirmCompletionScheduling/' "$missing_ton_receipt_completion_protocol/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmProtocols.swift"
expect_failure "missing TON receipt completion protocol" "$missing_ton_receipt_completion_protocol" "TON visible-receipt completion capability"

dropped_ton_wireframe_presentation_callback="$tmp_dir/dropped-ton-wireframe-presentation-callback"
write_valid_fixture "$dropped_ton_wireframe_presentation_callback"
perl -0pi -e 's/presentationCompletion: completion/presentationCompletion: nil/' "$dropped_ton_wireframe_presentation_callback/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmWireframe.swift"
expect_failure "dropped TON wireframe presentation callback" "$dropped_ton_wireframe_presentation_callback" "TON production presentation callback propagation"

missing_ton_receipt_callback_ack="$tmp_dir/missing-ton-receipt-callback-ack"
write_valid_fixture "$missing_ton_receipt_callback_ack"
perl -0pi -e 's/self\?\.interactor\.acknowledgeSubmittedTransfer/self?.interactor.logSubmittedTransfer/' "$missing_ton_receipt_callback_ack/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "missing TON receipt callback acknowledgement" "$missing_ton_receipt_callback_ack" "TON success receipt callback-before-acknowledgement ordering"

premature_ton_ack_without_receipt_callback="$tmp_dir/premature-ton-ack-without-receipt-callback"
write_valid_fixture "$premature_ton_ack_without_receipt_callback"
perl -0pi -e 's/    wireframe\.complete\(on: view, title: hash, chainAsset: chainAsset\)/    interactor.acknowledgeSubmittedTransfer(hash: hash)\n    wireframe.complete(on: view, title: hash, chainAsset: chainAsset)/' "$premature_ton_ack_without_receipt_callback/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "premature TON acknowledgement without receipt callback" "$premature_ton_ack_without_receipt_callback" "TON no-callback success path premature acknowledgement"

rounded_ton_fee_presentation="$tmp_dir/rounded-ton-fee-presentation"
write_valid_fixture "$rounded_ton_fee_presentation"
perl -0pi -e 's/\.exactCrypto\(fractionDigits: Int\(utilityAsset\.asset\.precision\)\)/.detailsCrypto/' "$rounded_ton_fee_presentation/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmPresenter.swift"
expect_failure "rounded TON fee presentation" "$rounded_ton_fee_presentation" "TON exact precision fee rendering"

missing_ton_ninth_decimal_test="$tmp_dir/missing-ton-ninth-decimal-test"
write_valid_fixture "$missing_ton_ninth_decimal_test"
perl -0pi -e 's/testTonExactFeeFormatterPreservesTheNinthDecimalAcrossLocales/testTonFeeFormatterRoundsAcrossLocales/' "$missing_ton_ninth_decimal_test/fearlessTests/Modules/WalletSendConfirm/WalletSendConfirmTests.swift"
expect_failure "missing TON ninth-decimal test" "$missing_ton_ninth_decimal_test" "TON ninth-decimal locale rendering regression"

reversible_ton_journal_phase="$tmp_dir/reversible-ton-journal-phase"
write_valid_fixture "$reversible_ton_journal_phase"
perl -0pi -e 's/pending\.journalPhaseRank >= existing\.journalPhaseRank/pending.journalPhaseRank <= existing.journalPhaseRank/' "$reversible_ton_journal_phase/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "reversible TON journal phase" "$reversible_ton_journal_phase" "TON journal phase-monotonic save guards"

bypassed_ton_journal_bearer_guard="$tmp_dir/bypassed-ton-journal-bearer-guard"
write_valid_fixture "$bypassed_ton_journal_bearer_guard"
perl -0pi -e 's/pending\.hasSameBearer\(as: existing\)/true/' "$bypassed_ton_journal_bearer_guard/fearless/Common/Model/TonPendingIntentJournal.swift"
expect_failure "bypassed TON journal bearer guard" "$bypassed_ton_journal_bearer_guard" "TON journal same-bearer overwrite guards"

reordered_ton_retain_durable_save="$tmp_dir/reordered-ton-retain-durable-save"
write_valid_fixture "$reordered_ton_retain_durable_save"
perl -0pi -e 's/    try journal\.save\(retained\)\n    statesBySender\[pending\.identity\.sender\] = \.pending\(retained\)/    statesBySender[pending.identity.sender] = .pending(retained)\n    try journal.save(retained)/' "$reordered_ton_retain_durable_save/fearless/Common/Model/TonSendService.swift"
expect_failure "reordered TON retain durable save" "$reordered_ton_retain_durable_save" "TON retained pending durable-save-before-state ordering"

dropped_ton_stale_confirmed_preservation="$tmp_dir/dropped-ton-stale-confirmed-preservation"
write_valid_fixture "$dropped_ton_stale_confirmed_preservation"
perl -0pi -e 's/storedPending\.confirmed \|\|/false ||/' "$dropped_ton_stale_confirmed_preservation/fearless/Common/Model/TonSendService.swift"
expect_failure "dropped TON stale confirmed preservation" "$dropped_ton_stale_confirmed_preservation" "TON stale recovery preserves confirmed phase"

missing_ton_deterministic_downgrade_regression="$tmp_dir/missing-ton-deterministic-downgrade-regression"
write_valid_fixture "$missing_ton_deterministic_downgrade_regression"
perl -0pi -e 's/stalePending\.confirmed = false/stalePending.confirmed = true/' "$missing_ton_deterministic_downgrade_regression/fearlessTests/TonTransferTransactionBuilderTests.swift"
expect_failure "missing TON deterministic downgrade regression" "$missing_ton_deterministic_downgrade_regression" "TON deterministic confirmed-phase downgrade regression"

missing_ton_prior_confirmed_locale_key="$tmp_dir/missing-ton-prior-confirmed-locale-key"
write_valid_fixture "$missing_ton_prior_confirmed_locale_key"
perl -0pi -e 's/ton\.transfer\.prior_confirmed\.acknowledge/ton.transfer.prior_confirmed.dismiss/' "$missing_ton_prior_confirmed_locale_key/fearless/en.lproj/Localizable.strings"
expect_failure "missing TON prior-confirmed locale key" "$missing_ton_prior_confirmed_locale_key" "TON prior-confirmed en acknowledgement action"

bypassed_ton_selected_fee_asset_pin="$tmp_dir/bypassed-ton-selected-fee-asset-pin"
write_valid_fixture "$bypassed_ton_selected_fee_asset_pin"
perl -0pi -e 's/if chainAsset\.chain\.isTonCompatibilityChain/if chainAsset.chain.isEthereum/' "$bypassed_ton_selected_fee_asset_pin/fearless/Modules/NewWallet/WalletSendConfirm/WalletSendConfirmInteractor.swift"
expect_failure "bypassed TON selected fee-asset pin" "$bypassed_ton_selected_fee_asset_pin" "TON selected native fee asset pinned before unordered registry fallback"

missing_ton_unordered_utility_asset_test="$tmp_dir/missing-ton-unordered-utility-asset-test"
write_valid_fixture "$missing_ton_unordered_utility_asset_test"
perl -0pi -e 's/testTonFeePaymentAssetIgnoresAdditionalUnorderedUtilityAssets/testTonFeePaymentAssetUsesFirstUtilityAsset/' "$missing_ton_unordered_utility_asset_test/fearlessTests/ApplicationLayer/Services/FeatureToggle/TonChainSelectionTests.swift"
expect_failure "missing TON unordered utility-asset test" "$missing_ton_unordered_utility_asset_test" "TON unordered utility-asset registry-confusion regression"

if ((executed_destructive_fixtures != EXPECTED_DESTRUCTIVE_FIXTURES)); then
  fail "expected exactly $EXPECTED_DESTRUCTIVE_FIXTURES destructive fixtures, executed $executed_destructive_fixtures"
fi

echo "[ios-transaction-builder-audit-test] all $executed_destructive_fixtures destructive fixtures passed"
