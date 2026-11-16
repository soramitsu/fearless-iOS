import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils
import XCTest
@testable import fearless

/// The SORA reward calculator quotes the reward token on every Polkaswap DEX and reads the past eras' rewards
/// before it can build an engine.
final class SoraRewardCalculatorServiceTests: XCTestCase {
    /// DEX k answers k + 1 VAL for one XOR. Every answer arrives on its own operation thread, and the service used
    /// to collect them under a barrier on a global queue, which serialises nothing, so answers could be lost.
    func testEveryConcurrentQuoteAnswerIsKept() throws {
        for _ in 0 ..< 3 {
            let fixture = try SoraRewardServiceFixture(dexCount: 64)

            let engine = try fixture.fetchEngine(setupAfterRequest: true)

            XCTAssertEqual(fixture.collectedQuoteCount, 64, "every DEX answer is kept")
            XCTAssertEqual(engine.rewardAssetRate, 64, "the best quote sets the reward token rate")
        }
    }
}

// MARK: - Fixture

final class SoraRewardServiceFixture {
    static let xor = "0x0200000000000000000000000000000000000000000000000000000000000000"
    static let val = "0x0200040000000000000000000000000000000000000000000000000000000000"
    static let validatorA = Data(repeating: 0xAA, count: 32)
    static let validatorB = Data(repeating: 0xBB, count: 32)

    let chain: ChainModel
    let stakingAsset: ChainAsset
    let polkaswap = SoraRewardServicePolkaswapStub()
    let performer = SoraRewardServiceStoragePerformer()
    let eraService = SoraRewardServiceEraStub()
    let registry = SoraRewardServiceRegistry()
    let manager = OperationManager()
    let service: SoraRewardCalculatorService

