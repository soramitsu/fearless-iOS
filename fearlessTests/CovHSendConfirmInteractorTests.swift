import XCTest
import BigInt
import RobinHood
import SSFModels
@testable import fearless

final class CovHSendConfirmInteractorTests: XCTestCase {
    func testBitcoinSetupReadsRemoteBalanceZeroMinimumAndSubscribesTheSendingServiceForFees() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.interactor.setup()
        CovHSendWait.until {
            fixture.output.accountInfos.count == 1 && fixture.service.subscribedTransfers.count == 1 && fixture.prepared.count == 1
        }

        XCTAssertEqual(fixture.remote.requests.map(\.asset.id), [fixture.chainAsset.asset.id])
        XCTAssertEqual(fixture.output.accountInfos.first?.asset.chainAssetId, fixture.chainAsset.chainAssetId)
        XCTAssertTrue(fixture.output.accountInfos.first?.isSuccess == true)
        XCTAssertEqual(fixture.output.minimumBalances, [.zero])
        XCTAssertTrue(fixture.adapter.subscribed.isEmpty)
        XCTAssertEqual(fixture.service.subscribedTransfers.first?.amount, 1000)
        XCTAssertTrue(fixture.service.listener === fixture.interactor)
        XCTAssertEqual(fixture.prepared, [fixture.chainAsset.chainAssetId])
    }

    func testRemoteBalanceFailureIsDelivered() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.remote.error = CovHSendError.failed
        fixture.interactor.setup()
        CovHSendWait.until { fixture.output.accountInfos.count == 1 }
        XCTAssertEqual(fixture.output.accountInfos.first?.isSuccess, false)
    }

    func testSolanaTokenReadsTokenAndFeeAssetBalances() throws {
        let token = try CovHSendFixtures.solanaToken()
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: token)
        fixture.interactor.setup()
        CovHSendWait.until { fixture.output.accountInfos.count == 2 }
        let requested = Set(fixture.remote.requests.map(\.asset.id))
        let utility = try XCTUnwrap(token.chain.utilityAssets().first)
        XCTAssertEqual(requested, Set([token.asset.id, utility.id]))
        XCTAssertEqual(fixture.output.minimumBalances, [.zero])
    }

    func testLocallyTrackedChainSubscribesAdapterAndForwardsHandlerResults() throws {
        let chainAsset = CovHSendFixtures.tonJetton()
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.setup()
        CovHSendWait.until { fixture.service.subscribedTransfers.count == 1 }
        XCTAssertEqual(fixture.adapter.subscribed.count, 1)
        XCTAssertEqual(fixture.adapter.subscribed.first?.map(\.asset.id), [chainAsset.asset.id, chainAsset.asset.id])
        XCTAssertTrue(fixture.remote.requests.isEmpty)

        fixture.interactor.handleAccountInfo(result: .success(nil), accountId: Data(repeating: 1, count: 32), chainAsset: chainAsset)
        XCTAssertEqual(fixture.output.accountInfos.count, 1)
        XCTAssertTrue(fixture.output.minimumBalances.isEmpty, "Locally tracked chains read the deposit from their dependencies")
    }

    func testFeePreparationFailureIsReportedAsFeeError() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.prepareError = CovHSendError.failed
        fixture.interactor.setup()
        CovHSendWait.until { fixture.output.fees.count == 1 }
        XCTAssertEqual(fixture.output.fees.first?.value, nil)
        XCTAssertTrue(fixture.output.fees.first?.error is CovHSendError)
    }

    func testFeeListenersDeliverValuesRatesDepositsAndErrorsOnMain() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.interactor.didReceiveFee(fee: 10)
        fixture.interactor.didReceiveBitcoinFee(fee: 20, feeRateSatPerVbyte: 2.5)
        fixture.interactor.didReceiveSolanaFee(fee: 30, accountCreationDeposit: 7)
        fixture.interactor.didReceiveFeeError(feeError: CovHSendError.failed)
        CovHSendWait.until { fixture.output.fees.count == 4 }
        XCTAssertEqual(fixture.output.fees.map(\.value), [10, 20, 30, nil])
        XCTAssertEqual(fixture.output.feeRates, [2.5])
        XCTAssertEqual(fixture.output.deposits, [7])
    }

    func testSubmitReportsHashOrFailure() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.service.submitResult = .success("0xbtc")
        fixture.interactor.submitExtrinsic()
        CovHSendWait.until { fixture.output.transfers.count == 1 }
        XCTAssertEqual(fixture.output.transfers.first?.hash, "0xbtc")
        XCTAssertNotNil(fixture.interactor.transferTask)

        fixture.service.submitResult = .failure(CovHSendError.failed)
        fixture.interactor.submitExtrinsic()
        CovHSendWait.until { fixture.output.transfers.count == 2 }
        XCTAssertNil(fixture.output.transfers.last?.hash)
    }

    func testRetryAndReplacementUseTheService() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.service.retryResult = .success("0xretried")
        fixture.interactor.retryUnresolvedTransfer(hash: "0xold")
        CovHSendWait.until { fixture.output.transfers.count == 1 }
        XCTAssertEqual(fixture.output.transfers.first?.hash, "0xretried")
        XCTAssertEqual(fixture.service.retried, ["0xold"])

        fixture.service.retryResult = .failure(CovHSendError.failed)
        fixture.interactor.retryUnresolvedTransfer(hash: "0xold2")
        CovHSendWait.until { fixture.output.transfers.count == 2 }
        XCTAssertNil(fixture.output.transfers.last?.hash)

        var allowed: [Bool] = []
        fixture.service.allowReplace = true
        fixture.interactor.allowReplacingUnresolvedTransfer(hash: "0xold") { allowed.append($0) }
        CovHSendWait.until { allowed.count == 1 }
        fixture.prepareError = CovHSendError.failed
        fixture.interactor.allowReplacingUnresolvedTransfer(hash: "0xold") { allowed.append($0) }
        CovHSendWait.until { allowed.count == 2 }
        XCTAssertEqual(allowed, [true, false])
    }

    func testAcknowledgementUsesSubmittedTransferAndRefusesWithoutService() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        var results: [Bool] = []
        fixture.service.acknowledgeResult = true
        fixture.interactor.acknowledgeSubmittedTransfer(hash: "0xa", recoveredIdentity: nil) { results.append($0) }
        CovHSendWait.until { results.count == 1 }
        XCTAssertEqual(fixture.service.acknowledged, ["0xa"])

        fixture.prepareError = CovHSendError.failed
        fixture.interactor.acknowledgeSubmittedTransfer(hash: "0xb", recoveredIdentity: nil) { results.append($0) }
        CovHSendWait.until { results.count == 2 }
        XCTAssertEqual(results, [true, false])
    }

    func testFeePresentationIsAlwaysAcceptedOffTon() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        var accepted: Bool?
        fixture.interactor.confirmFeePresentation(fee: 5) { accepted = $0 }
        XCTAssertEqual(accepted, true)
        XCTAssertTrue(fixture.service.confirmedPresentations.isEmpty)
    }

    func testTonFeePresentationRequiresTheQuotedFeeAndServiceConfirmation() {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: CovHSendFixtures.tonJetton())
        var results: [Bool] = []
        fixture.interactor.confirmFeePresentation(fee: 5) { results.append($0) }
        XCTAssertEqual(results, [false], "No quote has been presented yet")

        fixture.interactor.didReceiveTonFee(fee: 5, presentationID: "quote-1")
        CovHSendWait.until { fixture.output.fees.count == 1 }
        fixture.interactor.confirmFeePresentation(fee: 6) { results.append($0) }
        XCTAssertEqual(results, [false, false], "A different fee is not the presented quote")

        fixture.service.confirmAccepted = true
        fixture.interactor.confirmFeePresentation(fee: 5) { results.append($0) }
        CovHSendWait.until { results.count == 3 }
        XCTAssertEqual(results.last, true)
        XCTAssertEqual(fixture.service.confirmedPresentations.first?.id, "quote-1")
        XCTAssertEqual(fixture.service.confirmedPresentations.first?.fee, 5)

        fixture.prepareError = CovHSendError.failed
        fixture.interactor.confirmFeePresentation(fee: 5) { results.append($0) }
        CovHSendWait.until { results.count == 4 }
        XCTAssertEqual(results.last, false)

        fixture.interactor.didReceiveFee(fee: 5)
        fixture.interactor.confirmFeePresentation(fee: 5) { results.append($0) }
        XCTAssertEqual(results.last, false, "A plain fee clears the TON quote")
    }

    func testRefreshFeeReReadsRemoteBalanceAndResubscribes() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.interactor.refreshFee()
        CovHSendWait.until { fixture.remote.requests.count == 1 && fixture.service.subscribedTransfers.count == 1 }
        XCTAssertEqual(fixture.remote.requests.count, 1)
        XCTAssertEqual(fixture.service.subscribedTransfers.count, 1)

        let local = CovHSendConfirmInteractorFixture(chainAsset: CovHSendFixtures.tonJetton())
        local.interactor.refreshFee()
        CovHSendWait.until { local.service.subscribedTransfers.count == 1 }
        XCTAssertTrue(local.remote.requests.isEmpty)
        XCTAssertTrue(local.adapter.subscribed.isEmpty)
    }

    func testFeePaymentAssetResolution() throws {
        XCTAssertNil(WalletSendConfirmInteractor.resolveFeePaymentChainAsset(for: nil))
        let ton = CovHSendFixtures.tonJetton()
        XCTAssertEqual(WalletSendConfirmInteractor.resolveFeePaymentChainAsset(for: ton)?.asset.id, ton.asset.id)
        let token = try CovHSendFixtures.solanaToken()
        let utility = try XCTUnwrap(token.chain.utilityAssets().first)
        XCTAssertEqual(WalletSendConfirmInteractor.resolveFeePaymentChainAsset(for: token)?.asset.id, utility.id)
        let bare = CovHSendFixtures.chainAsset(chainName: "Bare", assetUtility: false)
        XCTAssertEqual(WalletSendConfirmInteractor.resolveFeePaymentChainAsset(for: bare)?.asset.id, bare.asset.id)
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: token)
        XCTAssertEqual(fixture.interactor.getFeePaymentChainAsset(for: token)?.asset.id, utility.id)
    }

    func testXorlessCallSkipsFeeSubscriptionAndSubmitsXorlessTransfer() throws {
        let chainAsset = try CovHSendFixtures.bitcoin()
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: chainAsset, call: .xorlessTransfer(CovHSendFixtures.xorless()))
        fixture.interactor.setup()
        CovHSendWait.until { fixture.output.accountInfos.count == 1 }
        CovHSendWait.until(timeout: 0.3) { false }
        XCTAssertTrue(fixture.service.subscribedTransfers.isEmpty)

        fixture.service.xorlessHash = "0xxorless"
        fixture.interactor.submitExtrinsic()
        CovHSendWait.until { fixture.output.transfers.count == 1 }
        XCTAssertEqual(fixture.output.transfers.first?.hash, "0xxorless")

        var acknowledged: Bool?
        fixture.interactor.acknowledgeSubmittedTransfer(hash: "0x", recoveredIdentity: nil) { acknowledged = $0 }
        XCTAssertEqual(acknowledged, false, "Only plain transfers have a submission to acknowledge")
    }

    func testNonEquilibriumChainDoesNotFetchTotalBalance() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.interactor.fetchEquilibriumTotalBalance(chainAsset: fixture.chainAsset, amount: 1)
        CovHSendWait.until(timeout: 0.2) { false }
        XCTAssertTrue(fixture.output.eqBalances.isEmpty)
    }

    func testSolanaAttemptOwnsTheTransferAndCanBeCancelled() throws {
        let sol = try CovHSendFixtures.solanaToken()
        let authority = SelectedWalletAuthority()
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: sol, authority: authority)
        XCTAssertTrue(fixture.interactor.isSendSelectionCurrent)
        fixture.service.submitResult = .success("sol-signature")
        fixture.interactor.submitExtrinsic()
        CovHSendWait.until { fixture.output.transfers.count == 1 }
        XCTAssertEqual(fixture.output.transfers.first?.hash, "sol-signature")
        XCTAssertNotNil(fixture.interactor.transferTask)

        fixture.service.retryResult = .success("sol-retry")
        fixture.interactor.retryUnresolvedTransfer(hash: "sol-signature")
        CovHSendWait.until { fixture.output.transfers.count == 2 }
        XCTAssertEqual(fixture.output.transfers.last?.hash, "sol-retry")

        fixture.interactor.cancelSendAttempt()
        authority.publish(AccountGenerator.generateMetaAccount())
        XCTAssertFalse(fixture.interactor.isSendSelectionCurrent)
        fixture.interactor.submitExtrinsic()
        CovHSendWait.until(timeout: 0.3) { false }
        XCTAssertEqual(fixture.output.transfers.count, 2, "A stale selection never starts a transfer")
    }

    func testCancelOffSolanaIsANoOp() throws {
        let fixture = CovHSendConfirmInteractorFixture(chainAsset: try CovHSendFixtures.bitcoin())
        fixture.interactor.cancelSendAttempt()
        XCTAssertTrue(fixture.interactor.isSendSelectionCurrent)
        XCTAssertNil(fixture.interactor.transferTask)
    }
}

