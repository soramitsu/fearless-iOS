import BigInt
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovFPolkaswapServicesTests: XCTestCase {
    func testBestQuoteSelectsLargestNumericAmountAcrossDexes() async throws {
        let fixture = CovFQuoteFixture()
        fixture.engine.replies = [["amount": "90", "rewards": []], ["amount": "700", "rewards": ["bonus"]], ["amount": "invalid", "rewards": []]]
        let result = try await fixture.fetch()
        XCTAssertEqual(result?.amount, "700")
        XCTAssertEqual(result?.rewards, ["bonus"])
        XCTAssertEqual(fixture.engine.methods, Array(repeating: RPCMethod.recalculateSwapValues, count: 3))
        for value in fixture.engine.parameters {
            let params = try XCTUnwrap(value as? [Any])
            XCTAssertEqual(params[1] as? String, "1")
            XCTAssertEqual(params[2] as? String, "2")
            XCTAssertEqual(params[3] as? String, "100")
            XCTAssertEqual(params[4] as? String, "WithDesiredInput")
            XCTAssertEqual((params[5] as? [String])?.count, 0)
        }
    }

    func testQuoteErrorsProduceNilAndDoNotEscapeTaskGroup() async throws {
        let fixture = CovFQuoteFixture()
        fixture.engine.failure = NSError(domain: "quote", code: 5)
        let value = try await fixture.fetch()
        XCTAssertNil(value)
        XCTAssertEqual(fixture.engine.methods.count, 3)
    }

    func testMissingSettingsAndRepositoryFailureAreReported() async {
        for repositoryError in [false, true] {
            let fixture = CovFQuoteFixture()
            fixture.repository.items = []
            if repositoryError { fixture.repository.failure = NSError(domain: "settings", code: 6) }
            do { _ = try await fixture.fetch(); XCTFail("Expected settings error") }
            catch {
                if repositoryError { XCTAssertEqual((error as NSError).domain, "settings") }
                else { XCTAssertTrue(error is fearless.ConvenienceError) }
            }
            XCTAssertTrue(fixture.engine.methods.isEmpty)
        }
    }

    func testNoDexesAndMissingCurrencyIdProduceNoQuoteRequests() async throws {
        let empty = CovFQuoteFixture(dexes: [])
        let noDexResult = try await empty.fetch()
        XCTAssertNil(noDexResult)
        XCTAssertTrue(empty.engine.methods.isEmpty)
        let missing = CovFQuoteFixture()
        let noCurrencyResult = try await missing.fetch(missingCurrency: true)
        XCTAssertNil(noCurrencyResult)
        XCTAssertTrue(missing.engine.methods.isEmpty)
    }

    func testPoolSubscriptionsEncodeExpectedKeysAndReleaseAllSubscriptions() throws {
        let engine = CovFQueryEngine()
        let service = PolkaswapRemoteSubscriptionService(connection: engine, logger: Logger.shared)
        let dex = PolkaswapDex(name: "DEX", code: 0, assetId: "0x01")
        for type in [LiquiditySourceType.xyk, .tbc, .smart] {
            service.subscribsToPools(for: "0x01", toAssetId: "0x02", liquiditySourceType: type, availablePolkaswapDex: [dex]) { _ in }
        }
        let factory = StorageKeyFactory()
        let xyk = try factory.createStorageKey(moduleName: fearless.StorageCodingPath.polkaswapXykPool.moduleName,
                                                storageName: fearless.StorageCodingPath.polkaswapXykPool.itemName,
                                                keys: [Data([1]), Data([2])], hashers: [.blake128Concat, .blake128Concat]).toHex(includePrefix: true)
        let tbc = try [Data([1]), Data([2])].map {
            try factory.createStorageKey(moduleName: fearless.StorageCodingPath.polkaswapTbcPool.moduleName,
                                         storageName: fearless.StorageCodingPath.polkaswapTbcPool.itemName, key: $0, hasher: .twox64Concat).toHex(includePrefix: true)
        }
        XCTAssertEqual(engine.subscriptionParameters.flatMap { $0.flatMap { $0 } }, [xyk] + tbc + [xyk] + tbc)
        service.unsubscribe()
        XCTAssertEqual(engine.unsubscribed, Array(1 ... 6).map(UInt16.init))
        service.unsubscribe()
        XCTAssertEqual(engine.unsubscribed.count, 6)
    }

    func testBlockSubscriptionForwardsUpdatesAndHandlesInvalidPoolKeys() throws {
        let engine = CovFQueryEngine()
        let service = PolkaswapRemoteSubscriptionService(connection: engine, logger: Logger.shared)
        var blocks = 0
        var receivedBlock: String?
        service.subscribeToBlocks { update in
            blocks += 1
            receivedBlock = update.params.result.blockHash
        }
        XCTAssertEqual(engine.subscriptionParameters.first?.first, [try StorageKeyFactory().key(from: .blockNumber).toHex(includePrefix: true)])
        let update: [String: Any] = [
            "jsonrpc": "2.0", "method": RPCMethod.storageSubscribe,
            "params": ["subscription": "id", "result": ["block": "0x0102", "changes": [["0x01", "0x02"]]]]
        ]
        try engine.update?(JSONSerialization.data(withJSONObject: update))
        XCTAssertEqual(blocks, 1)
        XCTAssertEqual(receivedBlock, "0x0102")
        engine.fail?(NSError(domain: "subscription", code: 1), false)
        service.subscribsToPools(for: "invalid", toAssetId: "0x02", liquiditySourceType: .xyk,
                                availablePolkaswapDex: [PolkaswapDex(name: "DEX", code: 0, assetId: "0x01")]) { _ in XCTFail("No update expected") }
        XCTAssertEqual(engine.subscriptionParameters.count, 1)
        engine.subscriptionError = NSError(domain: "subscribe", code: 2)
        service.subscribeToBlocks { _ in XCTFail("No update expected") }
        service.unsubscribe()
        XCTAssertEqual(engine.unsubscribed, [1])
    }
}

