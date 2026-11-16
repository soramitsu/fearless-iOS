import XCTest
import BigInt
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
import SSFModels
import Web3
@testable import fearless

/// Storage request factory that answers every query with prepared responses and records the keys it was asked for.
final class CovJFinStorageRequestFactory: StorageRequestFactoryProtocol {
    var responses: Any = [Any]()
    var childResponse: Any?
    var failure: Error?

    private let lock = NSLock()
    private var recordedPaths: [fearless.StorageCodingPath] = []
    private var recordedKeys: [String] = []
    private var recordedStorageKey: Data?
    private var recordedChildKey: Data?

    var paths: [fearless.StorageCodingPath] { locked { recordedPaths } }
    var encodedKeys: [String] { locked { recordedKeys } }
    var storageKey: Data? { locked { recordedStorageKey } }
    var childKey: Data? { locked { recordedChildKey } }

    private func locked<R>(_ block: () -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    private func record(path: fearless.StorageCodingPath) {
        locked { recordedPaths.append(path) }
    }

    private func record<K: Encodable>(keys: [K]) throws {
        let data = try JSONEncoder().encode(keys)
        let text = String(data: data, encoding: .utf8) ?? ""
        locked { recordedKeys.append(text) }
    }

    private func answer<T>(_ type: T.Type) throws -> T {
        if let failure { throw failure }
        guard let typed = responses as? T else { throw CovJError("unexpected response type \(T.self)") }
        return typed
    }

    func queryItems<K, T>(
        engine _: JSONRPCEngine,
        keyParams: @escaping () throws -> [K],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath,
        at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K: Encodable, T: Decodable {
        record(path: storagePath)
        let operation = ClosureOperation<[StorageResponse<T>]> {
            try self.record(keys: try keyParams())
            return try self.answer([StorageResponse<T>].self)
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func queryItems<K1, K2, T>(
        engine _: JSONRPCEngine,
        keyParams1 _: @escaping () throws -> [K1],
        keyParams2 _: @escaping () throws -> [K2],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath,
        at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where K1: Encodable, K2: Encodable, T: Decodable {
        record(path: storagePath)
        return CompoundOperationWrapper(targetOperation: ClosureOperation { try self.answer([StorageResponse<T>].self) })
    }

    func queryItems<T>(
        engine _: JSONRPCEngine,
        keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath,
        at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        record(path: storagePath)
        return CompoundOperationWrapper(targetOperation: ClosureOperation { try self.answer([StorageResponse<T>].self) })
    }

    func queryChildItem<T>(
        engine _: JSONRPCEngine,
        storageKeyParam: @escaping () throws -> Data,
        childKeyParam: @escaping () throws -> Data,
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper _: DynamicScaleDecodable,
        at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> where T: Decodable {
        let operation = ClosureOperation<ChildStorageResponse<T>> {
            let storageKey = try storageKeyParam()
            let childKey = try childKeyParam()
            self.locked {
                self.recordedStorageKey = storageKey
                self.recordedChildKey = childKey
            }
            if let failure = self.failure { throw failure }
            guard let typed = self.childResponse as? ChildStorageResponse<T> else { throw CovJError("unexpected child response") }
            return typed
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func queryItems<T>(
        engine _: JSONRPCEngine,
        keyParams _: @escaping () throws -> [[fearless.NMapKeyParamProtocol]],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath,
        at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        record(path: storagePath)
        return CompoundOperationWrapper(targetOperation: ClosureOperation { try self.answer([StorageResponse<T>].self) })
    }

    func queryItemsByPrefix<T>(
        engine _: JSONRPCEngine,
        keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath,
        at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> where T: Decodable {
        record(path: storagePath)
        return CompoundOperationWrapper(targetOperation: ClosureOperation { try self.answer([StorageResponse<T>].self) })
    }
}

/// Runtime service with an optional snapshot and a ready coder factory; counts coder factory requests.
final class CovJFinRuntimeService: RuntimeCodingServiceProtocol {
    let snapshot: RuntimeSnapshot?
    let factory: RuntimeCoderFactoryProtocol
    private let lock = NSLock()
    private var requests = 0

    var factoryRequests: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    init(snapshot: RuntimeSnapshot?, factory: RuntimeCoderFactoryProtocol) {
        self.snapshot = snapshot
        self.factory = factory
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        lock.lock()
        requests += 1
        lock.unlock()
        return ClosureOperation { self.factory }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { factory }
}

/// JSON-RPC engine that answers every call synchronously with `answer` and records method names and parameters.
final class CovJFinEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var answer: Any = [String]()

    private let lock = NSLock()
    private var recordedMethods: [String] = []
    private var recordedParams: [String] = []
    private var nextId: UInt16 = 0

    var methods: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedMethods
    }

    var params: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedParams
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let encoded = try params.map { try JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        lock.lock()
        recordedMethods.append(method)
        recordedParams.append(encoded)
        lock.unlock()
        if let typed = answer as? T {
            closure?(.success(typed))
        } else {
            closure?(.failure(CovJError("unexpected rpc result type")))
        }
        return generateRequestId()
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        generateRequestId()
    }

    func cancelForIdentifier(_: UInt16) {}

    func generateRequestId() -> UInt16 {
        lock.lock()
        defer { lock.unlock() }
        nextId &+= 1
        return nextId
    }

    func addSubscription(_: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

/// Chain registry with no chains, connections or runtimes; nothing here starts networking.
final class CovJFinChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? { nil }
    var availableChains: [ChainModel] { [] }
    var chainsTypesMap: [String: Data] { [:] }

    func resetConnection(for _: ChainModel.Id) {}
    func retryConnection(for _: ChainModel.Id) {}
    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw CovJError("no TON in lane J") }
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
    func getChain(for _: ChainModel.Id) -> ChainModel? { nil }
    func chainsSubscribe(
        _: AnyObject,
        runningInQueue _: DispatchQueue,
        updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {}
    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

enum CovJFinCrowdloanFixture {
    static let fundAccountPrefix = Data("modlpy/cfund".utf8)

    static func funds(raised: Int = 50, cap: Int = 100, end: UInt32 = 1000, firstPeriod: UInt32 = 10, trieIndex: UInt32 = 5) throws -> CrowdloanFunds {
        let json = """
        {"depositor":"\(Data(repeating: 7, count: 32).base64EncodedString())","verifier":null,"deposit":"1",
        "raised":"\(raised)","end":"\(end)","cap":"\(cap)","lastContribution":["Never"],
        "firstPeriod":"\(firstPeriod)","lastPeriod":"\(firstPeriod + 3)","trieIndex":"\(trieIndex)"}
        """
        return try JSONDecoder().decode(CrowdloanFunds.self, from: Data(json.utf8))
    }

    static func contribution(balance: Int, memo: [UInt8] = [1, 2]) throws -> CrowdloanContribution {
        let memoJSON = memo.map { "\"\($0)\"" }.joined(separator: ",")
        let json = "{\"balance\":\"\(balance)\",\"memo\":[\(memoJSON)]}"
        return try JSONDecoder().decode(CrowdloanContribution.self, from: Data(json.utf8))
    }

    static func leases(_ entries: [(Data, Int)?]) throws -> [ParachainSlotLease?] {
        let items = entries.map { entry -> String in
            guard let (account, amount) = entry else { return "null" }
            return "[\"\(account.base64EncodedString())\",\"\(amount)\"]"
        }
        return try JSONDecoder().decode([ParachainSlotLease?].self, from: Data("[\(items.joined(separator: ","))]".utf8))
    }

    static func littleEndian(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    static func fundAccount(_ paraId: UInt32) -> Data {
        (fundAccountPrefix + littleEndian(paraId) + Data(repeating: 0, count: 32)).prefix(32)
    }

    /// A storage key whose four-byte suffix is the SCALE-encoded para id.
    static func fundsKey(_ paraId: UInt32) -> Data {
        Data(repeating: 0xAB, count: 32) + Data(repeating: 0x11, count: 8) + littleEndian(paraId)
    }

    /// A v14 runtime whose schema holds `polkadot_parachain::primitives::Id(u32)`.
    static func paraIdRuntime() throws -> CovJFinRuntimeService {
        func item(_ build: (ScaleEncoder) throws -> Void) throws -> SchemaItem {
            let encoder = ScaleEncoder()
            try build(encoder)
            return try SchemaItem(scaleDecoder: try ScaleDecoder(data: encoder.encode()))
        }
        let paraId = try item { encoder in
            try BigUInt(0).encode(scaleEncoder: encoder)
            try ["polkadot_parachain", "primitives", "Id"].encode(scaleEncoder: encoder)
            try BigUInt(0).encode(scaleEncoder: encoder) // params
            try UInt8(0).encode(scaleEncoder: encoder) // composite
            try BigUInt(1).encode(scaleEncoder: encoder) // one field
            try UInt8(0).encode(scaleEncoder: encoder) // unnamed
            try BigUInt(1).encode(scaleEncoder: encoder) // of type 1
            try UInt8(0).encode(scaleEncoder: encoder) // no type name
            try BigUInt(0).encode(scaleEncoder: encoder) // field docs
            try BigUInt(0).encode(scaleEncoder: encoder) // type docs
        }
        let u32 = try item { encoder in
            try BigUInt(1).encode(scaleEncoder: encoder)
            try BigUInt(0).encode(scaleEncoder: encoder) // path
            try BigUInt(0).encode(scaleEncoder: encoder) // params
            try UInt8(5).encode(scaleEncoder: encoder) // primitive
            try UInt8(5).encode(scaleEncoder: encoder) // u32
            try BigUInt(0).encode(scaleEncoder: encoder) // docs
        }
        let metadata = try RuntimeMetadata.v14(
            types: [paraId, u32],
            modules: [],
            extrinsic: RuntimeMetadataV14.ExtrinsicMetadata(type: 0, version: 4, signedExtensions: [])
        )
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data("{\"types\":{}}".utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        let factory = RuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
        let snapshot = RuntimeSnapshot(typeRegistryCatalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
        return CovJFinRuntimeService(snapshot: snapshot, factory: factory)
    }

    static func emptyRuntime() throws -> CovJFinRuntimeService {
        let metadata = try RuntimeMetadata.v14(
            types: [],
            modules: [],
            extrinsic: RuntimeMetadataV14.ExtrinsicMetadata(type: 0, version: 4, signedExtensions: [])
        )
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data("{\"types\":{}}".utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        return CovJFinRuntimeService(snapshot: nil, factory: RuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata))
    }

    /// Runs the wrapper on a background queue and spins the main run loop until it finishes.
    static func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let queue = OperationQueue()
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        XCTAssertTrue(CovJWait.until(timeout: 5) { wrapper.targetOperation.isFinished })
        let result = try XCTUnwrap(wrapper.targetOperation.result)
        return try result.get()
    }
}

final class CovJFinCrowdloanOperationFactoryTests: XCTestCase {
    private func makeFactory(_ storage: CovJFinStorageRequestFactory) -> CrowdloanOperationFactory {
        CrowdloanOperationFactory(
            requestOperationFactory: storage,
            operationManager: OperationManager(operationQueue: OperationQueue()),
            chainRegistry: CovJFinChainRegistry()
        )
    }

    func testCrowdloansAreReadFromFundKeysAndDropEmptyOrUndecodableEntries() throws {
        let storage = CovJFinStorageRequestFactory()
        let funds = try CovJFinCrowdloanFixture.funds(raised: 40, trieIndex: 9)
        storage.responses = [
            StorageResponse<CrowdloanFunds>(key: CovJFinCrowdloanFixture.fundsKey(2000), data: nil, value: funds),
            StorageResponse<CrowdloanFunds>(key: CovJFinCrowdloanFixture.fundsKey(3000), data: nil, value: nil),
            StorageResponse<CrowdloanFunds>(key: Data([1, 2]), data: nil, value: funds)
        ]
        let engine = CovJFinEngine()
        engine.answer = [2000, 3000].map { CovJFinCrowdloanFixture.fundsKey($0).toHex(includePrefix: true) }
        let runtime = try CovJFinCrowdloanFixture.paraIdRuntime()

        let crowdloans = try CovJFinCrowdloanFixture.run(makeFactory(storage).fetchCrowdloansOperation(connection: engine, runtimeService: runtime))

        XCTAssertEqual(crowdloans.map(\.paraId), [2000])
        XCTAssertEqual(crowdloans.first?.fundInfo, funds)
        XCTAssertEqual(crowdloans.first?.fundInfo.trieOrFundIndex, .trieIndex(9))
        XCTAssertEqual(storage.paths, [.crowdloanFunds])
        XCTAssertEqual(storage.encodedKeys, ["[\"2000\",\"3000\"]"])
        XCTAssertEqual(engine.methods, [RPCMethod.getStorageKeysPaged])
        let prefix = try StorageKeyFactory().key(from: fearless.StorageCodingPath.crowdloanFunds).toHex(includePrefix: true)
        XCTAssertEqual(engine.params, ["[\"\(prefix)\",1000]"])
        XCTAssertEqual(runtime.factoryRequests, 1)
    }

    func testCrowdloansFailWithoutParaIdTypeInRuntimeSchema() throws {
        let storage = CovJFinStorageRequestFactory()
        let runtime = try CovJFinCrowdloanFixture.emptyRuntime()
        let wrapper = makeFactory(storage).fetchCrowdloansOperation(connection: CovJFinEngine(), runtimeService: runtime)

        switch wrapper.targetOperation.result {
        case let .failure(error as fearless.ConvenienceError):
            XCTAssertEqual(error.error, "type polkadot_primitives::Id not found")
        default:
            XCTFail("expected an immediate ConvenienceError, got \(String(describing: wrapper.targetOperation.result))")
        }
        XCTAssertTrue(storage.paths.isEmpty)
        XCTAssertEqual(runtime.factoryRequests, 1)
    }

    func testContributionQueriesTheFundChildTrieWithTheAccountKey() throws {
        let storage = CovJFinStorageRequestFactory()
        let contribution = try CovJFinCrowdloanFixture.contribution(balance: 1_500, memo: [9, 8, 7])
        let accountId = Data(repeating: 3, count: 32)
        storage.childResponse = ChildStorageResponse<CrowdloanContribution>(
            storageKey: accountId, childKey: Data([1]), data: nil, value: contribution
        )
        let runtime = try CovJFinCrowdloanFixture.emptyRuntime()

        let response = try CovJFinCrowdloanFixture.run(makeFactory(storage).fetchContributionOperation(
            connection: CovJFinEngine(), runtimeService: runtime, accountId: accountId, trieOrFundIndex: .fundIndex(42)
        ))

        XCTAssertEqual(response.accountId, accountId)
        XCTAssertEqual(response.trieOrFundIndex, .fundIndex(42))
        XCTAssertEqual(response.contribution?.balance, 1_500)
        XCTAssertEqual(response.contribution?.memo, Data([9, 8, 7]))
        XCTAssertEqual(storage.storageKey, accountId)
        let suffix = try (Data("crowdloan".utf8) + CovJFinCrowdloanFixture.littleEndian(42)).blake2b32()
        XCTAssertEqual(storage.childKey, Data(":child_storage:default:".utf8) + suffix)
        XCTAssertEqual(runtime.factoryRequests, 1)
    }

    func testContributionWithoutValueAndQueryFailure() throws {
        let storage = CovJFinStorageRequestFactory()
        let accountId = Data(repeating: 4, count: 32)
        storage.childResponse = ChildStorageResponse<CrowdloanContribution>(storageKey: accountId, childKey: Data(), data: nil, value: nil)
        let factory = makeFactory(storage)
        let runtime = try CovJFinCrowdloanFixture.emptyRuntime()

        let empty = try CovJFinCrowdloanFixture.run(factory.fetchContributionOperation(
            connection: CovJFinEngine(), runtimeService: runtime, accountId: accountId, trieOrFundIndex: .trieIndex(1)
        ))
        XCTAssertNil(empty.contribution)
        XCTAssertEqual(empty.trieOrFundIndex, .trieIndex(1))

        storage.failure = CovJError("child query failed")
        XCTAssertThrowsError(try CovJFinCrowdloanFixture.run(factory.fetchContributionOperation(
            connection: CovJFinEngine(), runtimeService: runtime, accountId: accountId, trieOrFundIndex: .trieIndex(1)
        ))) { error in
            XCTAssertEqual(error as? CovJError, CovJError("child query failed"))
        }
    }

    func testLeaseInfoMatchesTheFundAccountOfEachParachain() throws {
        let storage = CovJFinStorageRequestFactory()
        let other = Data(repeating: 9, count: 32)
        storage.responses = [
            StorageResponse<[ParachainSlotLease?]>(
                key: Data([1]), data: nil,
                value: try CovJFinCrowdloanFixture.leases([(CovJFinCrowdloanFixture.fundAccount(2000), 500), nil, (other, 900)])
            ),
            StorageResponse<[ParachainSlotLease?]>(key: Data([2]), data: nil, value: nil),
            StorageResponse<[ParachainSlotLease?]>(
                key: Data([3]), data: nil, value: try CovJFinCrowdloanFixture.leases([(other, 700)])
            )
        ]
        let runtime = try CovJFinCrowdloanFixture.emptyRuntime()

        let infos = try CovJFinCrowdloanFixture.run(makeFactory(storage).fetchLeaseInfoOperation(
            connection: CovJFinEngine(), runtimeService: runtime, paraIds: [2000, 3000, 4000]
        ))

        XCTAssertEqual(infos.map(\.paraId), [2000, 3000, 4000])
        XCTAssertEqual(infos.map(\.fundAccountId), [2000, 3000, 4000].map { CovJFinCrowdloanFixture.fundAccount($0) })
        XCTAssertEqual(infos.first?.fundAccountId.count, 32)
        XCTAssertEqual(infos.first?.fundAccountId.prefix(12), CovJFinCrowdloanFixture.fundAccountPrefix)
        XCTAssertEqual(infos.map(\.leasedAmount), [BigUInt(500), nil, nil])
        XCTAssertEqual(storage.paths, [.parachainSlotLeases])
        XCTAssertEqual(storage.encodedKeys, ["[\"2000\",\"3000\",\"4000\"]"])
        let map = infos.toMap()
        XCTAssertEqual(map.count, 3)
        XCTAssertEqual(map[2000]?.leasedAmount, 500)
        XCTAssertNil(map[3000]?.leasedAmount)
    }

    func testLeaseInfoPropagatesQueryFailure() throws {
        let storage = CovJFinStorageRequestFactory()
        storage.failure = CovJError("lease query failed")
        let wrapper = makeFactory(storage).fetchLeaseInfoOperation(
            connection: CovJFinEngine(), runtimeService: try CovJFinCrowdloanFixture.emptyRuntime(), paraIds: [2000]
        )
        XCTAssertThrowsError(try CovJFinCrowdloanFixture.run(wrapper)) { error in
            XCTAssertEqual(error as? CovJError, CovJError("lease query failed"))
        }
        XCTAssertEqual(storage.encodedKeys, ["[\"2000\"]"])
    }
}
