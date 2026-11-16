import Foundation
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest

@testable import fearless

final class CovDSettingsRepository: DataProviderRepositoryProtocol {
    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[PolkaswapRemoteSettings]> {
        ClosureOperation { [] }
    }
    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<PolkaswapRemoteSettings?> {
        ClosureOperation { nil }
    }
    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[PolkaswapRemoteSettings]> { ClosureOperation { [] } }
    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[PolkaswapRemoteSettings]> {
        ClosureOperation { [] }
    }
    func saveOperation(
        _: @escaping () throws -> [PolkaswapRemoteSettings], _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> { ClosureOperation {} }
    func saveBatchOperation(
        _: @escaping () throws -> [PolkaswapRemoteSettings], _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> { ClosureOperation {} }
    func replaceOperation(_: @escaping () throws -> [PolkaswapRemoteSettings]) -> BaseOperation<Void> { ClosureOperation {} }
    func fetchCountOperation() -> BaseOperation<Int> { ClosureOperation { 0 } }
    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation {} }
}

final class CovDQuoteOperationFactory: PolkaswapOperationFactoryProtocol {
    var failSecondDex = false
    var requests: [UInt32] = []
    var timeouts: [TimeInterval] = []

    func createIsPathAvailableOperation(dexId _: UInt32, from _: String, to _: String) -> JSONRPCOperation<[PolkaswapJSON], Bool> {
        JSONRPCOperation(engine: MockConnection(), method: "unused", parameters: [])
    }
    func createGetAvailableMarketAlgorithmsOperation(dexId _: UInt32, from _: String, to _: String) -> JSONRPCOperation<[PolkaswapJSON], [String]> {
        JSONRPCOperation(engine: MockConnection(), method: "unused", parameters: [])
    }
    func createPolkaswapQuoteOperation(dexId _: UInt32, params _: PolkaswapQuoteParams) -> JSONRPCOperation<[PolkaswapJSON], SwapValues> {
        JSONRPCOperation(engine: MockConnection(), method: "unused", parameters: [])
    }
    func createIsPathAvalableAndMarketCompoundOperation(
        dexId: UInt32, from _: String, to _: String
    ) -> CompoundOperationWrapper<(isAvailable: Bool, markets: [String])> {
        let fail = failSecondDex && dexId == 1
        let operation = ClosureOperation<(isAvailable: Bool, markets: [String])> {
            if fail { throw CovDTestError.offline }
            return (true, ["XYKPool"])
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }
    func createDexInfosOperation() -> CompoundOperationWrapper<[UInt32]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [0, 1] })
    }
    func fetchQuote(dexId: UInt32, params _: PolkaswapQuoteParams, timeout: TimeInterval, completion: @escaping (Result<SwapValues, Error>) -> Void) {
        requests.append(dexId)
        timeouts.append(timeout)
        if failSecondDex && dexId == 1 {
            completion(.failure(CovDTestError.offline))
        } else {
            completion(.success(SwapValues(dexId: nil, amount: "200", rewards: [])))
        }
    }
}

final class CovDBlockSubscriptionSpy: PolkaswapRemoteSubscriptionServiceProtocol {
    var updates: [(JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void] = []
    var unsubscribes = 0
    func subscribsToPools(
        for _: AssetModel.Id, toAssetId _: AssetModel.Id, liquiditySourceType _: LiquiditySourceType,
        availablePolkaswapDex _: [PolkaswapDex], updateClosure _: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void
    ) {}
    func subscribeToBlocks(updateClosure: @escaping (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void) { updates.append(updateClosure) }
    func unsubscribe() { unsubscribes += 1 }
}

final class CovDFeeProxySpy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    var identifiers: [String] = []
    var builder: ExtrinsicBuilderClosure?
    func estimateFee(using _: ExtrinsicServiceProtocol, reuseIdentifier: ExtrinsicFeeId, setupBy closure: @escaping ExtrinsicBuilderClosure) {
        identifiers.append(reuseIdentifier)
        builder = closure
        delegate?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 23)), for: reuseIdentifier)
    }
}

