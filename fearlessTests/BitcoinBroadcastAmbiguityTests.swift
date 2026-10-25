import XCTest
import BigInt
import CommonCrypto
import SSFModels
@testable import fearless

/// IOSUX-3 B1: after a broadcast whose outcome the wallet does not know, it must never build a
/// second payment from other coins while the first may still be in flight. The audit's case
/// (the reply is lost, the transaction landed, the user confirms again and pays twice) is
/// `testReplyLostAfterTheNodeAcceptedIt_thenASecondConfirmNeverSpendsOtherCoins`.
final class BitcoinBroadcastAmbiguityTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: BitcoinPendingBroadcastStore!
    private var ledger: BitcoinTestLedger!
    private var wallet: MetaAccountModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "BitcoinBroadcastAmbiguityTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = BitcoinPendingBroadcastStore(userDefaults: defaults, logger: nil)
        ledger = BitcoinTestLedger()
        wallet = try BitcoinTestWallet.wallet()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - The outcome is found out, not guessed

    func testBroadcastTransportError_whenTxStatusFound_thenReturnsSameTxidWithoutReplanning() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.acceptButFail(URLError(.timedOut))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)

        _ = try await service.estimateFee(for: transfer)
        let utxoReadsBeforeSubmit = ledger.utxoRequests.count
        let txid = try await service.submit(transfer: transfer)

        let sent = try ParsedBitcoinTransaction(hex: XCTUnwrap(ledger.broadcasts.first))
        XCTAssertEqual(txid, sent.txid)
        XCTAssertEqual(ledger.broadcasts.count, 1)
        // One plan for the submit; the lost reply was resolved by a status lookup, not a new plan.
        XCTAssertEqual(ledger.utxoRequests.count, utxoReadsBeforeSubmit + 1)
        XCTAssertEqual(ledger.statusRequests, [sent.txid])
        XCTAssertNil(store.pending(for: scope))
    }

    func testAlreadyInMempoolError_thenSuccess() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [
            .acceptButFail(
                UniversalWalletHTTPTransportError.httpStatusCode(
                    400,
                    Data(#"sendrawtransaction RPC error: {"code":-27,"message":"Transaction already in block chain"}"#.utf8)
                )
            )
        ]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)

        _ = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        XCTAssertEqual(txid, try ParsedBitcoinTransaction(hex: XCTUnwrap(ledger.broadcasts.first)).txid)
        XCTAssertNil(store.pending(for: scope))
    }

    func testBroadcastTransportError_whenStatusMissing_thenOutcomeUnknownWithStoredHex() async throws {
        let coin = ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)

        let fee = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }

        let record = try XCTUnwrap(store.pending(for: scope))
        XCTAssertEqual(record.txid, txid)
        XCTAssertEqual(record.txHex, ledger.broadcasts.first)
        XCTAssertEqual(record.amountSats, 50000)
        XCTAssertEqual(record.feeSats, Int64(fee))
        XCTAssertEqual(record.recipientAddress, BitcoinTestWallet.recipient)
        XCTAssertEqual(record.inputs.map(\.outpoint), [coin])
        XCTAssertNil(record.replacementAllowedAt)
        XCTAssertFalse(record.txHex.contains(BitcoinTestWallet.mnemonic))
    }

    /// The record is on disk before the transaction leaves the device, so a crash or a kill
    /// in the middle of the request cannot lose track of it.
    func testSubmit_recordsTheSignedTransactionBeforeItIsBroadcast() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        var recordedBeforeBroadcast: BitcoinPendingBroadcast?
        ledger.onBroadcast = { [store, scope] _ in
            recordedBeforeBroadcast = store?.pending(for: scope)
        }

        _ = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        XCTAssertEqual(recordedBeforeBroadcast?.txid, txid)
        XCTAssertEqual(recordedBeforeBroadcast?.txHex, ledger.broadcasts.first)
        XCTAssertNil(store.pending(for: scope), "A transfer the node accepted is no longer pending")
    }

    func testInterruptedBroadcast_whenAppRestarts_thenTheNextConfirmIsRefusedWithoutPlanning() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(CancellationError())]
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        let firstLaunch = makeService()
        _ = try await firstLaunch.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await firstLaunch.submit(transfer: transfer) }

        // A new process: nothing in memory, the same preferences on disk.
        let secondLaunch = makeService(
            store: BitcoinPendingBroadcastStore(userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)), logger: nil)
        )
        ledger.fund(BitcoinTestWallet.address, sats: 900_000)
        _ = try await secondLaunch.estimateFee(for: transfer)
        let utxoReads = ledger.utxoRequests.count

        await assertTransferError(.bitcoinPriorTransferUnresolved(txid: txid)) {
            _ = try await secondLaunch.submit(transfer: transfer)
        }

        XCTAssertEqual(ledger.broadcasts.count, 1)
        XCTAssertEqual(ledger.utxoRequests.count, utxoReads, "Nothing may be planned while a transfer is unresolved")
    }

    // MARK: - No second payment from other coins

    func testSubmit_whenPriorIntentUnresolved_thenThrowsWithoutPlanning() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.networkConnectionLost))]
        let mnemonicProvider = BitcoinTestMnemonicProvider()
        let service = makeService(mnemonicProvider: mnemonicProvider)
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }

        // A larger coin arrives. A fresh plan would now pick it alone, and both transactions
        // could confirm: exactly the double payment this guard exists to prevent.
        ledger.fund(BitcoinTestWallet.address, sats: 900_000)
        _ = try await service.estimateFee(for: transfer)
        let utxoReads = ledger.utxoRequests.count
        let mnemonicReads = mnemonicProvider.callCount

        await assertTransferError(.bitcoinPriorTransferUnresolved(txid: txid)) {
            _ = try await service.submit(transfer: transfer)
        }

        XCTAssertEqual(ledger.broadcasts.count, 1)
        XCTAssertEqual(ledger.utxoRequests.count, utxoReads)
        XCTAssertEqual(mnemonicProvider.callCount, mnemonicReads, "The key is not touched while a transfer is unresolved")
        XCTAssertEqual(store.pending(for: scope)?.txid, txid)
    }

    func testReplyLostAfterTheNodeAcceptedIt_thenASecondConfirmNeverSpendsOtherCoins() async throws {
        let firstCoin = ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        let otherCoin = ledger.fund(BitcoinTestWallet.address, sats: 80000)
        // The node takes the transaction, the reply is lost, and the indexer cannot be asked.
        ledger.broadcastScript = [.acceptButFail(URLError(.timedOut))]
        ledger.lookupError = URLError(.timedOut)
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        XCTAssertEqual(ledger.unspent(BitcoinTestWallet.address).map(\.outpoint).contains(firstCoin), false)

        // The user sees no transfer in history yet and confirms the same payment again. The
        // indexer now lists only the other coin; a new plan would spend it and pay twice.
        _ = try await service.estimateFee(for: transfer)
        await assertTransferError(.bitcoinPriorTransferUnresolved(txid: txid)) {
            _ = try await service.submit(transfer: transfer)
        }

        // Once the indexer answers, the wallet learns the first payment went out and says so
        // instead of sending another.
        ledger.lookupError = nil
        _ = try await service.estimateFee(for: transfer)
        await assertTransferError(.bitcoinPriorTransferConfirmed(txid: txid)) {
            _ = try await service.submit(transfer: transfer)
        }

        XCTAssertEqual(ledger.broadcasts.count, 1)
        let spent = try ledger.broadcasts.flatMap { try ParsedBitcoinTransaction(hex: $0).inputs }
        XCTAssertEqual(spent, [firstCoin])
        XCTAssertTrue(ledger.unspent(BitcoinTestWallet.address).map(\.outpoint).contains(otherCoin))
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 50000)
        XCTAssertNil(store.pending(for: scope))
    }

    func testPriorIntentClearedWhenTxSeen() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.fund(BitcoinTestWallet.address, sats: 80000)
        ledger.broadcastScript = [.acceptButFail(URLError(.timedOut))]
        ledger.lookupError = URLError(.timedOut)
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        ledger.lookupError = nil

        _ = try await service.estimateFee(for: transfer)
        await assertTransferError(.bitcoinPriorTransferConfirmed(txid: txid)) {
            _ = try await service.submit(transfer: transfer)
        }
        XCTAssertNil(store.pending(for: scope))

        // The user has been told. A deliberate second payment is now an ordinary transfer.
        _ = try await service.estimateFee(for: transfer)
        let secondTxid = try await service.submit(transfer: transfer)

        XCTAssertNotEqual(secondTxid, txid)
        XCTAssertEqual(ledger.broadcasts.count, 2)
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 100_000)
    }

    func testDeadPendingTransfer_whenAnotherConfirmedTransactionSpentItsCoin_thenSendingWorksAgain() async throws {
        let coin = ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.fund(BitcoinTestWallet.address, sats: 80000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        _ = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }

        // The same seed, used in another wallet app, spends the coin and that confirms.
        ledger.spendElsewhere(coin, confirmed: true)

        _ = try await service.estimateFee(for: transfer)
        let txid = try await service.submit(transfer: transfer)

        XCTAssertEqual(ledger.broadcasts.count, 2)
        XCTAssertEqual(try ParsedBitcoinTransaction(hex: ledger.broadcasts[1]).txid, txid)
        XCTAssertNil(store.pending(for: scope))
    }

    // MARK: - Retry and replace

    func testRetryBroadcast_resendsIdenticalHex() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        ledger.fund(BitcoinTestWallet.address, sats: 900_000)

        let retriedTxid = try await service.retryUnresolvedTransfer(hash: txid)

        XCTAssertEqual(retriedTxid, txid)
        XCTAssertEqual(ledger.broadcasts.count, 2)
        XCTAssertEqual(ledger.broadcasts[0], ledger.broadcasts[1])
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 50000)
        XCTAssertNil(store.pending(for: scope))
    }

    func testRetryBroadcast_whenItHadAlreadyLanded_thenReportsTheSameTransferOnce() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.acceptButFail(URLError(.timedOut))]
        ledger.lookupError = URLError(.timedOut)
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        ledger.lookupError = nil

        // The node refuses the bytes it already has; the lookup shows the payment is there.
        let retriedTxid = try await service.retryUnresolvedTransfer(hash: txid)

        XCTAssertEqual(retriedTxid, txid)
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 50000)
        XCTAssertNil(store.pending(for: scope))
    }

    func testRetryBroadcast_whenStillUnreachable_thenStaysUnresolved() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut)), .fail(URLError(.notConnectedToInternet))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }

        await assertTransferError(.bitcoinBroadcastOutcomeUnknown(txid: txid)) {
            _ = try await service.retryUnresolvedTransfer(hash: txid)
        }

        XCTAssertEqual(store.pending(for: scope)?.txid, txid, "Being offline now proves nothing about the first attempt")
    }

    func testRetryBroadcast_whenVetoed_thenNothingIsBroadcast() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        var config = FeatureToggleConfig.defaultConfig
        let service = makeService(sendGate: UniversalSendGate(policy: .production, remoteConfig: { config }))
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        config = FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true, bitcoinSendEnabled: false)

        await assertTransferError(.bitcoinSendPaused) {
            _ = try await service.retryUnresolvedTransfer(hash: txid)
        }

        XCTAssertEqual(ledger.broadcasts.count, 1)
        XCTAssertEqual(store.pending(for: scope)?.txid, txid)
    }

    func testReplacement_spendsEveryCoinOfTheUnresolvedTransfer() async throws {
        let stuckCoin = ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        let service = makeService()
        let stuck = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: stuck)
        let stuckTxid = try await assertOutcomeUnknown { try await service.submit(transfer: stuck) }
        let bigCoin = ledger.fund(BitcoinTestWallet.address, sats: 900_000)
        // More than the stuck coin holds, so both coins are needed.
        let replacement = BitcoinTestWallet.transfer(sats: 150_000)

        let allowed = await service.allowReplacingUnresolvedTransfer(hash: stuckTxid)
        let fee = try await service.estimateFee(for: replacement)
        let txid = try await service.submit(transfer: replacement)

        XCTAssertTrue(allowed)
        let sent = try ParsedBitcoinTransaction(hex: ledger.broadcasts[1])
        XCTAssertEqual(sent.txid, txid)
        // Largest-first selection alone would have taken only the 900,000 sat coin. Spending
        // the stuck transfer's coin as well makes the two transactions mutually exclusive.
        XCTAssertEqual(Set(sent.inputs), [stuckCoin, bigCoin])
        XCTAssertEqual(sent.inputs.first, stuckCoin, "The required coin is selected first")
        XCTAssertEqual(ledger.fee(of: sent), Int64(fee))
        XCTAssertNil(store.pending(for: scope))

        // The stuck transaction can no longer be accepted by any node that has the new one.
        XCTAssertThrowsError(try ledger.accept(txHex: ledger.broadcasts[0]))
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 150_000)
    }

    /// When the stuck coin alone covers the replacement, it is still the coin spent, so the
    /// two transfers conflict however little the replacement sends.
    func testReplacement_whenTheStuckCoinSuffices_thenItIsTheCoinSpent() async throws {
        let stuckCoin = ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        let service = makeService()
        _ = try await service.estimateFee(for: BitcoinTestWallet.transfer(sats: 50000))
        let stuckTxid = try await assertOutcomeUnknown {
            try await service.submit(transfer: BitcoinTestWallet.transfer(sats: 50000))
        }
        ledger.fund(BitcoinTestWallet.address, sats: 900_000)
        let replacement = BitcoinTestWallet.transfer(sats: 70000)

        _ = await service.allowReplacingUnresolvedTransfer(hash: stuckTxid)
        _ = try await service.estimateFee(for: replacement)
        _ = try await service.submit(transfer: replacement)

        XCTAssertEqual(try ParsedBitcoinTransaction(hex: ledger.broadcasts[1]).inputs, [stuckCoin])
        XCTAssertThrowsError(try ledger.accept(txHex: ledger.broadcasts[0]))
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 70000)
    }

    func testReplacement_whenTheFeeWasQuotedBeforeItWasAllowed_thenAsksForANewQuote() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        ledger.fund(BitcoinTestWallet.address, sats: 900_000)

        // Quoted for the big coin alone, then allowed to replace: the quote is for the wrong coins.
        _ = try await service.estimateFee(for: transfer)
        _ = await service.allowReplacingUnresolvedTransfer(hash: txid)

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected the stale quote to be refused")
        } catch let TransferServiceError.transferFailed(reason) {
            XCTAssertTrue(reason.contains("review the fee again"), reason)
        }
        XCTAssertEqual(ledger.broadcasts.count, 1)
    }

    func testReplacement_whenItsOwnBroadcastIsUnknown_thenRemembersBothTransfers() async throws {
        let stuckCoin = ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut)), .fail(URLError(.timedOut))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)
        let stuckTxid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }
        _ = await service.allowReplacingUnresolvedTransfer(hash: stuckTxid)
        _ = try await service.estimateFee(for: transfer)

        // Same amount and recipient, the same single coin: RFC 6979 signs the same bytes again.
        let replacementTxid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }

        let record = try XCTUnwrap(store.pending(for: scope))
        XCTAssertEqual(record.txid, replacementTxid)
        XCTAssertEqual(record.inputs.map(\.outpoint), [stuckCoin])
        XCTAssertEqual(record.replaced.map(\.txid), [stuckTxid])
        XCTAssertNil(record.replacementAllowedAt, "Replacing the replacement needs the user's say-so again")
    }

    func testAllowReplacing_whenNothingIsUnresolved_thenRefuses() async {
        let service = makeService()

        let allowed = await service.allowReplacingUnresolvedTransfer(hash: String(repeating: "ab", count: 32))

        XCTAssertFalse(allowed)
    }

    // MARK: - A definite failure is not left pending

    func testBroadcastNeverLeftTheDevice_thenNotSentAndNothingPending() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.notConnectedToInternet))]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)

        await assertTransferError(.bitcoinTransferNotSent(.noConnection)) {
            _ = try await service.submit(transfer: transfer)
        }

        XCTAssertNil(store.pending(for: scope))
        XCTAssertTrue(ledger.statusRequests.isEmpty, "Nothing was sent, so there is nothing to look up")
        _ = try await service.estimateFee(for: transfer)
        _ = try await service.submit(transfer: transfer)
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 50000)
    }

    func testNodeRejectsTheTransaction_thenNotSentAndNothingPending() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [
            .fail(
                UniversalWalletHTTPTransportError.httpStatusCode(
                    400,
                    Data(#"sendrawtransaction RPC error: {"code":-26,"message":"min relay fee not met"}"#.utf8)
                )
            )
        ]
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)

        await assertTransferError(.bitcoinTransferNotSent(.rejectedByNetwork)) {
            _ = try await service.submit(transfer: transfer)
        }

        XCTAssertNil(store.pending(for: scope))
        XCTAssertEqual(ledger.statusRequests.count, 1, "A refusal is still checked against the indexer once")
    }

    func testAlreadyKnownRefusal_whenLookupFails_thenStaysUnresolvedInsteadOfNotSent() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.fund(BitcoinTestWallet.address, sats: 80000)
        ledger.broadcastScript = [
            .acceptButFail(
                UniversalWalletHTTPTransportError.httpStatusCode(
                    400,
                    Data(#"sendrawtransaction RPC error: {"code":-26,"message":"txn-already-in-mempool"}"#.utf8)
                )
            )
        ]
        ledger.lookupError = URLError(.timedOut)
        let service = makeService()
        let transfer = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: transfer)

        let txid = try await assertOutcomeUnknown { try await service.submit(transfer: transfer) }

        XCTAssertEqual(store.pending(for: scope)?.txid, txid, "The node holds it; forgetting it would allow a second payment")
        _ = try await service.estimateFee(for: transfer)
        await assertTransferError(.bitcoinPriorTransferUnresolved(txid: txid)) {
            _ = try await service.submit(transfer: transfer)
        }
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 50000)
    }

    func testReplacement_whenTheEarlierTransferWasTheOneSent_thenReportsItAndSendsNothingMore() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 100_000)
        ledger.broadcastScript = [.fail(URLError(.timedOut)), .fail(URLError(.timedOut))]
        let service = makeService()
        let first = BitcoinTestWallet.transfer(sats: 50000)
        _ = try await service.estimateFee(for: first)
        let firstTxid = try await assertOutcomeUnknown { try await service.submit(transfer: first) }
        let firstHex = try XCTUnwrap(ledger.broadcasts.first)
        _ = await service.allowReplacingUnresolvedTransfer(hash: firstTxid)
        let replacement = BitcoinTestWallet.transfer(sats: 60000)
        _ = try await service.estimateFee(for: replacement)
        let replacementTxid = try await assertOutcomeUnknown { try await service.submit(transfer: replacement) }
        XCTAssertNotEqual(replacementTxid, firstTxid)

        // Some node did take the first transaction after all, and it reaches the indexer.
        try ledger.accept(txHex: firstHex)

        // Its coin is gone, so nothing could even be quoted; the check runs before any quote.
        await assertTransferError(.bitcoinPriorTransferConfirmed(txid: firstTxid)) {
            _ = try await service.submit(transfer: replacement)
        }
        XCTAssertNil(store.pending(for: scope))
        XCTAssertEqual(ledger.received(by: BitcoinTestWallet.recipient), 50000, "Exactly one of the two payments")
    }

    // MARK: - Classification, store, failover

    func testBroadcastFailuresAreAmbiguousUnlessProvablyUndelivered() {
        let neverLeft: [Error] = [
            URLError(.notConnectedToInternet),
            URLError(.cannotFindHost),
            URLError(.cannotConnectToHost),
            URLError(.dnsLookupFailed),
            URLError(.secureConnectionFailed),
            UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: 30),
            BitcoinBroadcastError.invalidTxHex
        ]
        let ambiguous: [Error] = [
            URLError(.timedOut),
            URLError(.networkConnectionLost),
            URLError(.cancelled),
            URLError(.badServerResponse),
            CancellationError(),
            UniversalWalletHTTPTransportError.invalidResponse,
            UniversalWalletHTTPTransportError.httpStatusCode(500, Data()),
            UniversalWalletHTTPTransportError.httpStatusCode(502, Data()),
            UniversalWalletHTTPTransportError.httpStatusCode(408, Data()),
            UniversalWalletHTTPTransportError.rateLimited(statusCode: 503, retryAfter: nil),
            BitcoinBroadcastError.invalidTxidResponse
        ]

        neverLeft.forEach { XCTAssertEqual(BitcoinBroadcastAttemptOutcome(error: $0), .notSent, "\($0)") }
        ambiguous.forEach { XCTAssertEqual(BitcoinBroadcastAttemptOutcome(error: $0), .ambiguous, "\($0)") }
        XCTAssertEqual(
            BitcoinBroadcastAttemptOutcome(
                error: UniversalWalletHTTPTransportError.httpStatusCode(400, Data("bad-txns-inputs-missingorspent".utf8))
            ),
            .rejected("bad-txns-inputs-missingorspent")
        )
        // A node that already holds the transaction refuses it again: the payment is out, so
        // these refusals must never read as "nothing was sent".
        let alreadyKnown = [
            #"sendrawtransaction RPC error: {"code":-27,"message":"Transaction already in block chain"}"#,
            #"sendrawtransaction RPC error: {"code":-27,"message":"Transaction outputs already in utxo set"}"#,
            #"sendrawtransaction RPC error: {"code":-26,"message":"txn-already-in-mempool"}"#,
            #"sendrawtransaction RPC error: {"code":-26,"message":"txn-already-known"}"#,
            #"sendrawtransaction RPC error: {"code":-26,"message":"txn-same-nonwitness-data-in-mempool"}"#
        ]
        alreadyKnown.forEach { body in
            XCTAssertEqual(
                BitcoinBroadcastAttemptOutcome(error: UniversalWalletHTTPTransportError.httpStatusCode(400, Data(body.utf8))),
                .ambiguous,
                body
            )
        }

        XCTAssertTrue(BitcoinBroadcastFailure(attempts: [.notSent, .notSent]).isDefinitelyNotSent)
        XCTAssertFalse(BitcoinBroadcastFailure(attempts: [.notSent, .rejected("x")]).isDefinitelyNotSent)
        XCTAssertFalse(BitcoinBroadcastFailure(attempts: [.notSent, .rejected("x")]).mayHaveReachedNetwork)
        XCTAssertTrue(BitcoinBroadcastFailure(attempts: [.rejected("x"), .ambiguous]).mayHaveReachedNetwork)
    }

    func testPendingStore_roundTripsAcrossInstancesAndChainAliases() throws {
        let record = BitcoinPendingBroadcast(
            walletId: "wallet",
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            txid: String(repeating: "ab", count: 32),
            txHex: "0200",
            amountSats: 1000,
            feeSats: 200,
            recipientAddress: BitcoinTestWallet.recipient,
            inputs: [.init(txid: String(repeating: "11", count: 32), vout: 1, valueSats: 5000)],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            replacementAllowedAt: Date(timeIntervalSince1970: 1_800_000_060),
            replaced: [.init(txid: String(repeating: "cd", count: 32), amountSats: 900, recipientAddress: "bc1q")]
        )
        let byChainId = BitcoinPendingBroadcastScope(walletId: "wallet", chainId: "bitcoin:mainnet")
        let byAlias = BitcoinPendingBroadcastScope(walletId: "wallet", chainId: "bitcoin-mainnet")

        try store.save(record, for: byChainId)
        let reopened = BitcoinPendingBroadcastStore(userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)), logger: nil)

        XCTAssertEqual(byChainId, byAlias)
        XCTAssertEqual(reopened.pending(for: byAlias), record)
        XCTAssertNil(reopened.pending(for: BitcoinPendingBroadcastScope(walletId: "other", chainId: "bitcoin:mainnet")))
        XCTAssertNil(reopened.pending(for: BitcoinPendingBroadcastScope(walletId: "wallet", chainId: "bitcoin:testnet")))

        reopened.clear(txid: String(repeating: "ff", count: 32), for: byAlias)
        XCTAssertEqual(store.pending(for: byChainId), record, "Only the transaction it was asked about is cleared")
        reopened.clear(txid: record.txid, for: byAlias)
        XCTAssertNil(store.pending(for: byChainId))
    }

    func testPendingStore_whenRecordIsUnreadable_thenKeepsTheBytesAndDoesNotBlockTheWallet() throws {
        let scope = BitcoinPendingBroadcastScope(walletId: "wallet", chainId: "bitcoin:mainnet")
        let damaged = Data("not json".utf8)
        defaults.set(damaged, forKey: BitcoinPendingBroadcastStore.key(for: scope))

        XCTAssertNil(store.pending(for: scope))

        XCTAssertNil(defaults.data(forKey: BitcoinPendingBroadcastStore.key(for: scope)))
        XCTAssertEqual(defaults.data(forKey: "bitcoin.pending_broadcast.unreadable:wallet:bitcoin:mainnet"), damaged)
    }

    func testFailoverClient_readsFromTheNextServiceWhenTheFirstRateLimits() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let health = BitcoinIndexerEndpointHealth(now: { clock })
        let endpoints = RecordingEndpointClient()
        endpoints.readErrors[Self.primary] = UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: 90)
        let client = BitcoinFailoverIndexerClient(client: endpoints, health: health)

        let first = try await client.feeEstimates(network: .mainnet, baseURL: nil)
        let second = try await client.feeEstimates(network: .mainnet, baseURL: Self.primary)

        XCTAssertEqual(first, ["2": 2])
        XCTAssertEqual(second, ["2": 2])
        // The rate-limited service is asked once and then left alone for its Retry-After.
        XCTAssertEqual(endpoints.readRequests, [Self.primary, Self.fallback, Self.fallback])

        clock = clock.addingTimeInterval(91)
        endpoints.readErrors[Self.primary] = nil
        _ = try await client.feeEstimates(network: .mainnet, baseURL: nil)
        XCTAssertEqual(endpoints.readRequests.last, Self.primary)
    }

    func testFailoverClient_whenEveryServiceRateLimits_thenStopsAskingUntilTheBackoffEnds() async throws {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let health = BitcoinIndexerEndpointHealth(now: { clock })
        let endpoints = RecordingEndpointClient()
        let limited = UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: nil)
        endpoints.readErrors = [Self.primary: limited, Self.fallback: limited]
        let client = BitcoinFailoverIndexerClient(client: endpoints, health: health)

        await assertThrows(limited) { _ = try await client.feeEstimates(network: .mainnet, baseURL: nil) }
        await assertThrows(BitcoinIndexerClientError.rateLimited(retryAfter: 30)) {
            _ = try await client.feeEstimates(network: .mainnet, baseURL: nil)
        }
        XCTAssertEqual(endpoints.readRequests.count, 2, "The second call must not reach the network")

        // 30 s, then 60 s, 120 s ... capped at 15 minutes.
        clock = clock.addingTimeInterval(31)
        await assertThrows(limited) { _ = try await client.feeEstimates(network: .mainnet, baseURL: nil) }
        XCTAssertEqual(health.retryDelay(for: [Self.primary]), 60)
        for _ in 0 ..< 12 {
            health.markFailure(Self.primary)
        }
        XCTAssertEqual(health.retryDelay(for: [Self.primary]), BitcoinIndexerEndpointHealth.maxBackoff)
    }

    func testFailoverClient_whenOffline_thenTriesTheNextServiceButHoldsNeitherBack() async throws {
        let health = BitcoinIndexerEndpointHealth()
        let endpoints = RecordingEndpointClient()
        endpoints.readErrors = [
            Self.primary: URLError(.notConnectedToInternet),
            Self.fallback: URLError(.notConnectedToInternet)
        ]
        let client = BitcoinFailoverIndexerClient(client: endpoints, health: health)

        await assertThrows(URLError(.notConnectedToInternet)) {
            _ = try await client.feeEstimates(network: .mainnet, baseURL: nil)
        }
        endpoints.readErrors = [:]
        _ = try await client.feeEstimates(network: .mainnet, baseURL: nil)

        XCTAssertEqual(endpoints.readRequests, [Self.primary, Self.fallback, Self.primary])
    }

    func testFailoverClient_doesNotFailOverARefusedRequestOrACustomService() async throws {
        let endpoints = RecordingEndpointClient()
        let refused = UniversalWalletHTTPTransportError.httpStatusCode(400, Data("Invalid Bitcoin address".utf8))
        endpoints.readErrors[Self.primary] = refused
        let client = BitcoinFailoverIndexerClient(client: endpoints, health: BitcoinIndexerEndpointHealth())

        await assertThrows(refused) { _ = try await client.feeEstimates(network: .mainnet, baseURL: nil) }
        XCTAssertEqual(endpoints.readRequests, [Self.primary])

        endpoints.readErrors["https://bitcoin.example/api"] = URLError(.timedOut)
        await assertThrows(URLError(.timedOut)) {
            _ = try await client.feeEstimates(network: .mainnet, baseURL: "https://bitcoin.example/api")
        }
        XCTAssertEqual(endpoints.readRequests, [Self.primary, "https://bitcoin.example/api"])
    }

    func testFailoverClient_offersTheSameTransactionToEveryServiceAndReportsEveryOutcome() async throws {
        let endpoints = RecordingEndpointClient()
        endpoints.broadcastErrors = [
            Self.primary: URLError(.timedOut),
            Self.fallback: UniversalWalletHTTPTransportError.httpStatusCode(400, Data("txn-already-in-mempool".utf8))
        ]
        let client = BitcoinFailoverIndexerClient(client: endpoints, health: BitcoinIndexerEndpointHealth())

        do {
            _ = try await client.broadcastTransaction(txHex: "0200", network: .mainnet, baseURL: nil)
            XCTFail("Expected the aggregated broadcast failure")
        } catch let failure as BitcoinBroadcastFailure {
            XCTAssertEqual(failure.attempts, [.ambiguous, .ambiguous])
            XCTAssertTrue(failure.mayHaveReachedNetwork)
        }
        XCTAssertEqual(endpoints.broadcastRequests.map(\.endpoint), [Self.primary, Self.fallback])
        XCTAssertEqual(Set(endpoints.broadcastRequests.map(\.txHex)), ["0200"])

        endpoints.broadcastErrors[Self.fallback] = nil
        let txid = try await client.broadcastTransaction(txHex: "0200", network: .mainnet, baseURL: nil)
        XCTAssertEqual(txid, RecordingEndpointClient.txid)
    }

    func testFailoverClient_transactionIsSeenIfAnyServiceHasItAndUnseenOnlyIfOneAnswered() async throws {
        let endpoints = RecordingEndpointClient()
        let client = BitcoinFailoverIndexerClient(client: endpoints, health: BitcoinIndexerEndpointHealth())
        let confirmed = BitcoinEsploraTxStatus(confirmed: true, blockHash: nil, blockHeight: 10, blockTime: nil)

        endpoints.statuses = [Self.primary: .success(nil), Self.fallback: .success(confirmed)]
        let seen = try await client.transactionStatus(txid: RecordingEndpointClient.txid, network: .mainnet, baseURL: nil)
        XCTAssertEqual(seen, confirmed)

        endpoints.statuses = [Self.primary: .failure(URLError(.timedOut)), Self.fallback: .success(nil)]
        let unseen = try await client.transactionStatus(txid: RecordingEndpointClient.txid, network: .mainnet, baseURL: nil)
        XCTAssertNil(unseen)

        endpoints.statuses = [Self.primary: .failure(URLError(.timedOut)), Self.fallback: .failure(URLError(.timedOut))]
        await assertThrows(URLError(.timedOut)) {
            _ = try await client.transactionStatus(txid: RecordingEndpointClient.txid, network: .mainnet, baseURL: nil)
        }
    }

    func testIndexerClient_readsTransactionStatusAndOutspend() async throws {
        let transport = ScriptedTransport()
        let client = BitcoinIndexerClient(transport: transport)
        let txid = RecordingEndpointClient.txid

        transport.responses = [
            .success(Data(#"{"txid":"\#(txid)","version":2,"vin":[],"vout":[],"status":{"confirmed":false}}"#.utf8))
        ]
        let mempool = try await client.transactionStatus(txid: txid.uppercased(), network: .mainnet, baseURL: nil)
        XCTAssertEqual(mempool?.confirmed, false)
        // `/tx/:txid`, never `/tx/:txid/status`: electrs answers the latter with
        // {"confirmed":false} for a transaction it has never seen.
        XCTAssertEqual(transport.requests.last?.url?.absoluteString, "https://mempool.space/api/tx/\(txid)")

        transport.responses = [
            .success(Data(#"{"txid":"\#(txid)","status":{"confirmed":true,"block_height":840000}}"#.utf8))
        ]
        let confirmed = try await client.transactionStatus(txid: txid, network: .mainnet, baseURL: nil)
        XCTAssertEqual(confirmed?.confirmed, true)
        XCTAssertEqual(confirmed?.blockHeight, 840_000)

        transport.responses = [.failure(UniversalWalletHTTPTransportError.httpStatusCode(404, Data("Transaction not found".utf8)))]
        let unknown = try await client.transactionStatus(txid: txid, network: .mainnet, baseURL: nil)
        XCTAssertNil(unknown)

        // A reply about another transaction proves nothing about this one.
        transport.responses = [
            .success(Data(#"{"txid":"\#(String(repeating: "cd", count: 32))","status":{"confirmed":true}}"#.utf8))
        ]
        await assertThrows(BitcoinIndexerClientError.unexpectedTransaction) {
            _ = try await client.transactionStatus(txid: txid, network: .mainnet, baseURL: nil)
        }

        transport.responses = [.failure(UniversalWalletHTTPTransportError.httpStatusCode(500, Data()))]
        await assertThrows(UniversalWalletHTTPTransportError.httpStatusCode(500, Data())) {
            _ = try await client.transactionStatus(txid: txid, network: .mainnet, baseURL: nil)
        }

        transport.responses = [
            .success(Data(#"{"spent":true,"txid":"\#(txid)","vin":0,"status":{"confirmed":true,"block_height":5}}"#.utf8))
        ]
        let outspend = try await client.outspend(
            txid: txid,
            vout: 1,
            network: .testnet,
            baseURL: "https://blockstream.info/testnet/api/"
        )
        XCTAssertEqual(outspend.spent, true)
        XCTAssertEqual(outspend.txid, txid)
        XCTAssertEqual(outspend.status?.confirmed, true)
        XCTAssertEqual(
            transport.requests.last?.url?.absoluteString,
            "https://blockstream.info/testnet/api/tx/\(txid)/outspend/1"
        )

        transport.responses = [.success(Data(#"{"spent":false}"#.utf8))]
        let unspent = try await client.outspend(txid: txid, vout: 0, network: .mainnet, baseURL: nil)
        XCTAssertEqual(unspent, BitcoinEsploraOutspend(spent: false))
    }

    func testBitcoinNetworksFailOverBetweenMempoolSpaceAndBlockstream() {
        XCTAssertEqual(
            BitcoinIndexerNetwork.mainnet.baseURLs.map(\.absoluteString),
            ["https://mempool.space/api", "https://blockstream.info/api"]
        )
        XCTAssertEqual(
            BitcoinIndexerNetwork.testnet.baseURLs.map(\.absoluteString),
            ["https://mempool.space/testnet/api", "https://blockstream.info/testnet/api"]
        )
    }

    func testTransport_reportsRateLimitsWithTheServicesRetryAfter() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(URLSessionUniversalWalletHTTPTransport.retryAfter(from: "120"), 120)
        XCTAssertEqual(URLSessionUniversalWalletHTTPTransport.retryAfter(from: " 7 "), 7)
        XCTAssertEqual(URLSessionUniversalWalletHTTPTransport.retryAfter(from: "-5"), 0)
        XCTAssertEqual(
            URLSessionUniversalWalletHTTPTransport.retryAfter(from: "86400"),
            URLSessionUniversalWalletHTTPTransport.maxRetryAfter
        )
        XCTAssertEqual(
            URLSessionUniversalWalletHTTPTransport.retryAfter(from: "Mon, 15 Jan 2027 08:01:00 GMT", now: now),
            60
        )
        XCTAssertNil(URLSessionUniversalWalletHTTPTransport.retryAfter(from: "soon"))
        XCTAssertNil(URLSessionUniversalWalletHTTPTransport.retryAfter(from: nil))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RateLimitedURLProtocol.self]
        let transport = URLSessionUniversalWalletHTTPTransport(session: URLSession(configuration: configuration))

        RateLimitedURLProtocol.response = (429, ["Retry-After": "45"])
        await assertThrows(UniversalWalletHTTPTransportError.rateLimited(statusCode: 429, retryAfter: 45)) {
            _ = try await transport.perform(URLRequest(url: URL(string: "https://rate-limited.invalid/api/fee-estimates")!))
        }
        RateLimitedURLProtocol.response = (503, [:])
        await assertThrows(UniversalWalletHTTPTransportError.rateLimited(statusCode: 503, retryAfter: nil)) {
            _ = try await transport.perform(URLRequest(url: URL(string: "https://rate-limited.invalid/api/fee-estimates")!))
        }
        RateLimitedURLProtocol.response = (404, [:])
        await assertThrows(UniversalWalletHTTPTransportError.httpStatusCode(404, Data("body".utf8))) {
            _ = try await transport.perform(URLRequest(url: URL(string: "https://rate-limited.invalid/api/tx/00/status")!))
        }
    }

    // MARK: - Helpers

    private static let primary = "https://mempool.space/api"
    private static let fallback = "https://blockstream.info/api"

    private var scope: BitcoinPendingBroadcastScope {
        BitcoinPendingBroadcastScope(walletId: wallet.metaId, chainId: BitcoinTestWallet.chain.chainId)
    }

    private func makeService(
        store: BitcoinPendingBroadcastStore? = nil,
        mnemonicProvider: BitcoinMnemonicProviding = BitcoinTestMnemonicProvider(),
        sendGate: UniversalSendGate = UniversalSendGate(policy: .production, remoteConfig: { .defaultConfig })
    ) -> BitcoinTransferService {
        BitcoinTransferService(
            wallet: wallet,
            chain: BitcoinTestWallet.chain,
            client: ledger,
            mnemonicProvider: mnemonicProvider,
            sendGate: sendGate,
            pendingStore: store ?? self.store,
            statusPolling: .once
        )
    }

    /// Runs a submit that must end as "outcome unknown" and returns the transaction ID it names.
    private func assertOutcomeUnknown(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ submit: () async throws -> String
    ) async throws -> String {
        do {
            _ = try await submit()
            XCTFail("Expected the broadcast outcome to be unknown", file: file, line: line)
            throw BitcoinTestError.unexpectedSuccess
        } catch let TransferServiceError.bitcoinBroadcastOutcomeUnknown(txid) {
            return txid
        }
    }

    private func assertTransferError(
        _ expected: BitcoinTestTransferError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(BitcoinTestTransferError(error), expected, "\(error)", file: file, line: line)
        }
    }

    private func assertThrows<E: Error & Equatable>(
        _ expected: E,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? E, expected, "\(error)", file: file, line: line)
        }
    }
}

// MARK: - Shared Bitcoin test support (used by the other IOSUX-3 suites)

enum BitcoinTestError: Error {
    case unexpectedSuccess
    case malformedTransaction
}

/// `TransferServiceError` is not `Equatable`; this mirrors the cases the Bitcoin tests assert.
enum BitcoinTestTransferError: Equatable {
    case bitcoinSendPaused
    case bitcoinBroadcastOutcomeUnknown(txid: String)
    case bitcoinPriorTransferUnresolved(txid: String)
    case bitcoinPriorTransferConfirmed(txid: String)
    case bitcoinTransferNotSent(BitcoinTransferNotSentReason)
    case other(String)

    init(_ error: Error) {
        switch error as? TransferServiceError {
        case .bitcoinSendPaused:
            self = .bitcoinSendPaused
        case let .bitcoinBroadcastOutcomeUnknown(txid):
            self = .bitcoinBroadcastOutcomeUnknown(txid: txid)
        case let .bitcoinPriorTransferUnresolved(txid):
            self = .bitcoinPriorTransferUnresolved(txid: txid)
        case let .bitcoinPriorTransferConfirmed(txid):
            self = .bitcoinPriorTransferConfirmed(txid: txid)
        case let .bitcoinTransferNotSent(reason):
            self = .bitcoinTransferNotSent(reason)
        default:
            self = .other(String(describing: error))
        }
    }
}

enum BitcoinTestWallet {
    static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    /// m/84'/0'/0'/0/0 of `mnemonic`.
    static let address = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    static let recipient = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
    static let asset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )
    static let chain = ChainModel(
        rank: nil,
        disabled: false,
        chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
        parentId: nil,
        paraId: nil,
        name: "Bitcoin",
        assets: [asset],
        xcm: nil,
        nodes: [],
        addressPrefix: 0,
        types: nil,
        icon: nil,
        options: nil,
        externalApi: nil,
        selectedNode: nil,
        customNodes: nil,
        iosMinAppVersion: nil,
        identityChain: nil
    )

    static func wallet() throws -> MetaAccountModel {
        let account = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .mainnet)
        return AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
                accountId: account.publicKey,
                publicKey: account.publicKey,
                cryptoType: CryptoType.ecdsa.rawValue,
                ethereumBased: false
            )
        ])
    }

    static func transfer(sats: Int64, to receiver: String = recipient) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            amount: BigUInt(UInt64(sats)),
            receiver: receiver,
            tip: nil,
            appId: nil
        )
    }
}

