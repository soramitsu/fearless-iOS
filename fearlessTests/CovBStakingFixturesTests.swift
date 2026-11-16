import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

struct CovBSkError: Error, Equatable {
    let code: Int
}

/// Serves a runtime coding service as a registry runtime provider.
final class CovBSkRuntimeProvider: RuntimeProviderProtocol {
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
        guard let snapshot = base.snapshot else { throw CovBSkError(code: 1) }
        return snapshot
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        base.fetchCoderFactoryOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try await base.fetchCoderFactory()
    }
}

/// A runtime that names the chain it serves, as the staking clock expects of Asset Hub runtimes.
final class CovBSkIdentifiedRuntime: RuntimeCodingServiceProtocol, StakingRuntimeIdentifying {
    let chainId: String
    let base: RuntimeCodingServiceProtocol

    init(chainId: String, base: RuntimeCodingServiceProtocol) {
        self.chainId = chainId
        self.base = base
    }

    var snapshot: RuntimeSnapshot? { base.snapshot }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        base.fetchCoderFactoryOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        try await base.fetchCoderFactory()
    }
}

/// A registry that answers with the connections and runtimes registered per chain.
final class CovBSkRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    private let lock = NSLock()
    private var connections: [ChainModel.Id: ChainConnection] = [:]
    private var runtimes: [ChainModel.Id: RuntimeProviderProtocol] = [:]
    private var runtimeRequestCount = 0

    var runtimeRequests: Int {
        lock.lock(); defer { lock.unlock() }
        return runtimeRequestCount
    }

    func register(_ chainId: ChainModel.Id, connection: ChainConnection?, runtime: RuntimeProviderProtocol?) {
        lock.lock(); defer { lock.unlock() }
        connections[chainId] = connection
        runtimes[chainId] = runtime
    }

    override func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        lock.lock(); defer { lock.unlock() }
        return connections[chainId]
    }

    override func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        lock.lock(); defer { lock.unlock() }
        runtimeRequestCount += 1
        return runtimes[chainId]
    }
}

/// Storage keyed by path and parameter, answered from JSON so values decode like chain responses.
final class CovBSkStorage: StorageRequestFactoryProtocol {
    static let keyPrefix = Data(repeating: 0xEE, count: 32)

    private let lock = NSLock()
    private var values: [String: [String: Any]] = [:]
    private var prefixed: [String: [(Data, Any)]] = [:]
    private var recorded: [String: [[String]]] = [:]
    var failure: Error?

    func put(_ path: fearless.StorageCodingPath, param: String, json: Any) {
        lock.lock(); defer { lock.unlock() }
        values[path.itemName, default: [:]][param] = json
    }

    func put(_ path: fearless.StorageCodingPath, account: Data, json: Any) {
        put(path, param: account.toHex(), json: json)
    }

    func putPrefixed(_ path: fearless.StorageCodingPath, key: Data, json: Any) {
        lock.lock(); defer { lock.unlock() }
        prefixed[path.itemName, default: []].append((key, json))
    }

    func requests(_ path: fearless.StorageCodingPath) -> [[String]] {
        lock.lock(); defer { lock.unlock() }
        return recorded[path.itemName] ?? []
    }

    private func record(_ path: fearless.StorageCodingPath, _ params: [String]) {
        lock.lock(); defer { lock.unlock() }
        recorded[path.itemName, default: []].append(params)
    }

    private func stored(_ path: fearless.StorageCodingPath, _ param: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return values[path.itemName]?[param]
    }

    private static func decode<T: Decodable>(_ json: Any?, key: Data) throws -> StorageResponse<T> {
        guard let json = json else { return StorageResponse(key: key, data: nil, value: nil) }
        let data = try JSONSerialization.data(withJSONObject: json, options: .fragmentsAllowed)
        return StorageResponse(key: key, data: data, value: try JSONDecoder().decode(T.self, from: data))
    }

