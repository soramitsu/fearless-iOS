import XCTest
@testable import fearless
import RobinHood
import SSFModels
import SSFNetwork
import SSFRuntimeCodingService
import SSFUtils

final class RuntimeSyncServiceTests: XCTestCase {
    func testRegisterAndUnregisterMaintainKnownChains() {
        let service = makeService().service
        let chains = ChainModelGenerator.generate(count: 6)

        chains.forEach { service.register(chain: $0, with: RuntimeMetadataConnection()) }

        XCTAssertTrue(chains.allSatisfy { service.hasChain(with: $0.chainId) })
        XCTAssertTrue(chains.allSatisfy { !service.isChainSyncing($0.chainId) })

        let removedChains = Array(chains.prefix(3))
        let remainingChains = Array(chains.suffix(3))

        removedChains.forEach { service.unregister(chainId: $0.chainId) }

        XCTAssertTrue(removedChains.allSatisfy { !service.hasChain(with: $0.chainId) })
        XCTAssertTrue(remainingChains.allSatisfy { service.hasChain(with: $0.chainId) })
        XCTAssertTrue(chains.allSatisfy { !service.isChainSyncing($0.chainId) })
    }

    func testApplyVersionFetchesStoresAndNotifiesRuntimeMetadata() throws {
        let fixture = makeService()
        let chain = ChainModelGenerator.generate(count: 1).first!
        let metadata = Data([0x01, 0x02, 0x03, 0x04])
        let version = RuntimeVersion(specVersion: 42, transactionVersion: 7)

        let eventExpectation = expectation(description: "Runtime metadata sync event")
        fixture.eventCenter.onNotify = { (event: EventProtocol) in
            guard let event = event as? RuntimeMetadataSyncCompleted else {
                return
            }

            XCTAssertEqual(event.chainId, chain.chainId)
            XCTAssertEqual(event.version.specVersion, version.specVersion)
            XCTAssertEqual(event.version.transactionVersion, version.transactionVersion)
            XCTAssertEqual(event.metadata.metadata, metadata)
            eventExpectation.fulfill()
        }

        fixture.service.register(
            chain: chain,
            with: RuntimeMetadataConnection(metadataHex: metadata.prefixedHexString)
        )

        fixture.service.apply(version: version, for: chain.chainId)

        wait(for: [eventExpectation], timeout: Constants.defaultExpectationDuration)

        let fetchOperation = fixture.repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let storedItem: fearless.RuntimeMetadataItem
        switch fetchOperation.result {
        case let .success(items):
            storedItem = try XCTUnwrap(items.first { $0.chain == chain.chainId })
        case let .failure(error):
            throw error
        case .none:
            XCTFail("Expected stored runtime metadata")
            return
        }

        XCTAssertEqual(storedItem.version, version.specVersion)
        XCTAssertEqual(storedItem.txVersion, version.transactionVersion)
        XCTAssertEqual(storedItem.metadata, metadata)
        XCTAssertFalse(fixture.service.isChainSyncing(chain.chainId))
    }

    func testSnapshotHotBootBuilderUsesInjectedConfigSource() {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRepository: CoreDataRepository<ChainModel, CDChain> = storageFacade.createRepository()
        let runtimeRepository: CoreDataRepository<fearless.RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let dataOperationFactory = CapturingNetworkOperationFactory()
        let operationQueue = OperationQueue()
        operationQueue.isSuspended = true
        defer {
            operationQueue.cancelAllOperations()
            operationQueue.isSuspended = false
        }
        let configSource = SnapshotHotBootConfigSourceStub(
            chainsSourceUrl: URL(string: "https://chains.example/chains.json")!,
            chainTypesSourceUrl: URL(string: "https://chains.example/types.json")!
        )

        let builder = SnapshotHotBootBuilder(
            runtimeProviderPool: RuntimeProviderPoolNoop(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            filesOperationFactory: RuntimeFilesOperationFactoryStub(),
            runtimeItemRepository: AnyDataProviderRepository(runtimeRepository),
            dataOperationFactory: dataOperationFactory,
            operationQueue: operationQueue,
            logger: Logger.shared,
            configSource: configSource
        )

        builder.startHotBoot()

        XCTAssertEqual(dataOperationFactory.requestedURLs, [
            configSource.chainTypesSourceUrl,
            configSource.chainsSourceUrl
        ])
    }
}

private extension RuntimeSyncServiceTests {
    typealias Fixture = (
        service: RuntimeSyncService,
        repository: CoreDataRepository<fearless.RuntimeMetadataItem, CDRuntimeMetadataItem>,
        eventCenter: RecordingEventCenter
    )