final class CovHSendConfirmInteractorFixture {
    let chainAsset: ChainAsset
    let wallet = AccountGenerator.generateMetaAccount()
    let output = CovHSendConfirmOutputSpy()
    let adapter = CovHSendAccountInfoAdapter()
    let remote = CovHSendRemoteService()
    let service = CovHSendTransferService()
    var prepareError: Error?
    var prepared: [ChainAssetId] = []
    let interactor: WalletSendConfirmInteractor

    init(chainAsset: ChainAsset, call: SendConfirmTransferCall? = nil, authority: SelectedWalletAuthority = SelectedWalletAuthority()) {
        self.chainAsset = chainAsset
        let wallet = wallet
        authority.publish(wallet)
        let transfer = Transfer(chainAsset: chainAsset, amount: 1000, receiver: "receiver", tip: nil, appId: nil)
        var prepareHook: ((ChainAsset) throws -> TransferServiceProtocol)?
        interactor = WalletSendConfirmInteractor(
            selectedMetaAccount: wallet,
            chainAsset: chainAsset,
            call: call ?? .transfer(transfer),
            accountInfoSubscriptionAdapter: adapter,
            dependencyContainer: SendDepencyContainer(wallet: wallet, operationManager: OperationManager()),
            wallet: wallet,
            accountInfoRemoteService: remote,
            prepareTransferService: { asset in try prepareHook?(asset) ?? CovHSendTransferService() },
            selection: authority.capture(for: wallet)
        )
        prepareHook = { [weak self] asset in
            guard let self else { throw CovHSendError.failed }
            if let error = self.prepareError { throw error }
            DispatchQueue.main.async { self.prepared.append(asset.chainAssetId) }
            return self.service
        }
        interactor.presenter = output
    }
}