    private func keyed<T: Decodable>(
        path: fearless.StorageCodingPath,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: @escaping () throws -> [(String, Data)]
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try factory()
            if let failure = self.failure { throw failure }
            let keys = try params()
            self.record(path, keys.map { $0.0 })
            return try keys.map { param, raw in
                try Self.decode(self.stored(path, param), key: Self.keyPrefix + raw)
            }
        })
    }

    func queryItems<K: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        keyed(path: storagePath, factory: factory) {
            try keyParams().map { param -> (String, Data) in
                if let data = param as? Data { return (data.toHex(), data) }
                if let text = param as? String { return (text, Data(text.utf8)) }
                let encoded = try JSONEncoder().encode(param)
                let text = (String(data: encoded, encoding: .utf8) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return (text, Data(text.utf8))
            }
        }
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        keyed(path: storagePath, factory: factory) { try keys().map { ($0.toHex(), $0) } }
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: @escaping () throws -> [[NMapKeyParamProtocol]],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { .createWithError(CovBSkError(code: 90)) }

    // swiftlint:disable:next function_parameter_count
    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams1 _: @escaping () throws -> [K1],
        keyParams2 _: @escaping () throws -> [K2], factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { .createWithError(CovBSkError(code: 91)) }

    // swiftlint:disable:next function_parameter_count
    func queryChildItem<T: Decodable>(
        engine _: JSONRPCEngine, storageKeyParam _: @escaping () throws -> Data,
        childKeyParam _: @escaping () throws -> Data, factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper _: DynamicScaleDecodable, at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> { .createWithError(CovBSkError(code: 92)) }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try factory()
            if let failure = self.failure { throw failure }
            self.record(storagePath, try keys().map { $0.toHex() })
            self.lock.lock()
            let entries = self.prefixed[storagePath.itemName] ?? []
            self.lock.unlock()
            return try entries.map { key, json in try Self.decode(json, key: key) }
        })
    }
}

/// A node answering paged key and storage reads from SCALE values encoded by `AssetHubStorageFixture`.
final class CovBSkEngine: JSONRPCEngine {
    let source: AssetHubStorageFixture
    let block = Data(repeating: 0x42, count: 32)
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var failure: Error?
    /// Keys listed by the node whose value reads come back empty.
    var emptyKeys: [String] = []
    private let lock = NSLock()
    private var identifier: UInt16 = 0
    private var recordedMethods: [String] = []

    init(source: AssetHubStorageFixture) {
        self.source = source
    }

    var methods: [String] {
        lock.lock(); defer { lock.unlock() }
        return recordedMethods
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let requestId = generateRequestId()
        do {
            if let failure = failure { throw failure }
            let parameters = try params.map {
                try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? [Any] ?? []
            } ?? []
            lock.lock(); recordedMethods.append(method); lock.unlock()
            let object: Any
            switch method {
            case "chain_getFinalizedHead":
                object = block.toHex(includePrefix: true)
            case "state_getKeysPaged":
                let prefix = (parameters.first as? String ?? "").lowercased()
                let offset = parameters.count > 2 ? parameters[2] as? String : nil
                let all = Array(source.values.keys) + emptyKeys
                object = all.filter { key in key.hasPrefix(prefix) && (offset.map { key > $0 } ?? true) }.sorted()
            case "state_queryStorageAt":
                let keys = parameters.first as? [String] ?? []
                let changes: [[Any]] = keys.map { [$0, source.values[$0] as Any? ?? NSNull()] }
                object = [["block": block.toHex(includePrefix: true), "changes": changes]]
            default:
                throw CovBSkError(code: 99)
            }
            let data = try JSONSerialization.data(withJSONObject: object, options: .fragmentsAllowed)
            closure?(.success(try JSONDecoder().decode(T.self, from: data)))
        } catch {
            closure?(.failure(error))
        }
        return requestId
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw CovBSkError(code: 98)
    }

    func generateRequestId() -> UInt16 {
        lock.lock(); defer { lock.unlock() }
        identifier &+= 1
        return identifier
    }

    func cancelForIdentifier(_: UInt16) {}
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

/// Identities answered at execution time; records the engine, runtime and the account ids it was asked for.
final class CovBSkIdentityFactory: IdentityOperationFactoryProtocol {
    private let lock = NSLock()
    var identities: [AccountAddress: AccountIdentity] = [:]
    var failure: Error?
    private(set) var engines: [JSONRPCEngine] = []
    private(set) var runtimes: [RuntimeCodingServiceProtocol] = []
    private var requested: [[AccountId]] = []