    func makeService() -> Fixture {
        let storageFacade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<fearless.RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let eventCenter = RecordingEventCenter()
        let service = RuntimeSyncService(
            repository: AnyDataProviderRepository(repository),
            filesOperationFactory: RuntimeFilesOperationFactoryStub(),
            dataOperationFactory: DataOperationFactoryStub(),
            eventCenter: eventCenter,
            maxConcurrentSyncRequests: 1
        )

        return (service, repository, eventCenter)
    }
}

private final class RuntimeMetadataConnection: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private var nextId: UInt16 = 1
    private let metadataHex: String

    init(metadataHex: String = "0x") {
        self.metadataHex = metadataHex
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let id = generateRequestId()

        guard method == RPCMethod.getRuntimeMetadata else {
            closure?(.failure(JSONRPCEngineError.clientCancelled))
            return id
        }

        if let metadata = metadataHex as? T {
            DispatchQueue.global().async {
                closure?(.success(metadata))
            }
        } else {
            DispatchQueue.global().async {
                closure?(.failure(JSONRPCEngineError.clientCancelled))
            }
        }

        return id
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
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}

    func generateRequestId() -> UInt16 {
        defer { nextId &+= 1 }
        return nextId
    }
}

private final class RuntimeFilesOperationFactoryStub: RuntimeFilesOperationFactoryProtocol {
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func fetchChainsTypesOperation() -> CompoundOperationWrapper<Data?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func fetchChainTypesOperation(for _: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func saveCommonTypesOperation(data _: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper.createWithResult(())
    }

    func saveChainsTypesOperation(data _: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper.createWithResult(())
    }

    func saveChainTypesOperation(
        for _: ChainModel.Id,
        data _: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper.createWithResult(())
    }
}

private final class DataOperationFactoryStub: DataOperationFactoryProtocol {
    func fetchData(from _: URL) -> BaseOperation<Data> {
        ClosureOperation<Data> {
            throw BaseOperationError.unexpectedDependentResult
        }
    }
}

private final class CapturingNetworkOperationFactory: NetworkOperationFactoryProtocol {
    private(set) var requestedURLs: [URL] = []

    func fetchData<T: Decodable>(from url: URL) -> BaseOperation<T> {
        requestedURLs.append(url)
        return ClosureOperation<T> {
            throw BaseOperationError.unexpectedDependentResult
        }
    }
}

private struct SnapshotHotBootConfigSourceStub: SnapshotHotBootConfigSource {
    let chainsSourceUrl: URL
    let chainTypesSourceUrl: URL
}

private final class RuntimeProviderPoolNoop: RuntimeProviderPoolProtocol {
    private let runtimeProvider = RuntimeProviderNoop()

    func setupRuntimeProvider(
        for _: ChainModel,
        chainTypes _: Data?
    ) -> RuntimeProviderProtocol {
        runtimeProvider
    }

    func setupHotRuntimeProvider(
        for _: ChainModel,
        runtimeItem _: fearless.RuntimeMetadataItem,
        chainTypes _: Data
    ) -> RuntimeProviderProtocol {
        runtimeProvider
    }

    func destroyRuntimeProvider(for _: ChainModel.Id) {}

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        nil
    }
}

private final class RuntimeProviderNoop: RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }
    var snapshot: RuntimeSnapshot?

    func setup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw NSError(domain: "RuntimeProviderNoop", code: 0)
    }

    func cleanup() {}

    func setupHot() {}

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation<RuntimeCoderFactoryProtocol> {
            throw NSError(domain: "RuntimeProviderNoop", code: 0)
        }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw NSError(domain: "RuntimeProviderNoop", code: 0)
    }
}

private final class RecordingEventCenter: EventCenterProtocol {
    var onNotify: ((EventProtocol) -> Void)?

    func notify(with event: EventProtocol) {
        onNotify?(event)
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

private extension Data {
    var prefixedHexString: String {
        "0x" + map { String(format: "%02x", $0) }.joined()
    }
}