final class BitcoinTestMnemonicProvider: BitcoinMnemonicProviding {
    private let mnemonic: String?
    private(set) var callCount = 0

    init(mnemonic: String? = BitcoinTestWallet.mnemonic) {
        self.mnemonic = mnemonic
    }

    func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
        callCount += 1
        return mnemonic
    }
}

/// The parts of a signed transaction the tests reason about, read back from the bytes the
/// wallet handed to the network.
struct ParsedBitcoinTransaction: Equatable {
    struct Output: Equatable {
        let valueSats: Int64
        let script: Data
    }

    let txid: String
    let inputs: [BitcoinOutpoint]
    let outputs: [Output]
    let sequences: [UInt32]
    let vsize: Int

    init(hex: String) throws {
        let bytes = try Self.bytes(fromHex: hex)
        var reader = Reader(bytes: bytes)
        let version = try reader.take(4)
        let isSegwit = try reader.peek(2) == [0x00, 0x01]
        if isSegwit {
            _ = try reader.take(2)
        }

        let bodyStart = reader.offset
        var inputs: [BitcoinOutpoint] = []
        var sequences: [UInt32] = []
        for _ in 0 ..< (try reader.varInt()) {
            let txid = try reader.take(32).reversed().map { String(format: "%02x", $0) }.joined()
            let vout = Int64(try reader.uint32())
            _ = try reader.take(Int(try reader.varInt()))
            sequences.append(try reader.uint32())
            inputs.append(BitcoinOutpoint(txid: txid, vout: vout))
        }
        var outputs: [Output] = []
        for _ in 0 ..< (try reader.varInt()) {
            let value = Int64(try reader.uint64())
            outputs.append(Output(valueSats: value, script: Data(try reader.take(Int(try reader.varInt())))))
        }
        let bodyEnd = reader.offset
        if isSegwit {
            for _ in inputs {
                for _ in 0 ..< (try reader.varInt()) {
                    _ = try reader.take(Int(try reader.varInt()))
                }
            }
        }
        let locktime = try reader.take(4)
        guard reader.offset == bytes.count else {
            throw BitcoinTestError.malformedTransaction
        }

        let stripped = version + Array(bytes[bodyStart ..< bodyEnd]) + locktime
        txid = Self.sha256(Self.sha256(stripped)).reversed().map { String(format: "%02x", $0) }.joined()
        self.inputs = inputs
        self.outputs = outputs
        self.sequences = sequences
        vsize = Int((Double(stripped.count * 3 + bytes.count) / 4).rounded(.up))
    }

