import XCTest
import BigInt
import SSFModels
import TonSwift
import Web3
@testable import fearless

final class CovHSendConfirmPresenterTests: XCTestCase {
    private let messageHash = String(repeating: "0123456789abcdef", count: 4)

    func testInitialFeeViewModelAndSenderAccountReachTheViewModel() throws {
        let asset = CovHSendFixtures.asset(id: "native", symbol: "NAT", utility: true, precision: 12)
        let chain = CovHSendFixtures.chain(name: "Covh Substrate", assets: [asset])
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: chainAsset, feeViewModel: BalanceViewModel(amount: "0.5", price: nil))
        fixture.presenter.setup()
        CovHSendWait.until { !fixture.factory.parameters.isEmpty }

        XCTAssertEqual(fixture.interactor.setupCount, 1)
        let parameters = try XCTUnwrap(fixture.factory.parameters.first)
        XCTAssertEqual(parameters.feeViewModel?.amount, "0.5")
        let expected = try XCTUnwrap(fixture.wallet.fetch(for: chain.accountRequest())?.toAddress())
        XCTAssertEqual(parameters.senderAccountViewModel?.name, expected)
        XCTAssertEqual(parameters.receiverAccountViewModel?.name, "receiver-address")
        XCTAssertEqual(fixture.view.states.count, 1)
        XCTAssertTrue(fixture.view.loadingFlags.isEmpty, "Only TON starts in the loading state")
    }

    func testTonFeeIsUsableOnlyAfterTheServiceConfirmsThePresentedQuote() throws {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
        fixture.presenter.setup()
        XCTAssertEqual(fixture.view.loadingFlags, [true])
        fixture.presenter.didReceiveAccountInfo(result: .success(nil), for: fixture.chainAsset)
        fixture.presenter.didReceiveMinimumBalance(result: .success(1))

        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5_000_000)))
        XCTAssertEqual(fixture.view.loadingFlags.last, true)
        CovHSendWait.until { fixture.interactor.feeConfirmations.count == 1 }
        XCTAssertEqual(fixture.interactor.feeConfirmations, [5_000_000])

        fixture.presenter.didTapConfirmButton()
        XCTAssertEqual(fixture.authorizer.requests, 0, "TON cannot be confirmed before the quote is accepted")

        fixture.interactor.feeCompletions[0](true)
        XCTAssertEqual(fixture.view.loadingFlags.last, false)

        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 6_000_000)))
        CovHSendWait.until { fixture.interactor.feeConfirmations.count == 2 }
        fixture.interactor.feeCompletions[1](false)
        XCTAssertEqual(fixture.view.loadingFlags.last, true, "A refused quote keeps Confirm disabled")
    }

    func testStaleTonFeeConfirmationIsIgnored() {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
        fixture.presenter.setup()
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 7)))
        CovHSendWait.until { fixture.interactor.feeConfirmations.count == 1 }
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 8)))
        let flags = fixture.view.loadingFlags.count
        fixture.interactor.feeCompletions[0](true)
        XCTAssertEqual(fixture.view.loadingFlags.count, flags, "A newer quote replaced the one being confirmed")
        CovHSendWait.until { fixture.interactor.feeConfirmations.count == 2 }
        XCTAssertEqual(fixture.interactor.feeConfirmations, [7, 8])
    }

    func testTonFeeFailureDisablesConfirmAndIsLogged() {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
        fixture.presenter.didReceiveFee(result: .failure(CovHSendError.failed))
        XCTAssertEqual(fixture.view.loadingFlags, [true])
        XCTAssertTrue(fixture.logger.errors.contains { $0.contains("Did receive fee error") })
        XCTAssertTrue(fixture.wireframe.sheets.isEmpty)
    }

    func testTonSuccessAcknowledgesTheReceiptOnlyAfterPresentation() throws {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
        let wireframe = try XCTUnwrap(fixture.wireframe as? CovHSendConfirmCompletingWireframe)
        fixture.presenter.didTransfer(result: .success("ton-hash"))
        XCTAssertEqual(fixture.view.stops, 1)
        XCTAssertEqual(fixture.view.stages, [.accepted])
        XCTAssertEqual(wireframe.presentedCompletions, ["ton-hash"])
        XCTAssertTrue(fixture.interactor.acknowledgements.isEmpty)

        wireframe.completion?()
        XCTAssertEqual(fixture.interactor.acknowledgements.first?.hash, "ton-hash")
        XCTAssertEqual(fixture.interactor.acknowledgements.first?.recovered, false)
        XCTAssertTrue(fixture.logger.errors.contains { $0.contains("tombstone retained") })
        XCTAssertTrue(wireframe.completed.isEmpty)
    }

    func testTonSuccessWithoutPresentationCallbackCompletesDirectly() {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative(), completing: false)
        fixture.presenter.didTransfer(result: .success("ton-hash"))
        XCTAssertEqual(fixture.wireframe.completed, ["ton-hash"])
        XCTAssertTrue(fixture.interactor.acknowledgements.isEmpty)
    }

    func testTonUnknownOutcomeOffersTheMessageHashToCopy() throws {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
        fixture.presenter.didTransfer(result: .failure(TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex: messageHash)))
        let sheet = try XCTUnwrap(fixture.wireframe.sheets.last)
        XCTAssertTrue(sheet.message?.contains(messageHash) == true)
        XCTAssertEqual(sheet.actions.count, 1)
        sheet.actions.first?.handler?()
        XCTAssertEqual(fixture.pasteboard.string, messageHash)
        XCTAssertEqual(fixture.feedback.plays, 0)
        XCTAssertEqual(fixture.wireframe.extrinsicFailed, 0)
    }

    func testMalformedTonHashFallsBackToTheGenericFailure() {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
        fixture.presenter.didTransfer(result: .failure(TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex: "XYZ")))
        XCTAssertTrue(fixture.wireframe.sheets.isEmpty)
        XCTAssertEqual(fixture.feedback.plays, 1)
        XCTAssertEqual(fixture.view.breaks, 1)
        XCTAssertEqual(fixture.wireframe.errors.count, 1)
        XCTAssertEqual(fixture.wireframe.extrinsicFailed, 1)
    }

    func testTonPriorTransferConfirmedAcknowledgesAndRequotesOrReportsFailure() throws {
        let identity = try tonIdentity()
        for acknowledged in [true, false] {
            let fixture = CovHSendConfirmPresenterFixture(chainAsset: tonNative())
            fixture.interactor.acknowledgeResult = acknowledged
            let error = TransferServiceError.tonPriorTransferConfirmed(identity: identity, messageHashHex: messageHash)
            fixture.presenter.didTransfer(result: .failure(error))
            XCTAssertEqual(fixture.view.loadingFlags.last, true)
            let sheet = try XCTUnwrap(fixture.wireframe.sheets.last)
            XCTAssertTrue(sheet.message?.contains(messageHash) == true)
            sheet.actions.first?.handler?()
            XCTAssertEqual(fixture.interactor.acknowledgements.first?.hash, messageHash)
            XCTAssertEqual(fixture.interactor.acknowledgements.first?.recovered, true)
            XCTAssertEqual(fixture.interactor.refreshCount, acknowledged ? 1 : 0)
            XCTAssertEqual(fixture.wireframe.extrinsicFailed, acknowledged ? 0 : 1)
        }
    }

    func testBitcoinPriorUnresolvedRetryCloseAndReplaceChoices() throws {
        let btc = try CovHSendFixtures.bitcoin()
        let txid = messageHash
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: btc)
        let error = TransferServiceError.bitcoinPriorTransferUnresolved(txid: txid)

        fixture.presenter.didTransfer(result: .failure(error))
        var sheet = try XCTUnwrap(fixture.wireframe.sheets.last)
        XCTAssertEqual(sheet.actions.count, 3)
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.retried, [txid])
        XCTAssertEqual(fixture.view.starts, 1)

        fixture.presenter.didTransfer(result: .failure(error))
        sheet = try XCTUnwrap(fixture.wireframe.sheets.last)
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.retried, [txid], "Closing keeps the earlier transfer as it is")
        XCTAssertTrue(fixture.interactor.replacements.isEmpty)

        fixture.interactor.replaceAllowed = false
        fixture.presenter.didTransfer(result: .failure(error))
        sheet = try XCTUnwrap(fixture.wireframe.sheets.last)
        sheet.actions[1].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.replacements, [txid])
        XCTAssertEqual(fixture.wireframe.extrinsicFailed, 1)
        XCTAssertEqual(fixture.interactor.refreshCount, 0)
    }

    func testBitcoinReplacementRequotesAndShowsTheFeeRate() throws {
        let btc = try CovHSendFixtures.bitcoin()
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: btc)
        fixture.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinPriorTransferUnresolved(txid: messageHash)))
        let sheet = try XCTUnwrap(fixture.wireframe.sheets.last)
        sheet.actions[1].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(fixture.interactor.refreshCount, 1)
        let stopsBeforeQuote = fixture.view.stops

        fixture.presenter.didReceiveFeeRate(satPerVbyte: 2.5)
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 282)))
        XCTAssertEqual(fixture.view.stops, stopsBeforeQuote + 1, "The requote ends the loading state")
        CovHSendWait.until { fixture.factory.parameters.last?.feeViewModel?.amount.contains("sat/vB") == true }
        XCTAssertTrue(fixture.factory.parameters.last?.feeViewModel?.amount.contains(" · ") == true)
        XCTAssertEqual(fixture.interactor.eqRequests.count, 1)

        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 300)))
        XCTAssertEqual(fixture.view.stops, stopsBeforeQuote + 1, "Only an awaited requote stops loading")
    }

    func testMalformedBitcoinTxidsFallBackToTheGenericFailure() throws {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinPriorTransferUnresolved(txid: "bad")))
        fixture.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinPriorTransferConfirmed(txid: "bad")))
        XCTAssertTrue(fixture.wireframe.sheets.isEmpty)
        XCTAssertEqual(fixture.wireframe.errors.count, 2)
        XCTAssertEqual(fixture.wireframe.extrinsicFailed, 2)
        XCTAssertEqual(fixture.interactor.refreshCount, 2, "A failed Bitcoin attempt is quoted again")
    }

    func testEthereumAmountTooHighErrorHasItsOwnMessage() throws {
        let data = Data(#"{"code":-32000,"message":"insufficient funds"}"#.utf8)
        let rpcError = try JSONDecoder().decode(RPCResponse<EthereumData>.Error.self, from: data)
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: CovHSendFixtures.chainAsset(chainName: "Covh EVM", assetUtility: true))
        fixture.presenter.didTransfer(result: .failure(rpcError))
        XCTAssertEqual(fixture.wireframe.amountTooHigh, 1)
        XCTAssertTrue(fixture.wireframe.errors.isEmpty)
        XCTAssertEqual(fixture.interactor.refreshCount, 0)
    }

    func testFailureWithoutViewIsDropped() {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: CovHSendFixtures.chainAsset(chainName: "Covh", assetUtility: true))
        fixture.presenter.view = nil
        fixture.presenter.didTransfer(result: .failure(CovHSendError.failed))
        XCTAssertTrue(fixture.wireframe.errors.isEmpty)
        XCTAssertEqual(fixture.feedback.plays, 0)
    }

    func testSolanaCancellationStopsLoadingWithoutAnError() throws {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: try CovHSendFixtures.solana())
        XCTAssertFalse(fixture.presenter.hasOwnedRecoveryPresentation)
        fixture.presenter.didTransfer(result: .failure(CancellationError()))
        XCTAssertEqual(fixture.view.stops, 1)
        XCTAssertTrue(fixture.wireframe.errors.isEmpty)
        XCTAssertTrue(fixture.wireframe.sheets.isEmpty)
        XCTAssertEqual(fixture.feedback.plays, 0)
    }

    func testXorlessConfirmRequiresAuthorization() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Sora", assetUtility: true)
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: chainAsset, call: .xorlessTransfer(CovHSendFixtures.xorless()))
        fixture.authorizer.granted = false
        fixture.presenter.didTapConfirmButton()
        XCTAssertEqual(fixture.authorizer.requests, 1)
        XCTAssertEqual(fixture.interactor.submitCount, 0)

        fixture.authorizer.granted = true
        fixture.presenter.didTapConfirmButton()
        XCTAssertEqual(fixture.interactor.submitCount, 1)
        XCTAssertEqual(fixture.view.starts, 1)
        XCTAssertEqual(fixture.view.stages, [.ready])
    }

    func testUtilityBalanceMinimumBalanceAndEquilibriumUpdateLoadingState() throws {
        let native = CovHSendFixtures.asset(id: "native", symbol: "NAT", utility: true)
        let token = CovHSendFixtures.asset(id: "token", symbol: "TOK", utility: false)
        let chain = CovHSendFixtures.chain(name: "Covh Multi", assets: [native, token])
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: ChainAsset(chain: chain, asset: token))
        let utility = ChainAsset(chain: chain, asset: native)
        XCTAssertEqual(fixture.interactor.feeAsset?.asset.id, native.id)

        fixture.presenter.didReceiveAccountInfo(result: .success(nil), for: utility)
        XCTAssertEqual(fixture.view.loadingFlags, [true])
        fixture.presenter.didReceiveAccountInfo(result: .failure(CovHSendError.failed), for: utility)
        XCTAssertTrue(fixture.logger.errors.contains { $0.contains("Did receive account info error") })

        fixture.presenter.didReceiveMinimumBalance(result: .success(10))
        fixture.presenter.didReceiveMinimumBalance(result: .failure(CovHSendError.failed))
        XCTAssertTrue(fixture.logger.errors.contains { $0.contains("Did receive minimum balance error") })
        fixture.presenter.didReceive(eqTotalBalance: 5)
        XCTAssertEqual(fixture.view.loadingFlags.count, 4)
        CovHSendWait.until { !fixture.factory.parameters.isEmpty }
        XCTAssertFalse(fixture.factory.parameters.isEmpty, "A minimum balance refreshes the review")
    }

    func testLoadingStateIsDeliveredOnMainWhenReportedFromBackground() {
        let fixture = CovHSendConfirmPresenterFixture(chainAsset: CovHSendFixtures.chainAsset(chainName: "Covh", assetUtility: true))
        let presenter = fixture.presenter
        DispatchQueue.global().async {
            presenter.didReceive(eqTotalBalance: 1)
        }
        CovHSendWait.until { fixture.view.loadingFlags.count == 1 }
        XCTAssertEqual(fixture.view.loadingFlags, [true])
    }

    private func tonNative() -> ChainAsset {
        let native = CovHSendFixtures.asset(id: "ton", symbol: "TON", utility: true)
        let chain = CovHSendFixtures.chain(id: "covh-ton", name: "TON", assets: [native])
        return ChainAsset(chain: chain, asset: native)
    }

    private func tonIdentity() throws -> TonTransferIntentIdentity {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let account = try TonKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let sender = try TonSwift.Address.parse(account.addressNonBounceable).toRaw()
        let recipient = try TonSwift.Address.parse("EQAimhPwOYc5Z1JP_pddxo82SHOl67T0Lklw91pKtSX2Q094").toRaw()
        let request = TonNativeSendRequest(
            mnemonic: mnemonic, senderAddress: sender, recipientAddress: recipient,
            amountNanotons: "100000000", bounce: true, comment: "covh"
        )
        return try TonTransferIntentIdentity(request: request)
    }
}