    init(dexCount: Int) throws {
        let staking = Self.token("XOR", currencyId: Self.xor)
        let reward = Self.token("VAL", currencyId: Self.val)
        chain = ChainModel(
            rank: nil, disabled: false, chainId: "sora-reward-service", parentId: nil, paraId: nil, name: "SORA Mainnet",
            assets: [staking, reward], xcm: nil, nodes: [], addressPrefix: 69, icon: nil, iosMinAppVersion: nil,
            identityChain: nil
        )
        stakingAsset = ChainAsset(chain: chain, asset: staking)
        let rewardAsset = ChainAsset(chain: chain, asset: reward)

        polkaswap.amounts = Dictionary(uniqueKeysWithValues: (0 ..< dexCount).map { dexId in
            (UInt32(dexId), String(BigUInt(dexId + 1) * BigUInt(10).power(18)))
        })
        eraService.info = EraStakersInfo(activeEra: 3, validators: [
            Self.validator(Self.validatorA, total: 400, commission: 100_000_000),
            Self.validator(Self.validatorB, total: 700, commission: 0)
        ])
        performer.responses = [
            "StakingErasTotalStakeRequest": ["1": "1000", "2": "1000"],
            "StakingErasRewardPointsRequest": [
                "1": Self.points(total: 100, [(Self.validatorA, 60), (Self.validatorB, 40)]),
                "2": Self.points(total: 200, [(Self.validatorA, 100), (Self.validatorB, 100)])
            ],
            "StakingErasValidatorRewardRequest": ["1": "1000", "2": "2000"]
        ]
        registry.runtime = try SoraRewardServiceRegistry.sharedRuntime()

        let facade = SubstrateStorageTestFacade()
        let settings = try Self.settings(dexCount: dexCount)
        service = SoraRewardCalculatorService(
            chainAsset: stakingAsset,
            assetPrecision: 18,
            eraValidatorsService: eraService,
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: registry,
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade,
            polkaswapOperationFactory: polkaswap,
            chainAssetFetching: SoraRewardServiceAssets(chainAssets: [stakingAsset, rewardAsset]),
            settingsRepository: AnyDataProviderRepository(SoraRewardServiceSettingsRepository(settings: [settings])),
            storageRequestFactory: StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: manager
            ),
            storageRequestPerformer: performer
        )
    }

    /// The number of quote answers the service collected, read from its private state.
    var collectedQuoteCount: Int? {
        (Mirror(reflecting: service).descendant("swapValues") as? [SwapValues])?.count
    }

    /// Asks for an engine and waits for it. With `setupAfterRequest` the request is made before the service starts,
    /// so it waits for the first data.
    func fetchEngine(setupAfterRequest: Bool, timeout: TimeInterval = 30) throws -> RewardCalculatorEngineProtocol {
        let operation = service.fetchCalculatorOperation()
        let done = XCTestExpectation(description: "the calculator request completes")
        operation.completionBlock = { done.fulfill() }
        manager.enqueue(operations: [operation], in: .transient)
        if setupAfterRequest {
            service.setup()
        }
        guard XCTWaiter.wait(for: [done], timeout: timeout) == .completed else {
            throw SoraRewardServiceFixtureError.requestNotAnswered
        }
        return try XCTUnwrap(operation.result).get()
    }

    static func token(_ symbol: String, currencyId: String) -> AssetModel {
        AssetModel(
            id: symbol, name: symbol, symbol: symbol, precision: 18, currencyId: currencyId,
            isUtility: symbol == "XOR", isNative: true, staking: symbol == "XOR" ? .relayChain : nil
        )
    }

    static func validator(_ accountId: Data, total: BigUInt, commission: BigUInt) -> EraValidatorInfo {
        EraValidatorInfo(
            accountId: accountId,
            exposure: ValidatorExposure(total: total, own: total, others: []),
            prefs: ValidatorPrefs(commission: commission, blocked: false)
        )
    }

    static func points(total: Int, _ individual: [(Data, Int)]) -> [String: Any] {
        ["total": String(total), "individual": individual.map { [$0.0.base64EncodedString(), String($0.1)] }]
    }

    static func settings(dexCount: Int) throws -> PolkaswapRemoteSettings {
        let json: [String: Any] = [
            "version": "1",
            "availableDexIds": (0 ..< dexCount).map { ["name": "DEX\($0)", "code": $0, "assetId": xor] },
            "availableSources": ["smart"],
            "forceSmartIds": [],
            "xstusdId": xor
        ]
        return try JSONDecoder().decode(PolkaswapRemoteSettings.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

enum SoraRewardServiceFixtureError: Error {
    case requestNotAnswered
}

/// Answers prefix reads with JSON keyed by the request type name.
final class SoraRewardServiceStoragePerformer: SSFStorageQueryKit.StorageRequestPerformer {
    private let lock = NSLock()
    var responses: [String: Any] = [:]

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
        lock.lock()
        let json = responses[name]
        lock.unlock()
        guard let json = json else { return nil }
        return try JSONDecoder().decode([K: T].self, from: JSONSerialization.data(withJSONObject: json))
    }

    func perform(_: [any MixStorageRequest], chain _: ChainModel) async throws -> [MixStorageResponse] { [] }
}

final class SoraRewardServicePolkaswapStub: PolkaswapOperationFactoryProtocol {
    var amounts: [UInt32: String] = [:]

    private static func failed<T: Decodable>() -> JSONRPCOperation<[PolkaswapJSON], T> {
        let operation = JSONRPCOperation<[PolkaswapJSON], T>(engine: MockConnection(), method: "unexpected")
        operation.result = .failure(NSError(domain: "polkaswap-stub", code: 1))
        return operation
    }

    func createIsPathAvailableOperation(dexId _: UInt32, from _: String, to _: String) -> JSONRPCOperation<[PolkaswapJSON], Bool> {
        Self.failed()
    }

    func createGetAvailableMarketAlgorithmsOperation(
        dexId _: UInt32,
        from _: String,
        to _: String
    ) -> JSONRPCOperation<[PolkaswapJSON], [String]> {
        Self.failed()
    }

    func createIsPathAvalableAndMarketCompoundOperation(
        dexId _: UInt32,
        from _: String,
        to _: String
    ) -> CompoundOperationWrapper<(isAvailable: Bool, markets: [String])> {
        .createWithError(NSError(domain: "polkaswap-stub", code: 2))
    }

    func createPolkaswapQuoteOperation(dexId: UInt32, params _: PolkaswapQuoteParams) -> JSONRPCOperation<[PolkaswapJSON], SwapValues> {
        guard let amount = amounts[dexId] else { return Self.failed() }
        let operation = JSONRPCOperation<[PolkaswapJSON], SwapValues>(engine: MockConnection(), method: "quote")
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
        completion(.failure(NSError(domain: "polkaswap-stub", code: 3)))
    }

    func createDexInfosOperation() -> CompoundOperationWrapper<[UInt32]> {
        .createWithError(NSError(domain: "polkaswap-stub", code: 4))
    }
}

final class SoraRewardServiceAssets: ChainAssetFetchingProtocol {
    let chainAssets: [ChainAsset]

    init(chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
    }

    func fetch(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        completionBlock(.success(chainAssets))
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        let chainAssets = chainAssets
        return ClosureOperation { chainAssets }
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        chainAssets
    }
}

struct SoraRewardServiceSettingsRepository: DataProviderRepositoryProtocol {
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

final class SoraRewardServiceEraStub: EraValidatorServiceProtocol {
    var info = EraStakersInfo(activeEra: 1, validators: [])
    private let lock = NSLock()
    private var setupCount = 0

    var setups: Int {
        lock.lock()
        defer { lock.unlock() }
        return setupCount
    }

    func setup() {
        lock.lock()
        setupCount += 1
        lock.unlock()
    }

    func throttle() {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        let info = info
        return ClosureOperation { info }
    }
}

struct SoraRewardServiceDuration: StakingDurationOperationFactoryProtocol {
    func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            StakingDuration(session: 3600, era: 21600, unlocking: 604_800)
        })
    }
}

final class SoraRewardServiceRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    private static var cachedRuntime: AssetHubRuntimeFixture?

    static func sharedRuntime() throws -> AssetHubRuntimeFixture {
        if let cachedRuntime {
            return cachedRuntime
        }
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        cachedRuntime = runtime
        return runtime
    }

    var runtime: RuntimeProviderProtocol?
    var hasConnection = true

    override func getConnection(for _: ChainModel.Id) -> ChainConnection? {
        hasConnection ? MockConnection() : nil
    }

    override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtime
    }
}