    private struct Reader {
        let bytes: [UInt8]
        var offset = 0

        func peek(_ count: Int) throws -> [UInt8] {
            guard offset + count <= bytes.count else {
                throw BitcoinTestError.malformedTransaction
            }
            return Array(bytes[offset ..< offset + count])
        }

        mutating func take(_ count: Int) throws -> [UInt8] {
            let slice = try peek(count)
            offset += count
            return slice
        }

        mutating func uint32() throws -> UInt32 {
            try take(4).reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        }

        mutating func uint64() throws -> UInt64 {
            try take(8).reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        }

        mutating func varInt() throws -> UInt64 {
            let first = try take(1)[0]
            switch first {
            case 0xFD:
                return try take(2).reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            case 0xFE:
                return UInt64(try uint32())
            case 0xFF:
                return try uint64()
            default:
                return UInt64(first)
            }
        }
    }

    private static func bytes(fromHex hex: String) throws -> [UInt8] {
        guard hex.count.isMultiple(of: 2) else {
            throw BitcoinTestError.malformedTransaction
        }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                throw BitcoinTestError.malformedTransaction
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private static func sha256(_ bytes: [UInt8]) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = CC_SHA256(bytes, CC_LONG(bytes.count), &output)
        return output
    }
}

/// An in-memory stand-in for an Esplora service and the node behind it. It applies the same
/// rules that matter for these tests: a transaction is accepted only if every coin it spends
/// is unspent, accepted transactions hide their inputs from `/utxo` at once (the mempool-aware
/// view that makes a re-plan pick other coins), and their outputs stay unconfirmed until mined.
final class BitcoinTestLedger: BitcoinIndexerClientProtocol {
    enum BroadcastStep {
        /// The node accepts the transaction and the wallet gets the reply.
        case accept
        /// The node accepts the transaction but the wallet gets this error instead of the reply.
        case acceptButFail(Error)
        /// The node never sees the transaction; the wallet gets this error.
        case fail(Error)
    }

