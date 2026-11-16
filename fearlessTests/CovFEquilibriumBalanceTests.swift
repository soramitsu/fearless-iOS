import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovFEquilibriumBalanceTests: XCTestCase {
    func testAllBalancesAreRequiredBeforeReturningPricedTotal() throws {
        let fixture = CovFEquilibriumFixture()
        let service = fixture.service()
        service.oraclePricesMap = [1: 200, 2: 300, 99: 400]
        var totals: [BigUInt] = []
        service.fetchTotalBalance { totals.append($0) }
        XCTAssertEqual(fixture.adapter.assets.count, 2)
        XCTAssertEqual(fixture.adapter.accounts, [fixture.account, fixture.account])
        service.handleAccountInfo(result: .success(AccountInfo(ethBalance: 500)), accountId: fixture.account, chainAsset: fixture.assets[0])
        XCTAssertTrue(totals.isEmpty)
        service.handleAccountInfo(result: .success(AccountInfo(ethBalance: 400)), accountId: fixture.account, chainAsset: fixture.assets[1])
        XCTAssertEqual(totals, [2200])
        XCTAssertEqual(service.totalBalanceAfterTransfer(chainAsset: fixture.assets[0], amount: 2), 18)
        XCTAssertEqual(service.totalBalanceAfterTransfer(chainAsset: fixture.assets[1], amount: 3), 13)
        service.handleAccountInfo(result: .success(AccountInfo(ethBalance: 600)), accountId: fixture.account, chainAsset: fixture.assets[0])
        XCTAssertEqual(totals, [2200, 2400])
    }

    func testEmptyPricesAndMissingCachedTotalDoNotProduceTransferEstimates() {
        let fixture = CovFEquilibriumFixture()
        let service = fixture.service()
        XCTAssertNil(service.totalBalanceAfterTransfer(chainAsset: fixture.assets[0], amount: 1))
        service.oraclePricesMap = [1: 200]
        XCTAssertNil(service.totalBalanceAfterTransfer(chainAsset: fixture.assets[0], amount: 1))
        var totals: [BigUInt] = []
        service.fetchTotalBalance { totals.append($0) }
        service.oraclePricesMap = [:]
        fixture.assets.forEach { service.handleAccountInfo(result: .success(AccountInfo(ethBalance: 500)), accountId: fixture.account, chainAsset: $0) }
        XCTAssertTrue(totals.isEmpty)
    }

    func testUnpricedAssetContributesZeroAndFailurePreservesLastBalance() {
        let fixture = CovFEquilibriumFixture()
        let service = fixture.service()
        service.oraclePricesMap = [1: 200]
        var totals: [BigUInt] = []
        service.fetchTotalBalance { totals.append($0) }
        for asset in fixture.assets {
            service.handleAccountInfo(result: .success(AccountInfo(ethBalance: 500)), accountId: fixture.account, chainAsset: asset)
        }
        XCTAssertEqual(totals, [1000])
        service.handleAccountInfo(result: .failure(NSError(domain: "balance", code: 1)), accountId: fixture.account, chainAsset: fixture.assets[0])
        XCTAssertEqual(totals, [1000])
        XCTAssertEqual(service.accountInfos[fixture.assets[0].uniqueKey(accountId: fixture.account)]??.data.free, 500)
        XCTAssertEqual(service.totalBalanceAfterTransfer(chainAsset: fixture.assets[1], amount: 100), 10)
        let invalid = AssetModel(id: "bad", name: "Bad", symbol: "BAD", precision: 2, currencyId: "invalid", isUtility: false, isNative: false)
        XCTAssertNil(service.totalBalanceAfterTransfer(chainAsset: ChainAsset(chain: fixture.assets[0].chain, asset: invalid), amount: 1))
    }

    func testOracleOperationDecodesStorageKeysSkipsNullAndMalformedEntriesAndCalculatesTotal() throws {
        let fixture = CovFEquilibriumFixture()
        let runtime = try CovFOracleRuntime.make()
        let requests = CovFStorageRequests()
        for (key, price) in [(UInt64(1), 200), (2, 300)] {
            let encoder = runtime.factory.createEncoder()
            try encoder.append(json: CovFFixtures.json(String(key)), type: "u64")
            try requests.put(.eqOraclePricePoint, key: Data(repeating: 9, count: 32) + encoder.encode(), value: oracle(price))
        }
        try requests.put(.eqOraclePricePoint, key: Data([1]), value: oracle(900))
        try requests.put(.eqOraclePricePoint, value: nil)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.isSuspended = true
        let service = fixture.service(runtime: runtime, requests: requests, queue: queue)
        for asset in fixture.assets { service.accountInfos[asset.uniqueKey(accountId: fixture.account)] = AccountInfo(ethBalance: 500) }
        let done = expectation(description: "both oracle reads")
        done.expectedFulfillmentCount = 2
        service.fetchTotalBalance { total in XCTAssertEqual(total, 2500); done.fulfill() }
        queue.isSuspended = false
        wait(for: [done], timeout: 10)
        XCTAssertEqual(service.oraclePricesMap, [1: 200, 2: 300])
        XCTAssertEqual(requests.requestedPaths.count, 2)
    }

    func testStorageKeyExtractorPropagatesMissingMetadataAndCoderFailures() async throws {
        let runtime = try CovFOracleRuntime.make()
        let extractor = StorageKeyDataExtractor(runtimeService: runtime)
        do {
            let _: String = try await extractor.extractKey(storageKey: Data(repeating: 0, count: 8), storagePath: .activeEra, type: .u64)
            XCTFail("Expected absent metadata")
        } catch { XCTAssertTrue(error is fearless.ConvenienceError) }
        runtime.failure = NSError(domain: "oracle-runtime", code: 4)
        do {
            let _: String = try await extractor.extractKey(storageKey: Data(repeating: 0, count: 8), storagePath: .eqOraclePricePoint, type: .u64)
            XCTFail("Expected runtime error")
        } catch { XCTAssertEqual((error as NSError).domain, "oracle-runtime") }
    }

    private func oracle(_ price: Int) -> [String: Any] {
        ["blockNumber": "1", "timestamp": "2", "lastFinRecalcTimestamp": "3", "price": String(price), "dataPoints": []]
    }
}

