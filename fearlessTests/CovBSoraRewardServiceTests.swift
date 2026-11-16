import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFStorageQueryKit
import SSFUtils
@testable import fearless

/// Answers prefix reads with JSON keyed by the request type name.
final class CovBSoPerformer: SSFStorageQueryKit.StorageRequestPerformer {
    private let lock = NSLock()
    var responses: [String: Any] = [:]
    var failure: Error?
    private(set) var prefixRequests: [String] = []

    func performSingle<T: Decodable>(_: SSFStorageQueryKit.StorageRequest, chain _: ChainModel) async throws -> T? { nil }

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<T>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _ request: SSFStorageQueryKit.PrefixRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? {
        let name = String(describing: type(of: request))
        let json: Any? = lock.withLock {
            prefixRequests.append(name)
            return responses[name]
        }
        if let failure = failure { throw failure }
        guard let json = json else { return nil }
        return try JSONDecoder().decode([K: T].self, from: JSONSerialization.data(withJSONObject: json))
    }

    func perform(_: [any MixStorageRequest], chain _: ChainModel) async throws -> [MixStorageResponse] { [] }
}

final class CovBSoPolkaswap: PolkaswapOperationFactoryProtocol {
    var amounts: [UInt32: String] = [:]
    private(set) var quotedDexIds: [UInt32] = []
    private(set) var quoteParams: [PolkaswapQuoteParams] = []

    private static func failed<T: Decodable>(_ code: Int) -> JSONRPCOperation<[PolkaswapJSON], T> {
        let operation = JSONRPCOperation<[PolkaswapJSON], T>(engine: MockConnection(), method: "covb_failed")
        operation.result = .failure(CovBSkError(code: code))
        return operation
    }

    func createIsPathAvailableOperation(dexId _: UInt32, from _: String, to _: String) -> JSONRPCOperation<[PolkaswapJSON], Bool> {
        Self.failed(81)
    }

    func createGetAvailableMarketAlgorithmsOperation(
        dexId _: UInt32,
        from _: String,
        to _: String
    ) -> JSONRPCOperation<[PolkaswapJSON], [String]> {
        Self.failed(82)
    }

    func createIsPathAvalableAndMarketCompoundOperation(
        dexId _: UInt32,
        from _: String,
        to _: String
    ) -> CompoundOperationWrapper<(isAvailable: Bool, markets: [String])> {
        .createWithError(CovBSkError(code: 83))
    }

    func createPolkaswapQuoteOperation(dexId: UInt32, params: PolkaswapQuoteParams) -> JSONRPCOperation<[PolkaswapJSON], SwapValues> {
        quotedDexIds.append(dexId)
        quoteParams.append(params)
        guard let amount = amounts[dexId] else { return Self.failed(84) }
        let operation = JSONRPCOperation<[PolkaswapJSON], SwapValues>(engine: MockConnection(), method: "covb_quote")
        do {
            let data = try JSONSerialization.data(withJSONObject: ["amount": amount, "rewards": []])
            operation.result = .success(try JSONDecoder().decode(SwapValues.self, from: data))
        } catch {
            operation.result = .failure(error)
        }
        return operation
    }

    func fetchQuote(
        dexId _: UInt32,
        params _: PolkaswapQuoteParams,
        timeout _: TimeInterval,
        completion: @escaping (Result<SwapValues, Error>) -> Void
    ) {
        completion(.failure(CovBSkError(code: 85)))
    }

    func createDexInfosOperation() -> CompoundOperationWrapper<[UInt32]> {
        .createWithError(CovBSkError(code: 86))
    }
}

final class CovBSoAssets: ChainAssetFetchingProtocol {
    var result: Result<[ChainAsset], Error>
    private(set) var filters: [[ChainAssetsFetching.Filter]] = []

    init(result: Result<[ChainAsset], Error>) {
        self.result = result
    }

    func fetch(
        shouldUseCache _: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        self.filters.append(filters)
        completionBlock(result)
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        let result = result
        return ClosureOperation { try result.get() }
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        try result.get()
    }
}

struct CovBSoSettingsRepository: DataProviderRepositoryProtocol {
    typealias Model = PolkaswapRemoteSettings
    let settings: [PolkaswapRemoteSettings]

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { settings }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { settings.first }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { settings }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { settings }
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { settings.count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}

final class CovBSoServiceTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private static let xor = "0x0200000000000000000000000000000000000000000000000000000000000000"
    private static let val = "0x0200040000000000000000000000000000000000000000000000000000000000"

    private func token(_ symbol: String, currencyId: String) -> AssetModel {
        AssetModel(
            id: symbol, name: symbol, symbol: symbol, precision: 18, currencyId: currencyId,
            isUtility: symbol == "XOR", isNative: true, staking: symbol == "XOR" ? .relayChain : nil
        )
    }