    struct Coin: Equatable {
        let outpoint: BitcoinOutpoint
        let valueSats: Int64
        let script: Data
        var confirmed: Bool
        var spentBy: String?
        var spendConfirmed = false
    }

    var broadcastScript: [BroadcastStep] = []
    /// When set, transaction and outspend lookups fail with it (the indexer cannot be asked).
    var lookupError: Error?
    var feeEstimates: [String: Double] = ["2": 2]
    var onBroadcast: ((String) -> Void)?
    private(set) var broadcasts: [String] = []
    private(set) var utxoRequests: [String] = []
    private(set) var statusRequests: [String] = []
    private var coins: [Coin] = []
    private var transactions: [String: Bool] = [:]
    private var fundingCounter = 0
    private let network: BitcoinKeyDerivation.Network

    init(network: BitcoinKeyDerivation.Network = .mainnet) {
        self.network = network
    }

    @discardableResult
    func fund(_ address: String, sats: Int64, confirmed: Bool = true) -> BitcoinOutpoint {
        fundingCounter += 1
        let txid = String(format: "%064x", fundingCounter)
        let outpoint = BitcoinOutpoint(txid: txid, vout: 0)
        transactions[txid] = confirmed
        coins.append(Coin(outpoint: outpoint, valueSats: sats, script: script(for: address), confirmed: confirmed))
        return outpoint
    }