final class CovHSendConfirmOutputSpy: WalletSendConfirmInteractorOutputProtocol {
    struct CovHSendAccountInfoDelivery {
        let asset: ChainAsset
        let isSuccess: Bool
    }

    struct CovHSendFeeDelivery {
        let value: BigUInt?
        let error: Error?
    }

    struct CovHSendTransferDelivery {
        let hash: String?
    }

    var accountInfos: [CovHSendAccountInfoDelivery] = []
    var minimumBalances: [BigUInt] = []
    var fees: [CovHSendFeeDelivery] = []
    var eqBalances: [Decimal] = []
    var transfers: [CovHSendTransferDelivery] = []
    var feeRates: [Double] = []
    var deposits: [BigUInt] = []

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        if case .success = result {
            accountInfos.append(CovHSendAccountInfoDelivery(asset: chainAsset, isSuccess: true))
        } else {
            accountInfos.append(CovHSendAccountInfoDelivery(asset: chainAsset, isSuccess: false))
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        if case let .success(value) = result { minimumBalances.append(value) }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(info):
            fees.append(CovHSendFeeDelivery(value: info.inclusionFee.baseFee, error: nil))
        case let .failure(error):
            fees.append(CovHSendFeeDelivery(value: nil, error: error))
        }
    }

    func didReceive(eqTotalBalance: Decimal) { eqBalances.append(eqTotalBalance) }

    func didTransfer(result: Result<String, Error>) {
        transfers.append(CovHSendTransferDelivery(hash: try? result.get()))
    }

    func didReceiveFeeRate(satPerVbyte: Double) { feeRates.append(satPerVbyte) }
    func didReceiveAccountCreationDeposit(_ deposit: BigUInt) { deposits.append(deposit) }
}