final class CovDQuoteOutputSpy: PolkaswapAdjustmentInteractorOutput {
    var errors: [Error] = []
    var accounts: [ChainAssetId] = []
    var feeCount = 0
    var dexes: [[PolkaswapDexInfo]] = []
    var quotes: [[SwapValues]] = []
    var quoteErrors: [[Error]] = []
    var params: [PolkaswapQuoteParams] = []
    var settings: [PolkaswapRemoteSettings?] = []
    var updates = 0
    var disclaimer: [Bool] = []
    func didReceive(error: Error) { errors.append(error) }
    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) { accounts.append(chainAsset.chainAssetId) }
    func didReceiveFee(result _: Result<RuntimeDispatchInfo, Error>) { feeCount += 1 }
    func didReceiveDex(infos: [PolkaswapDexInfo], fromAssetId _: String, toAssetId _: String) { dexes.append(infos) }
    func didReceiveSwapValues(_ valuesMap: [SwapValues], params: PolkaswapQuoteParams, errors: [Error]) {
        quotes.append(valuesMap)
        self.params.append(params)
        quoteErrors.append(errors)
    }
    func didReceiveSettings(settings: PolkaswapRemoteSettings?) { self.settings.append(settings) }
    func updateQuotes() { updates += 1 }
    func didReceiveDisclaimer(isRead: Bool) { disclaimer.append(isRead) }
}

final class CovDAdjustmentHarness {
    let factory = CovDQuoteOperationFactory()
    let subscription = CovDBlockSubscriptionSpy()
    let adapter = CovDAccountSubscriptionSpy()
    let fee = CovDFeeProxySpy()
    let output = CovDQuoteOutputSpy()
    let storage = InMemorySettingsManager()
    let chain = CovDSwapFixtures.chain()
    let interactor: PolkaswapAdjustmentInteractor
    let settings: PolkaswapRemoteSettings

    init() throws {
        settings = PolkaswapRemoteSettings(
            version: "covd", availableDexIds: [
                PolkaswapDex(name: "XOR", code: 0, assetId: CovDFixtures.xorAssetId),
                PolkaswapDex(name: "VAL", code: 1, assetId: CovDFixtures.valAssetId)
            ], availableSources: [.smart, .xyk], forceSmartIds: [], xstusdId: "xst"
        )
        interactor = PolkaswapAdjustmentInteractor(
            xorChainAsset: try XCTUnwrap(chain.utilityChainAssets().first), subscriptionService: subscription,
            accountInfoSubscriptionAdapter: adapter, feeProxy: fee,
            settingsRepository: AnyDataProviderRepository(CovDSettingsRepository()),
            extrinsicService: ExtrinsicServiceStub.dummy(), operationFactory: factory, operationManager: OperationManager(),
            userDefaultsStorage: storage, callFactory: SubstrateCallFactoryDefault(runtimeService: CovDRuntimeProviderStub()),
            eventCenter: CovDEventCenterSpy(), fallbackSettings: settings
        )
        interactor.setup(with: output)
    }

    var quote: PolkaswapQuoteParams {
        PolkaswapQuoteParams(
            fromAssetId: CovDFixtures.xorAssetId, toAssetId: CovDSwapFixtures.tokenId, amount: "100",
            swapVariant: .desiredInput, liquiditySources: [], filterMode: .disabled
        )
    }
}