    /// Mines a block: every mempool transaction and its outputs become confirmed.
    func confirmAll() {
        transactions = transactions.mapValues { _ in true }
        coins = coins.map { coin in
            var coin = coin
            coin.confirmed = true
            coin.spendConfirmed = coin.spentBy != nil
            return coin
        }
    }

    /// A transaction the wallet knows nothing about spends one of its coins.
    func spendElsewhere(_ outpoint: BitcoinOutpoint, confirmed: Bool) {
        guard let index = coins.firstIndex(where: { $0.outpoint == outpoint }) else {
            return
        }
        let txid = String(repeating: "ee", count: 32)
        transactions[txid] = confirmed
        coins[index].spentBy = txid
        coins[index].spendConfirmed = confirmed
    }

    func unspent(_ address: String) -> [Coin] {
        let script = script(for: address)
        return coins.filter { $0.script == script && $0.spentBy == nil }
    }

    func received(by address: String) -> Int64 {
        let script = script(for: address)
        return coins.filter { $0.script == script }.reduce(0) { $0 + $1.valueSats }
    }

    func fee(of transaction: ParsedBitcoinTransaction) -> Int64 {
        let inputTotal = transaction.inputs.reduce(Int64(0)) { total, input in
            total + (coins.first { $0.outpoint == input }?.valueSats ?? 0)
        }
        return inputTotal - transaction.outputs.reduce(0) { $0 + $1.valueSats }
    }

