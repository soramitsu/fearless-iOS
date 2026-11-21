import RobinHood
import SSFModels
import SSFNetwork
import XCTest
@testable import fearless

final class CovFRtHotBootBuilderTests: XCTestCase {
    func testStoredTypesChainsAndRuntimeStartHotProviderWithoutDownloads() throws {
        let chain = covFMiscChain(id: "covf-hot-a")
        let types = Data(#"{"runtime_id":1,"types":{}}"#.utf8)
        let fixture = try CovFRtHotBootFixture(
            storedTypes: try JSONEncoder().encode(["covf-hot-a": types]),
            chains: [chain],
            runtimes: [fearless.RuntimeMetadataItem(chain: "covf-hot-a", version: 7, txVersion: 2, metadata: Data([1]))]
        )
        fixture.builder.startHotBoot()
        try covFMiscEventually { fixture.pool.hotChains.count == 1 }
        XCTAssertEqual(fixture.pool.hotChains.first?.chain, "covf-hot-a")
        XCTAssertEqual(fixture.pool.hotChains.first?.types, types)
        XCTAssertEqual(fixture.pool.hotChains.first?.version, 7)
    }

    func testDownloadedTypesAndChainsAreUsedAndChainsSavedWhenNothingIsStored() throws {
        let chain = covFMiscChain(id: "covf-hot-b")
        let remoteTypes = try JSONSerialization.data(withJSONObject: [["chainId": "covf-hot-b", "types": [String: String]()]])
        let fixture = try CovFRtHotBootFixture(
            storedTypes: nil,
            chains: [],
            runtimes: [fearless.RuntimeMetadataItem(chain: "covf-hot-b", version: 3, txVersion: 1, metadata: Data([2]))],
            remote: [
                ApplicationConfig.shared.chainTypesSourceUrl: remoteTypes,
                ApplicationConfig.shared.chainsSourceUrl: try JSONEncoder().encode([chain])
            ]
        )
        fixture.builder.startHotBoot()
        try covFMiscEventually { fixture.pool.hotChains.count == 1 && fixture.chains.items.count == 1 }
        XCTAssertEqual(fixture.chains.items.first?.chainId, "covf-hot-b")
        let typesJSON = try JSONSerialization.jsonObject(with: try XCTUnwrap(fixture.pool.hotChains.first?.types)) as? [String: Any]
        XCTAssertEqual(typesJSON?["chainId"] as? String, "covf-hot-b")
        XCTAssertEqual(Set(fixture.network.requested), [ApplicationConfig.shared.chainTypesSourceUrl, ApplicationConfig.shared.chainsSourceUrl])
    }

    func testChainsWithoutRuntimeOrTypesAndUnreadableTypesStartNothing() throws {
        let known = covFMiscChain(id: "covf-hot-c")
        let fixture = try CovFRtHotBootFixture(
            storedTypes: try JSONEncoder().encode(["other": Data("{}".utf8)]),
            chains: [known, covFMiscChain(id: "covf-hot-d")],
            runtimes: [fearless.RuntimeMetadataItem(chain: "covf-hot-d", version: 1, txVersion: 1, metadata: Data())]
        )
        fixture.builder.startHotBoot()
        try covFMiscEventually { fixture.chains.fetches > 0 && fixture.runtimes.fetches > 0 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(fixture.pool.hotChains.isEmpty)

        let unreadable = try CovFRtHotBootFixture(
            storedTypes: Data("not json".utf8), chains: [known],
            runtimes: [fearless.RuntimeMetadataItem(chain: "covf-hot-c", version: 1, txVersion: 1, metadata: Data())]
        )
        unreadable.builder.startHotBoot()
        try covFMiscEventually { unreadable.runtimes.fetches > 0 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(unreadable.pool.hotChains.isEmpty)
    }

    func testRepositoryFailureStopsHotBoot() throws {
        let fixture = try CovFRtHotBootFixture(
            storedTypes: try JSONEncoder().encode(["covf-hot-e": Data("{}".utf8)]),
            chains: [covFMiscChain(id: "covf-hot-e")], runtimes: []
        )
        fixture.runtimes.failure = NSError(domain: "runtime-items", code: 1)
        fixture.builder.startHotBoot()
        try covFMiscEventually { fixture.runtimes.fetches > 0 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(fixture.pool.hotChains.isEmpty)
    }
}

private final class CovFRtHotBootFixture {
    let pool: CovFRtPool
    let chains: CovFRtCountingRepository<ChainModel>
    let runtimes: CovFRtCountingRepository<fearless.RuntimeMetadataItem>
    let network: CovFRtNetworkFactory
    let builder: SnapshotHotBootBuilder

    init(storedTypes: Data?, chains: [ChainModel], runtimes: [fearless.RuntimeMetadataItem], remote: [URL: Data] = [:]) throws {
        pool = CovFRtPool(runtime: try covFRtBareRuntime())
        self.chains = CovFRtCountingRepository(chains)
        self.runtimes = CovFRtCountingRepository(runtimes)
        network = CovFRtNetworkFactory(responses: remote)
        builder = SnapshotHotBootBuilder(
            runtimeProviderPool: pool,
            chainRepository: AnyDataProviderRepository(self.chains),
            filesOperationFactory: CovFRtStoredTypes(data: storedTypes),
            runtimeItemRepository: AnyDataProviderRepository(self.runtimes),
            dataOperationFactory: network,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }
}

final class CovFRtCountingRepository<T: RobinHood.Identifiable>: DataProviderRepositoryProtocol {
    private let base: CovFRepository<T>
    private let lock = NSLock()
    private var storedFetches = 0

    init(_ items: [T]) { base = CovFRepository(items) }

    var items: [T] { base.items }

    var fetches: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedFetches
    }

    var failure: Error? {
        get { base.failure }
        set { base.failure = newValue }
    }

    func fetchOperation(by ids: @escaping () throws -> [String], options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        base.fetchOperation(by: ids, options: options)
    }

    func fetchOperation(by id: @escaping () throws -> String, options: RepositoryFetchOptions) -> BaseOperation<T?> {
        base.fetchOperation(by: id, options: options)
    }

    func fetchAllOperation(with options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        lock.lock()
        storedFetches += 1
        lock.unlock()
        return base.fetchAllOperation(with: options)
    }

    func fetchOperation(by request: RepositorySliceRequest, options: RepositoryFetchOptions) -> BaseOperation<[T]> {
        base.fetchOperation(by: request, options: options)
    }

    func saveOperation(_ updates: @escaping () throws -> [T], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> {
        base.saveOperation(updates, deletes)
    }

    func saveBatchOperation(_ updates: @escaping () throws -> [T], _ deletes: @escaping () throws -> [String]) -> BaseOperation<Void> {
        saveOperation(updates, deletes)
    }

    func replaceOperation(_ items: @escaping () throws -> [T]) -> BaseOperation<Void> { base.replaceOperation(items) }
    func fetchCountOperation() -> BaseOperation<Int> { base.fetchCountOperation() }
    func deleteAllOperation() -> BaseOperation<Void> { base.deleteAllOperation() }
}

final class CovFRtPool: RuntimeProviderPoolProtocol {
    struct CovFRtHotChain {
        let chain: String
        let types: Data
        let version: UInt32
    }

    private let lock = NSLock()
    private let runtime: RuntimeProviderProtocol
    private var storedHot: [CovFRtHotChain] = []

    init(runtime: RuntimeProviderProtocol) { self.runtime = runtime }

    var hotChains: [CovFRtHotChain] {
        lock.lock()
        defer { lock.unlock() }
        return storedHot
    }

    func setupRuntimeProvider(for _: ChainModel, chainTypes _: Data?) -> RuntimeProviderProtocol { runtime }

    func setupHotRuntimeProvider(for chain: ChainModel, runtimeItem: fearless.RuntimeMetadataItem, chainTypes: Data) -> RuntimeProviderProtocol {
        lock.lock()
        storedHot.append(CovFRtHotChain(chain: chain.chainId, types: chainTypes, version: runtimeItem.version))
        lock.unlock()
        return runtime
    }

    func destroyRuntimeProvider(for _: ChainModel.Id) {}
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
}

final class CovFRtNetworkFactory: NetworkOperationFactoryProtocol {
    private let lock = NSLock()
    private let responses: [URL: Data]
    private var storedRequests: [URL] = []

    init(responses: [URL: Data]) { self.responses = responses }

    var requested: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    func fetchData<T: Decodable>(from url: URL) -> BaseOperation<T> {
        lock.lock()
        storedRequests.append(url)
        lock.unlock()
        let operation = BaseOperation<T>()
        if let data = responses[url] as? T {
            operation.result = .success(data)
        } else {
            operation.result = .failure(NSError(domain: "covf.network", code: 404))
        }
        return operation
    }
}

final class CovFRtStoredTypes: RuntimeFilesOperationFactoryProtocol {
    private let data: Data?
    private let empty = CovFRtNoFiles()

    init(data: Data?) { self.data = data }

    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> { empty.fetchCommonTypesOperation() }
    func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?> { CompoundOperationWrapper(targetOperation: CovFFixtures.result(data)) }
    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> { empty.fetchChainTypesOperation(for: chainId) }
    func saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { empty.saveCommonTypesOperation(data: data) }
    func saveChainsTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> { empty.saveChainsTypesOperation(data: data) }
    func saveChainTypesOperation(for chainId: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        empty.saveChainTypesOperation(for: chainId, data: data)
    }
}