final class CovDAdjustmentInteractorTests: XCTestCase {
    func testSettingsAccountPairAndQuoteResultsStayBoundToTheRequest() throws {
        let fixture = try CovDAdjustmentHarness()
        XCTAssertEqual(fixture.output.settings.first ?? nil, fixture.settings)
        XCTAssertEqual(fixture.output.disclaimer, [false])
        PolkaswapDisclaimerPolicy.acceptCurrentVersion(in: fixture.storage)
        fixture.interactor.fetchDisclaimerVisible()
        XCTAssertEqual(fixture.output.disclaimer, [false, true])
        let xor = try XCTUnwrap(fixture.chain.utilityChainAssets().first)
        let token = try XCTUnwrap(fixture.chain.chainAssets.first { $0.asset.id == "tkn" })
        fixture.interactor.didReceive(xor, token)
        XCTAssertTrue(CovDFixtures.spin { fixture.output.dexes.count == 1 })
        XCTAssertEqual(Set(fixture.output.dexes[0].map(\.dexId)), [0, 1])
        XCTAssertTrue(fixture.output.dexes[0].allSatisfy(\.pathIsAvailable))
        XCTAssertEqual(fixture.adapter.subscribed.count, 3)
        fixture.adapter.handler?.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: token)
        XCTAssertEqual(fixture.output.accounts, [token.chainAssetId])
        let params = fixture.quote
        fixture.interactor.fetchQuotes(with: params)
        XCTAssertTrue(CovDFixtures.spin { fixture.output.quotes.count == 1 })
        XCTAssertEqual(Set(fixture.output.quotes[0].compactMap(\.dexId)), [0, 1])
        XCTAssertEqual(fixture.output.quotes[0].map(\.amount), ["200", "200"])
        XCTAssertEqual(fixture.output.params, [params])
        XCTAssertTrue(fixture.output.quoteErrors[0].isEmpty)
        XCTAssertEqual(fixture.factory.timeouts, [PolkaswapAdjustmentInteractor.quoteTimeout, PolkaswapAdjustmentInteractor.quoteTimeout])
    }

    func testPairAndQuoteFailuresRetainSuccessfulDexResults() throws {
        let fixture = try CovDAdjustmentHarness()
        fixture.factory.failSecondDex = true
        let params = CovDSwapFixtures.params(chain: fixture.chain)
        fixture.interactor.didReceive(params.swapFromChainAsset, params.swapToChainAsset)
        fixture.interactor.fetchQuotes(with: fixture.quote)
        XCTAssertTrue(CovDFixtures.spin { fixture.output.dexes.count == 1 && fixture.output.quotes.count == 1 })
        XCTAssertEqual(fixture.output.dexes[0].map(\.dexId), [0])
        XCTAssertEqual(fixture.output.errors.first as? CovDTestError, .offline)
        XCTAssertEqual(fixture.output.quotes[0].compactMap(\.dexId), [0])
        XCTAssertEqual(fixture.output.quoteErrors[0].first as? CovDTestError, .offline)
        fixture.interactor.didReceive(nil, nil)
        XCTAssertEqual(fixture.adapter.subscribed.count, 4)
        let empty = PolkaswapRemoteSettings(version: "empty", availableDexIds: [], availableSources: [], forceSmartIds: [], xstusdId: "")
        fixture.interactor.processPolkaswapSettingsDidUpdate(event: PolkaswapSettingsDidUpdate(settings: empty))
        fixture.interactor.fetchQuotes(with: fixture.quote)
        XCTAssertTrue(CovDFixtures.spin { fixture.output.quotes.count == 2 })
        XCTAssertTrue(fixture.output.quotes[1].isEmpty)
        XCTAssertEqual(fixture.output.settings.last ?? nil, empty)
    }

    func testReplacedBlockSubscriptionsCannotRefreshQuotesAndFeeBuilderUsesExactAssets() throws {
        let fixture = try CovDAdjustmentHarness()
        let data = Data(#"{"jsonrpc":"2.0","method":"state_storage","params":{"subscription":"sub","result":{"block":"0x00","changes":[]}}}"#.utf8)
        let update = try JSONDecoder().decode(JSONRPCSubscriptionUpdate<StorageUpdate>.self, from: data)
        fixture.interactor.subscribeOnBlocks()
        fixture.subscription.updates[0](update)
        fixture.subscription.updates[0](update)
        XCTAssertTrue(CovDFixtures.spin { fixture.output.updates == 1 })
        fixture.interactor.subscribeOnBlocks()
        fixture.subscription.updates[0](update)
        fixture.subscription.updates[1](update)
        fixture.subscription.updates[1](update)
        XCTAssertTrue(CovDFixtures.spin { fixture.output.updates == 2 })
        XCTAssertEqual(fixture.subscription.unsubscribes, 2)
        fixture.interactor.estimateFee(
            dexId: "0", fromAssetId: CovDFixtures.xorAssetId, toAssetId: CovDSwapFixtures.tokenId,
            swapVariant: .desiredInput, swapAmount: SwapAmount(type: .desiredInput, desired: 100, slip: 99), filter: .disabled, liquiditySourceType: .smart
        )
        XCTAssertEqual(fixture.output.feeCount, 1)
        let builder = CovDExtrinsicBuilderSpy()
        _ = try XCTUnwrap(fixture.fee.builder)(builder)
        XCTAssertEqual(builder.calls.count, 1)
        XCTAssertEqual(builder.calls.first?.module, "LiquidityProxy")
        XCTAssertEqual(builder.calls.first?.call, "swap")
        XCTAssertTrue(fixture.fee.identifiers.first?.contains(CovDSwapFixtures.tokenId) == true)
    }

    func testOperationBatchIncludesCancelledAndFailedWork() {
        let batch = PolkaswapOperationBatch<Int>(expectedCount: 3)
        let completed = expectation(description: "batch completion")
        batch.notify(on: .main) { values, errors in
            XCTAssertEqual(values, [7])
            XCTAssertEqual(errors.count, 2)
            XCTAssertTrue(errors.contains { $0 is BaseOperationError })
            completed.fulfill()
        }
        batch.complete(.success(7))
        batch.complete(.failure(CovDTestError.offline))
        batch.complete(nil)
        wait(for: [completed], timeout: 3)
    }
}
