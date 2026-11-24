import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// LegacyEraStakersFetching (runtimes with Staking.ErasStakers and no paged exposures) read each exposed validator's
/// Staking.Validators entry by key. An absent entry decodes to the storage default, so a validator with an exposure
/// but no prefs (one that chilled after the election) was kept with 0% commission, while the paged path leaves it out.
final class LegacyEraStakersFetchingTests: XCTestCase {
    private typealias Harness = LegacyEraStakersHarness

    func testRemoteReadLeavesOutAValidatorWithAnExposureButNoPrefs() throws {
        let harness = try Harness()
        try harness.putExposure(era: 10, account: Harness.listed, total: 500, own: 250, others: [(Harness.small, 50), (Harness.large, 200)])
        try harness.putExposure(era: 10, account: Harness.chilled, total: 90, own: 90, others: [])
        try harness.putPrefs(account: Harness.listed, commission: 100_000_000, blocked: true)

        harness.deliverActiveEra(10)
        let info = try harness.fetch()

        XCTAssertEqual(info.activeEra, 10)
        XCTAssertEqual(info.validators.map(\.accountId), [Harness.listed], "a validator without prefs is left out")
        let validator = try XCTUnwrap(info.validators.first)
        XCTAssertEqual(validator.prefs.commission, 100_000_000)
        XCTAssertTrue(validator.prefs.blocked)
        XCTAssertEqual(validator.exposure.total, 500)
        XCTAssertEqual(validator.exposure.own, 250)
        XCTAssertEqual(validator.exposure.others.map(\.who), [Harness.large, Harness.small], "nominators by stake")
        XCTAssertTrue(harness.node.methods.contains(RPCMethod.getStorageKeysPaged), "exposures are listed by the node")
    }

    func testCachedReadLeavesOutAValidatorWithAnExposureButNoPrefs() throws {
        let first = try Harness()
        try first.putExposure(era: 10, account: Harness.listed, total: 500, own: 250, others: [(Harness.large, 250)])
        try first.putExposure(era: 10, account: Harness.chilled, total: 90, own: 90, others: [])
        try first.putPrefs(account: Harness.listed, commission: 50_000_000, blocked: false)
        first.deliverActiveEra(10)
        XCTAssertEqual(try first.fetch().validators.map(\.accountId), [Harness.listed])

        // The next service finds both exposures in the local cache and reads only the prefs from the node.
        let second = try Harness(facade: first.facade, values: first.node.values)
        second.node.values = second.node.values.filter { !$0.key.hasPrefix(Harness.exposurePrefix) }
        second.deliverActiveEra(10)
        let info = try second.fetch()

        XCTAssertFalse(second.node.methods.contains(RPCMethod.getStorageKeysPaged), "a cached era is not listed again")
        XCTAssertEqual(info.validators.map(\.accountId), [Harness.listed], "a validator without prefs is left out")
        XCTAssertEqual(info.validators.first?.prefs.commission, 50_000_000)
    }

    /// Leaving out absent entries must not drop a validator that stored a 0% commission.
    func testAValidatorWithStoredZeroCommissionIsKept() throws {
        let harness = try Harness()
        try harness.putExposure(era: 7, account: Harness.listed, total: 300, own: 100, others: [(Harness.large, 200)])
        try harness.putExposure(era: 7, account: Harness.chilled, total: 90, own: 90, others: [])
        try harness.putPrefs(account: Harness.listed, commission: 0, blocked: false)
        try harness.putPrefs(account: Harness.chilled, commission: 0, blocked: false)

        harness.deliverActiveEra(7)
        let info = try harness.fetch()

        XCTAssertEqual(Set(info.validators.map(\.accountId)), [Harness.listed, Harness.chilled])
        XCTAssertEqual(info.validators.map(\.prefs.commission), [0, 0])
    }