    /// What a node does with a raw transaction: all inputs unspent, or it is refused.
    @discardableResult
    func accept(txHex: String) throws -> String {
        let transaction = try ParsedBitcoinTransaction(hex: txHex)
        if transactions[transaction.txid] != nil {
            throw UniversalWalletHTTPTransportError.httpStatusCode(
                400,
                Data(#"sendrawtransaction RPC error: {"code":-27,"message":"Transaction outputs already in utxo set"}"#.utf8)
            )
        }
        let indexes = transaction.inputs.map { input in
            coins.firstIndex { $0.outpoint == input && $0.spentBy == nil }
        }
        guard !indexes.contains(nil) else {
            throw UniversalWalletHTTPTransportError.httpStatusCode(
                400,
                Data(#"sendrawtransaction RPC error: {"code":-25,"message":"bad-txns-inputs-missingorspent"}"#.utf8)
            )
        }
        indexes.compactMap { $0 }.forEach { coins[$0].spentBy = transaction.txid }
        transactions[transaction.txid] = false
        for (vout, output) in transaction.outputs.enumerated() {
            coins.append(
                Coin(
                    outpoint: BitcoinOutpoint(txid: transaction.txid, vout: Int64(vout)),
                    valueSats: output.valueSats,
                    script: output.script,
                    confirmed: false
                )
            )
        }
        return transaction.txid
    }

    // MARK: BitcoinIndexerClientProtocol

    func address(
        address: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> BitcoinEsploraAddress {
        let script = script(for: address)
        let owned = coins.filter { $0.script == script }
        let chainFunded = owned.filter(\.confirmed)
        let chainSpent = owned.filter { $0.spentBy != nil && $0.spendConfirmed }
        let mempoolFunded = owned.filter { !$0.confirmed }
        let mempoolSpent = owned.filter { $0.spentBy != nil && !$0.spendConfirmed }
        let chainTxids = Set(chainFunded.map(\.outpoint.txid)).union(chainSpent.compactMap(\.spentBy))
        let mempoolTxids = Set(mempoolFunded.map(\.outpoint.txid)).union(mempoolSpent.compactMap(\.spentBy))

        return BitcoinEsploraAddress(
            address: address,
            chainStats: BitcoinEsploraStats(
                fundedTxoCount: chainFunded.count,
                fundedTxoSum: chainFunded.reduce(0) { $0 + $1.valueSats },
                spentTxoCount: chainSpent.count,
                spentTxoSum: chainSpent.reduce(0) { $0 + $1.valueSats },
                txCount: chainTxids.count
            ),
            mempoolStats: BitcoinEsploraStats(
                fundedTxoCount: mempoolFunded.count,
                fundedTxoSum: mempoolFunded.reduce(0) { $0 + $1.valueSats },
                spentTxoCount: mempoolSpent.count,
                spentTxoSum: mempoolSpent.reduce(0) { $0 + $1.valueSats },
                txCount: mempoolTxids.count
            )
        )
    }

    func utxos(
        address: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> [BitcoinEsploraUtxo] {
        utxoRequests.append(address)
        return unspent(address).map {
            BitcoinEsploraUtxo(
                txid: $0.outpoint.txid,
                vout: $0.outpoint.vout,
                value: $0.valueSats,
                status: BitcoinEsploraTxStatus(confirmed: $0.confirmed, blockHash: nil, blockHeight: nil, blockTime: nil)
            )
        }
    }

    func transactions(
        address _: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?,
        lastSeenTxid _: String?,
        mempool _: Bool
    ) async throws -> [BitcoinEsploraTransaction] {
        []
    }

    func feeEstimates(network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> [String: Double] {
        feeEstimates
    }

    func broadcastTransaction(
        txHex: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> String {
        onBroadcast?(txHex)
        broadcasts.append(txHex)
        switch broadcastScript.isEmpty ? .accept : broadcastScript.removeFirst() {
        case .accept:
            return try accept(txHex: txHex)
        case let .acceptButFail(error):
            try accept(txHex: txHex)
            throw error
        case let .fail(error):
            throw error
        }
    }

    func transactionStatus(
        txid: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> BitcoinEsploraTxStatus? {
        statusRequests.append(txid)
        if let lookupError {
            throw lookupError
        }
        return transactions[txid].map {
            BitcoinEsploraTxStatus(confirmed: $0, blockHash: nil, blockHeight: nil, blockTime: nil)
        }
    }

    func outspend(
        txid: String,
        vout: Int64,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?
    ) async throws -> BitcoinEsploraOutspend {
        if let lookupError {
            throw lookupError
        }
        guard
            let coin = coins.first(where: { $0.outpoint == BitcoinOutpoint(txid: txid, vout: vout) }),
            let spender = coin.spentBy
        else {
            return BitcoinEsploraOutspend(spent: false)
        }
        return BitcoinEsploraOutspend(
            spent: true,
            txid: spender,
            vin: 0,
            status: BitcoinEsploraTxStatus(confirmed: coin.spendConfirmed, blockHash: nil, blockHeight: nil, blockTime: nil)
        )
    }

    private func script(for address: String) -> Data {
        BitcoinAddressSupport.recipient(address, network: network)?.scriptPubKey ?? Data(address.utf8)
    }
}

/// Records which Esplora base URL each call was sent to and fails the ones it is told to.
private final class RecordingEndpointClient: BitcoinIndexerClientProtocol {
    static let txid = String(repeating: "ab", count: 32)

    var readErrors: [String: Error] = [:]
    var broadcastErrors: [String: Error] = [:]
    var statuses: [String: Result<BitcoinEsploraTxStatus?, Error>] = [:]
    private(set) var readRequests: [String] = []
    private(set) var broadcastRequests: [(endpoint: String, txHex: String)] = []

    func feeEstimates(network _: BitcoinIndexerNetwork, baseURL: String?) async throws -> [String: Double] {
        let endpoint = baseURL ?? "default"
        readRequests.append(endpoint)
        if let error = readErrors[endpoint] {
            throw error
        }
        return ["2": 2]
    }

    func broadcastTransaction(txHex: String, network _: BitcoinIndexerNetwork, baseURL: String?) async throws -> String {
        let endpoint = baseURL ?? "default"
        broadcastRequests.append((endpoint, txHex))
        if let error = broadcastErrors[endpoint] {
            throw error
        }
        return Self.txid
    }

    func transactionStatus(
        txid _: String,
        network _: BitcoinIndexerNetwork,
        baseURL: String?
    ) async throws -> BitcoinEsploraTxStatus? {
        try (statuses[baseURL ?? "default"] ?? .success(nil)).get()
    }

    func address(address _: String, network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> BitcoinEsploraAddress {
        throw BitcoinTestError.malformedTransaction
    }

    func utxos(address _: String, network _: BitcoinIndexerNetwork, baseURL _: String?) async throws -> [BitcoinEsploraUtxo] {
        throw BitcoinTestError.malformedTransaction
    }

    func transactions(
        address _: String,
        network _: BitcoinIndexerNetwork,
        baseURL _: String?,
        lastSeenTxid _: String?,
        mempool _: Bool
    ) async throws -> [BitcoinEsploraTransaction] {
        throw BitcoinTestError.malformedTransaction
    }
}

private final class ScriptedTransport: UniversalWalletHTTPTransport {
    var responses: [Result<Data, Error>] = []
    private(set) var requests: [URLRequest] = []

    func perform(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        return try responses.removeFirst().get()
    }
}

/// Answers every request of a session with a fixed status and headers, without any network.
private final class RateLimitedURLProtocol: URLProtocol {
    static var response: (status: Int, headers: [String: String]) = (429, [:])

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: Self.response.status,
                httpVersion: "HTTP/1.1",
                headerFields: Self.response.headers
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("body".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