    var requestedIds: [[AccountId]] {
        lock.lock(); defer { lock.unlock() }
        return requested
    }

    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        engines.append(engine)
        runtimes.append(runtimeService)
        let operation = ClosureOperation<[AccountAddress: AccountIdentity]> {
            let ids = try accountIdClosure()
            self.lock.lock(); self.requested.append(ids); self.lock.unlock()
            if let failure = self.failure { throw failure }
            return self.identities
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

/// Returns per validator yearly returns; an unknown validator throws like the real engines.
final class CovBSkRewardEngine: RewardCalculatorEngineProtocol {
    var returns: [AccountId: Decimal] = [:]
    var rewardAssetRate: Decimal { 1 }

    func calculateEarnings(amount: Decimal, validatorAccountId: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        guard let value = returns[validatorAccountId] else {
            throw RewardCalculatorEngineError.unexpectedValidator(accountId: validatorAccountId)
        }
        return amount * value
    }

    func calculateMaxEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculateAvgEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculatorReturn(isCompound _: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal { 0 }
    func maxEarningsTitle(locale _: Locale) -> String { "max" }
    func avgEarningTitle(locale _: Locale) -> String { "avg" }
}

final class CovBSkRewardService: RewardCalculatorServiceProtocol {
    var engine: RewardCalculatorEngineProtocol
    var failure: Error?

    init(engine: RewardCalculatorEngineProtocol) {
        self.engine = engine
    }

    func setup() {}
    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation {
            if let failure = self.failure { throw failure }
            return self.engine
        }
    }
}

final class CovBSkEraService: EraValidatorServiceProtocol {
    var info = EraStakersInfo(activeEra: 0, validators: [])
    var failure: Error?
    private(set) var setups = 0

    func setup() { setups += 1 }
    func throttle() {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        ClosureOperation {
            if let failure = self.failure { throw failure }
            return self.info
        }
    }
}

enum CovBSkFixtures {
    static let validatorA = Data(repeating: 0x0A, count: 32)
    static let validatorB = Data(repeating: 0x0B, count: 32)
    static let validatorC = Data(repeating: 0x0C, count: 32)
    static let validatorD = Data(repeating: 0x0D, count: 32)
    static let nominator = Data(repeating: 0x03, count: 32)
    static let other = Data(repeating: 0x04, count: 32)

    static func chain(id: ChainModel.Id = "covb-relay", identityChain: ChainModel.Id? = nil, precision: UInt16 = 2) -> ChainModel {
        let token = AssetModel(
            id: "0", name: "STAKE", symbol: "STAKE", precision: precision,
            isUtility: true, isNative: true, staking: .relayChain, type: nil
        )
        return ChainModel(
            rank: nil, disabled: false, chainId: id, parentId: nil, paraId: nil, name: id,
            assets: [token], xcm: nil, nodes: [], addressPrefix: 42, icon: nil,
            iosMinAppVersion: nil, identityChain: identityChain
        )
    }

    static func exposure(_ who: Data, _ value: BigUInt) throws -> IndividualExposure {
        let data = try JSONSerialization.data(withJSONObject: ["who": who.base64EncodedString(), "value": String(value)])
        return try JSONDecoder().decode(IndividualExposure.self, from: data)
    }

    static func validator(
        _ id: Data,
        others: [(Data, BigUInt)] = [],
        total: BigUInt = 300,
        own: BigUInt = 100,
        commission: BigUInt = 200_000_000,
        blocked: Bool = false
    ) throws -> EraValidatorInfo {
        EraValidatorInfo(
            accountId: id,
            exposure: ValidatorExposure(total: total, own: own, others: try others.map { try exposure($0.0, $0.1) }),
            prefs: ValidatorPrefs(commission: commission, blocked: blocked)
        )
    }

    static func nomination(targets: [Data], submittedIn: UInt32) throws -> Nomination {
        let json: [String: Any] = ["targets": targets.map { $0.base64EncodedString() }, "submittedIn": String(submittedIn)]
        return try JSONDecoder().decode(Nomination.self, from: JSONSerialization.data(withJSONObject: json))
    }

    static func address(_ id: Data, chain: ChainModel) throws -> AccountAddress {
        try AddressFactory.address(for: id, chainFormat: chain.chainFormat)
    }

    static func execute<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let queue = OperationQueue()
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
}

final class CovBSkFixturesTests: XCTestCase {
    func testStorageAnswersEachParameterAndRecordsTheRequest() throws {
        let storage = CovBSkStorage()
        storage.put(.validatorPrefs, account: CovBSkFixtures.validatorA, json: ["commission": "5", "blocked": true])
        let wrapper: CompoundOperationWrapper<[StorageResponse<ValidatorPrefs>]> = storage.queryItems(
            engine: MockConnection(),
            keyParams: { [CovBSkFixtures.validatorA, CovBSkFixtures.validatorB] },
            factory: { try StakingConstantRuntime().factory },
            storagePath: .validatorPrefs
        )
        let responses = try CovBSkFixtures.execute(wrapper)
        XCTAssertEqual(responses.map { $0.value?.blocked }, [true, nil])
        XCTAssertEqual(responses.first?.key, CovBSkStorage.keyPrefix + CovBSkFixtures.validatorA)
        XCTAssertEqual(storage.requests(.validatorPrefs), [[CovBSkFixtures.validatorA.toHex(), CovBSkFixtures.validatorB.toHex()]])
    }

    func testRewardEngineThrowsForUnknownValidator() {
        let engine = CovBSkRewardEngine()
        engine.returns[CovBSkFixtures.validatorA] = 0.1
        XCTAssertEqual(try engine.calculateValidatorReturn(validatorAccountId: CovBSkFixtures.validatorA, isCompound: false, period: .year), 0.1)
        XCTAssertThrowsError(try engine.calculateValidatorReturn(validatorAccountId: CovBSkFixtures.validatorB, isCompound: false, period: .year))
    }
}