    func testExposuresOfAnotherEraAreNotRead() throws {
        let harness = try Harness()
        try harness.putExposure(era: 10, account: Harness.listed, total: 500, own: 500, others: [])
        try harness.putExposure(era: 9, account: Harness.chilled, total: 70, own: 70, others: [])
        try harness.putPrefs(account: Harness.listed, commission: 10, blocked: false)
        try harness.putPrefs(account: Harness.chilled, commission: 20, blocked: false)

        harness.deliverActiveEra(10)

        XCTAssertEqual(try harness.fetch().validators.map(\.accountId), [Harness.listed])
    }
}

// MARK: - Harness

/// An EraValidatorService on a relay chain runtime from before paged exposures (the Polkadot 9370 metadata the app
/// bundles: Staking.ErasStakers, no ErasStakersOverview, served without a snapshot so the legacy path is taken), a node
/// that lists keys and answers storage reads from SCALE values, and an in-memory local storage.
final class LegacyEraStakersHarness {
    static let listed = Data(repeating: 0x0A, count: 32)
    static let chilled = Data(repeating: 0x0B, count: 32)
    static let large = Data(repeating: 0x03, count: 32)
    static let small = Data(repeating: 0x04, count: 32)
    static var exposurePrefix: String {
        (try? StorageKeyFactory().createStorageKey(moduleName: "Staking", storageName: "ErasStakers"))?
            .toHex(includePrefix: true) ?? "-"
    }

    let facade: SubstrateStorageTestFacade
    let manager = OperationManager()
    let node: LegacyEraStakersNode
    let chain: ChainModel
    let service: EraValidatorService

    init(facade: SubstrateStorageTestFacade = SubstrateStorageTestFacade(), values: [String: String] = [:]) throws {
        self.facade = facade
        node = LegacyEraStakersNode(values: values)
        let factory = try Self.legacyRuntime()
        XCTAssertNotNil(factory.metadata.getStorageMetadata(for: fearless.StorageCodingPath.erasStakers))
        XCTAssertNil(
            factory.metadata.getStorageMetadata(for: fearless.StorageCodingPath.erasStakersOverview),
            "the runtime has no paged exposures"
        )
        let token = AssetModel(
            id: "0", name: "STAKE", symbol: "STAKE", precision: 10,
            isUtility: true, isNative: true, staking: .relayChain, type: nil
        )
        chain = ChainModel(
            rank: nil, disabled: false, chainId: "legacy-era-stakers", parentId: nil, paraId: nil, name: "Legacy relay",
            assets: [token], xcm: nil, nodes: [], addressPrefix: 42, icon: nil, iosMinAppVersion: nil, identityChain: nil
        )
        service = EraValidatorService(
            chain: chain,
            storageFacade: facade,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            operationManager: manager,
            eventCenter: EventCenterProtocolStub(),
            chainRegistry: LegacyEraStakersRegistry(
                connection: node,
                runtime: WannabeValidatorRuntimeProvider(RuntimeCodingServiceStub(factory: factory))
            ),
            requestTimeout: 30
        )
    }