    private func settings() throws -> PolkaswapRemoteSettings {
        let json: [String: Any] = [
            "version": "1",
            "availableDexIds": [["name": "XOR", "code": 0, "assetId": Self.xor], ["name": "XSTUSD", "code": 1, "assetId": Self.xor]],
            "availableSources": ["smart"],
            "forceSmartIds": [],
            "xstusdId": Self.xor
        ]
        return try JSONDecoder().decode(PolkaswapRemoteSettings.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func points(total: Int, _ individual: [(Data, Int)]) -> [String: Any] {
        ["total": String(total), "individual": individual.map { [$0.0.base64EncodedString(), String($0.1)] }]
    }

    func testRewardTokenQuoteAndPastErasBuildASoraEngine() throws {
        let staking = token("XOR", currencyId: Self.xor)
        let reward = token("VAL", currencyId: Self.val)
        let chain = ChainModel(
            rank: nil, disabled: false, chainId: "covb-sora", parentId: nil, paraId: nil, name: "SORA Mainnet",
            assets: [staking, reward], xcm: nil, nodes: [], addressPrefix: 69, icon: nil, iosMinAppVersion: nil, identityChain: nil
        )
        let stakingAsset = ChainAsset(chain: chain, asset: staking)
        let rewardAsset = ChainAsset(chain: chain, asset: reward)
        let registry = CovBSkRegistry()
        registry.register(chain.chainId, connection: MockConnection(), runtime: CovBSkRuntimeProvider(try StakingConstantRuntime()))
        let era = CovBSkEraService()
        era.info = EraStakersInfo(activeEra: 3, validators: [
            try Fx.validator(Fx.validatorA, total: 400, own: 400, commission: 100_000_000),
            try Fx.validator(Fx.validatorB, total: 700, own: 700, commission: 0)
        ])
        let polkaswap = CovBSoPolkaswap()
        // Only one DEX answers: the service collects concurrent quote answers without a lock (reported), so two
        // successful answers could lose one and make the asserted rate flaky.
        polkaswap.amounts = [1: "2000000000000000000"]
        let assets = CovBSoAssets(result: .success([stakingAsset, rewardAsset]))
        let performer = CovBSoPerformer()
        performer.responses = [
            "StakingErasTotalStakeRequest": ["1": "1000", "x": "5"],
            "StakingErasRewardPointsRequest": [
                "1": points(total: 100, [(Fx.validatorA, 60), (Fx.validatorB, 40)]),
                "2": points(total: 200, [(Fx.validatorA, 100), (Fx.validatorB, 100)]),
                "3": points(total: 999, [(Fx.validatorA, 999)])
            ],
            "StakingErasValidatorRewardRequest": ["1": "1000", "2": "2000", "3": "99999"]
        ]
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let service = SoraRewardCalculatorService(
            chainAsset: stakingAsset,
            assetPrecision: 18,
            eraValidatorsService: era,
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: registry,
            stakingDurationFactory: CovBRsDuration(),
            storageFacade: facade,
            polkaswapOperationFactory: polkaswap,
            chainAssetFetching: assets,
            settingsRepository: AnyDataProviderRepository(CovBSoSettingsRepository(settings: [try settings()])),
            storageRequestFactory: CovBSkStorage(),
            storageRequestPerformer: performer
        )

        let request = service.fetchCalculatorOperation()
        let done = XCTestExpectation(description: "sora calculator")
        request.completionBlock = { done.fulfill() }
        manager.enqueue(operations: [request], in: .transient)
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "request is waiting")], timeout: 0.5)
        service.setup()

        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 30), .completed)
        let engine = try XCTUnwrap(request.result).get()

        XCTAssertTrue(engine is SoraRewardCalculatorEngine)
        XCTAssertEqual(engine.rewardAssetRate, 2, "The answering DEX quote sets the VAL rate; the failed one is skipped")
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: false, period: .day), 3.6)
        XCTAssertEqual(Set(polkaswap.quotedDexIds), [0, 1])
        XCTAssertEqual(polkaswap.quoteParams.first?.fromAssetId, Self.xor)
        XCTAssertEqual(polkaswap.quoteParams.first?.toAssetId, Self.val)
        XCTAssertEqual(assets.filters.first, [.assetName("val"), .chainId(chain.chainId)])
        XCTAssertEqual(Set(performer.prefixRequests), [
            "StakingErasTotalStakeRequest", "StakingErasRewardPointsRequest", "StakingErasValidatorRewardRequest"
        ])
        XCTAssertEqual(era.setups, 1)
        service.throttle()
    }

    func testChainWithoutRewardAssetNeverQuotes() throws {
        let chain = Fx.chain(id: "covb-sora-relay", precision: 0)
        let assets = CovBSoAssets(result: .success([]))
        let polkaswap = CovBSoPolkaswap()
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let service = SoraRewardCalculatorService(
            chainAsset: try CovBRsSupport.chainAsset(chain),
            assetPrecision: 0,
            eraValidatorsService: CovBSkEraService(),
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: CovBSkRegistry(),
            stakingDurationFactory: CovBRsDuration(),
            storageFacade: facade,
            polkaswapOperationFactory: polkaswap,
            chainAssetFetching: assets,
            settingsRepository: AnyDataProviderRepository(CovBSoSettingsRepository(settings: [])),
            storageRequestFactory: CovBSkStorage(),
            storageRequestPerformer: CovBSoPerformer()
        )
        service.throttle()
        service.setup()
        XCTAssertTrue(assets.filters.isEmpty, "A relay chain has no reward asset to look up")
        XCTAssertTrue(polkaswap.quotedDexIds.isEmpty)
    }
}
