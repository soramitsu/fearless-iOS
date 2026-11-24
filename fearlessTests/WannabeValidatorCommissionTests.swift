import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// A validator's commission is stored as parts per billion. The "wannabe" validators list (validators a nominator
/// picked that are not elected) converted it as a token amount with the asset's decimals, so 10 % on a 2-decimal
/// token showed as 1,000,000.
final class WannabeValidatorCommissionTests: XCTestCase {
    func testWannabeValidatorCommissionIsAFractionOfOne() throws {
        let tenPercent = Data(repeating: 0xA1, count: 32)
        let fivePercent = Data(repeating: 0xA2, count: 32)
        let withoutPrefs = Data(repeating: 0xA3, count: 32)
        let storage = WannabeValidatorPrefsStorage(prefs: [
            tenPercent: ["commission": "100000000", "blocked": false],
            fivePercent: ["commission": "50000000", "blocked": true]
        ])
        let factory = try Self.factory(storage: storage, precision: 2)

        let validators = try Self.execute(factory.wannabeValidatorsOperation(for: [tenPercent, withoutPrefs, fivePercent]))

        XCTAssertEqual(validators.count, 2, "a validator without prefs is left out")
        XCTAssertEqual(validators.map(\.commission), [Decimal(string: "0.1"), Decimal(string: "0.05")])
        XCTAssertEqual(validators.map(\.blocked), [false, true])
    }

    // MARK: - Fixtures

    private static func factory(storage: WannabeValidatorPrefsStorage, precision: UInt16) throws -> RelaychainValidatorOperationFactory {
        let asset = ChainModelGenerator.generateAssetWithId("tkn", symbol: "TKN", assetPresicion: precision)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let runtime = WannabeValidatorRuntimeProvider(
            try StakingConstantRuntime(values: [.slashDeferDuration: 3, .maxNominatorRewardedPerValidator: 2])
        )
        let registry = WannabeValidatorRegistry(runtime: runtime)
        let engine = RewardCalculatorEngine(
            chainId: chain.chainId,
            assetPrecision: Int16(precision),
            totalIssuance: 1_000_000,
            validators: [],
            eraDurationInSeconds: 21600
        )
        return RelaychainValidatorOperationFactory(
            asset: asset,
            chain: chain,
            eraValidatorService: EraValidatorServiceStub(info: EraStakersInfo(activeEra: 10, validators: [])),
            rewardService: RewardCalculatorServiceStub(engine: engine),
            storageRequestFactory: storage,
            identityOperationFactory: WannabeValidatorIdentities(),
            chainRegistry: registry
        )
    }

    private static func execute<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let queue = OperationQueue()
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
}

/// Answers Staking.Validators reads from JSON keyed by account id; every other storage read is empty.
final class WannabeValidatorPrefsStorage: StorageRequestFactoryProtocol {
    let prefs: [Data: [String: Any]]

    init(prefs: [Data: [String: Any]]) {
        self.prefs = prefs
    }

    func queryItems<K: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        let prefs = prefs
        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try factory()
            guard storagePath == .validatorPrefs else { return [] }
            return try keyParams().compactMap { $0 as? Data }.map { accountId in
                guard let json = prefs[accountId] else {
                    return StorageResponse(key: accountId, data: nil, value: nil)
                }
                let data = try JSONSerialization.data(withJSONObject: json)
                return StorageResponse(key: accountId, data: data, value: try JSONDecoder().decode(T.self, from: data))
            }
        })
    }

    // swiftlint:disable:next function_parameter_count
    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams1 _: @escaping () throws -> [K1],
        keyParams2 _: @escaping () throws -> [K2], factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { CompoundOperationWrapper(targetOperation: ClosureOperation { [] }) }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { CompoundOperationWrapper(targetOperation: ClosureOperation { [] }) }

    // swiftlint:disable:next function_parameter_count
    func queryChildItem<T: Decodable>(
        engine _: JSONRPCEngine, storageKeyParam _: @escaping () throws -> Data,
        childKeyParam _: @escaping () throws -> Data, factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper _: DynamicScaleDecodable, at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> {
        .createWithError(NSError(domain: "wannabe-storage", code: 1))
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: @escaping () throws -> [[NMapKeyParamProtocol]],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { CompoundOperationWrapper(targetOperation: ClosureOperation { [] }) }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { CompoundOperationWrapper(targetOperation: ClosureOperation { [] }) }
}

final class WannabeValidatorIdentities: IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for _: @escaping () throws -> [AccountId],
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [:] })
    }
}

/// Serves a runtime coding service as a registry runtime provider.
final class WannabeValidatorRuntimeProvider: RuntimeProviderProtocol {
    let base: RuntimeCodingServiceProtocol

    init(_ base: RuntimeCodingServiceProtocol) {
        self.base = base
    }

    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }
    var snapshot: RuntimeSnapshot? { base.snapshot }

    func setup() {}
    func setupHot() {}
    func cleanup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        guard let snapshot = base.snapshot else { throw NSError(domain: "wannabe-runtime", code: 1) }
        return snapshot
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        base.fetchCoderFactoryOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try await base.fetchCoderFactory()
    }
}

final class WannabeValidatorRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    private let runtime: RuntimeProviderProtocol
    private let connection = MockConnection()

    init(runtime: RuntimeProviderProtocol) {
        self.runtime = runtime
        super.init()
    }

    override func getConnection(for _: ChainModel.Id) -> ChainConnection? {
        connection
    }

    override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtime
    }
}