    static func legacyRuntime() throws -> TestRuntimeCoderFactory {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "polkadot-9370metadata", withExtension: nil))
        let hex = try String(contentsOf: url).components(separatedBy: .whitespacesAndNewlines).joined()
        let metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: Data(hexStringSSF: hex)))
        let definition = Data("{\"types\":{\"Index\":\"u32\",\"Balance\":\"u128\"}}".utf8)
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            definition,
            runtimeMetadata: metadata,
            usedRuntimePaths: [:]
        )
        return TestRuntimeCoderFactory(catalog: catalog, specVersion: 9370, txVersion: 20, metadata: metadata)
    }

    static func compact(_ value: UInt64) -> Data {
        switch value {
        case 0 ..< 64:
            return Data([UInt8(value << 2)])
        case 64 ..< 16384:
            return withUnsafeBytes(of: (UInt16(value) << 2 | 1).littleEndian) { Data($0) }
        default:
            return withUnsafeBytes(of: (UInt32(value) << 2 | 2).littleEndian) { Data($0) }
        }
    }

    static func eraBytes(_ era: UInt32) -> Data {
        withUnsafeBytes(of: era.littleEndian) { Data($0) }
    }

    /// Staking.ErasStakers(era, validator): total, own and the nominators' stakes, all compact.
    func putExposure(era: UInt32, account: Data, total: UInt64, own: UInt64, others: [(Data, UInt64)]) throws {
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: "Staking", storageName: "ErasStakers",
            key1: Self.eraBytes(era), hasher1: .twox64Concat, key2: account, hasher2: .twox64Concat
        )
        var value = Self.compact(total) + Self.compact(own) + Self.compact(UInt64(others.count))
        for (who, stake) in others {
            value += who + Self.compact(stake)
        }
        node.values[key.toHex(includePrefix: true)] = value.toHex(includePrefix: true)
    }

    /// Staking.Validators(validator): a compact Perbill commission and the blocked flag.
    func putPrefs(account: Data, commission: UInt64, blocked: Bool) throws {
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: "Staking", storageName: "Validators", key: account, hasher: .twox64Concat
        )
        node.values[key.toHex(includePrefix: true)] = (Self.compact(commission) + Data([blocked ? 1 : 0]))
            .toHex(includePrefix: true)
    }

    /// Hands the service a Staking.ActiveEra item (index, no start) as its storage subscription would.
    func deliverActiveEra(_ era: UInt32) {
        let item = ChainStorageItem(identifier: "legacy-era-stakers-active-era", data: Self.eraBytes(era) + Data([0]))
        service.syncQueue.async { self.service.didUpdateActiveEraItem(item) }
    }

    func fetch(timeout: TimeInterval = 30) throws -> EraStakersInfo {
        let operation = service.fetchInfoOperation()
        let done = XCTestExpectation(description: "era stakers")
        operation.completionBlock = { done.fulfill() }
        manager.enqueue(operations: [operation], in: .transient)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: timeout), .completed)
        return try XCTUnwrap(operation.result).get()
    }
}

/// A node that lists stored keys by prefix (state_getKeysPaged) and answers state_queryStorageAt from SCALE values;
/// an unknown key reads as null, as on chain.
final class LegacyEraStakersNode: JSONRPCEngine {
    private let lock = NSLock()
    private var stored: [String: String]
    private var recordedMethods: [String] = []
    private var identifier: UInt16 = 0
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    init(values: [String: String]) {
        stored = values
    }

    var values: [String: String] {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
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
            let parameters = try params.map {
                try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? [Any] ?? []
            } ?? []
            lock.lock(); recordedMethods.append(method); lock.unlock()
            let values = self.values
            let object: Any
            switch method {
            case RPCMethod.getStorageKeysPaged:
                let prefix = (parameters.first as? String ?? "").lowercased()
                let offset = parameters.count > 2 ? parameters[2] as? String : nil
                object = values.keys.filter { key in key.hasPrefix(prefix) && (offset.map { key > $0 } ?? true) }.sorted()
            case RPCMethod.queryStorageAt:
                let keys = parameters.first as? [String] ?? []
                let changes: [[Any]] = keys.map { [$0, values[$0] as Any? ?? NSNull()] }
                object = [["block": Data(repeating: 0x42, count: 32).toHex(includePrefix: true), "changes": changes]]
            default:
                throw NSError(domain: "legacy-era-stakers-node", code: 1, userInfo: [NSLocalizedDescriptionKey: method])
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
        throw NSError(domain: "legacy-era-stakers-node", code: 2)
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

final class LegacyEraStakersRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    private let connection: ChainConnection
    private let runtime: RuntimeProviderProtocol

    init(connection: ChainConnection, runtime: RuntimeProviderProtocol) {
        self.connection = connection
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