private final class CovFEquilibriumFixture {
    let wallet = AccountGenerator.generateMetaAccount()
    let adapter = CovFBalanceAdapter()
    let assets: [ChainAsset]
    var account: Data { wallet.substrateAccountId ?? Data() }
    init() {
        let models: [AssetModel] = [1, 2].map { (id: Int) -> AssetModel in
            let utility: Bool = id == 1
            let identifier = String(id)
            return AssetModel(id: identifier, name: "Token " + identifier, symbol: "T" + identifier, precision: 2,
                              currencyId: identifier, isUtility: utility, isNative: utility, type: SubstrateAssetType.equilibrium)
        }
        let chain = ChainModel(rank: nil, disabled: false, chainId: String(repeating: "ab", count: 32), parentId: nil,
                               paraId: nil, name: "Eq", assets: Set(models), xcm: nil, nodes: [], addressPrefix: 42,
                               icon: nil, options: nil, iosMinAppVersion: nil, identityChain: nil)
        assets = models.map { ChainAsset(chain: chain, asset: $0) }
    }

    func service(runtime: CovFRuntime? = nil, requests: CovFStorageRequests = CovFStorageRequests(), queue: OperationQueue = OperationQueue())
        -> EquilibriumTotalBalanceService {
        EquilibriumTotalBalanceService(wallet: wallet, accountInfoSubscriptionAdapter: adapter, equilibriumChainAsset: assets[0],
                                       storageRequestFactory: requests, operationManager: OperationManager(operationQueue: queue),
                                       runtimeService: runtime, engine: runtime == nil ? nil : MockConnection(), logger: Logger.shared)
    }
}

private final class CovFBalanceAdapter: AccountInfoSubscriptionAdapterProtocol {
    var assets: [ChainAsset] = []
    var accounts: [Data] = []
    func subscribe(chainAsset: ChainAsset, accountId: AccountId, handler _: AccountInfoSubscriptionAdapterHandler?,
                   deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool) {
        assets.append(chainAsset)
        accounts.append(accountId)
    }

    func subscribe(chainsAssets _: [ChainAsset], handler _: AccountInfoSubscriptionAdapterHandler?,
                   deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool) {}
    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}
}

private enum CovFOracleRuntime {
    static func make() throws -> CovFRuntime {
        let path = fearless.StorageCodingPath.eqOraclePricePoint
        let entry = RuntimeMetadataV1.StorageEntryMetadata(
            name: path.itemName, modifier: .optional, type: .map(MapEntry(hasher: .twox64Concat, key: "u64", value: "u64", unused: false)),
            defaultValue: Data(), documentation: []
        )
        let module = RuntimeMetadataV1.ModuleMetadata(name: path.moduleName, storage: .init(prefix: path.moduleName, entries: [entry]),
                                                     calls: nil, events: nil, constants: [], errors: [], index: 0)
        let metadata = try RuntimeMetadata.v1(modules: [module], extrinsic: .init(version: 4, signedExtensions: []))
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(Data(#"{"types":{}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:])
        return CovFRuntime(factory: TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata))
    }
}