private final class CovFQuoteFixture {
    let engine = CovFQueryEngine()
    let repository: CovFRepository<PolkaswapRemoteSettings>
    let manager = CovFCompletionAwareManager()
    let registry = CovFRegistry()
    init(dexes: [UInt32] = [0, 1, 2]) {
        repository = CovFRepository([PolkaswapRemoteSettings(version: "1", availableDexIds: dexes.map {
            PolkaswapDex(name: "Dex \($0)", code: $0, assetId: "1")
        }, availableSources: [.smart], forceSmartIds: [], xstusdId: "3")])
        registry.connection = engine
    }

    func fetch(missingCurrency: Bool = false) async throws -> SwapValues? {
        let runner = Task {
            while !Task.isCancelled {
                manager.runReady()
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
        }
        defer { runner.cancel() }
        let first = CovFFixtures.asset()
        let secondModel = AssetModel(id: "2", name: "Token", symbol: "T", precision: 2, currencyId: missingCurrency ? nil : "2",
                                     isUtility: false, isNative: false)
        let second = ChainAsset(chain: first.chain, asset: secondModel)
        let factory = PolkaswapOperationFactory(storageRequestFactory: CovFStorageRequests(), chainRegistry: registry, chainId: first.chain.chainId)
        let service = PolkaswapServiceImpl(polkaswapOperationFactory: factory, settingsRepository: AnyDataProviderRepository(repository),
                                          operationManager: manager)
        return try await service.fetchQuotes(amount: 100, fromChainAsset: first, toChainAsset: second)
    }
}

private final class CovFCompletionAwareManager: OperationManagerProtocol {
    private let lock = NSLock()
    private var pending: [Operation] = []
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    func enqueue(operations: [Operation], in _: OperationMode) {
        lock.lock()
        pending.append(contentsOf: operations)
        lock.unlock()
    }

    func runReady() {
        lock.lock()
        let ready = pending.filter { $0.completionBlock != nil }
        pending.removeAll { $0.completionBlock != nil }
        lock.unlock()
        queue.addOperations(ready, waitUntilFinished: false)
    }
}
