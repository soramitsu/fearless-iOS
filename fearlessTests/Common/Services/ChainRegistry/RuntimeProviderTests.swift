import XCTest
@testable import fearless
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

final class RuntimeProviderTests: XCTestCase {
    func testSetupBuildsSnapshotAndResolvesCoderFactory() throws {
        let fixture = try makeProvider()
        let readyExpectation = expectation(description: "Runtime snapshot ready")

        fixture.eventCenter.onNotify = { (event: EventProtocol) in
            guard event is RuntimeSnapshotReady else {
                return
            }

            readyExpectation.fulfill()
        }

        fixture.provider.setup()

        wait(for: [readyExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.snapshotFactory.calls.count, 1)
        XCTAssertEqual(fixture.snapshotFactory.calls.first?.chainTypes, fixture.chainTypes)
        XCTAssertEqual(fixture.snapshotFactory.calls.first?.chainMetadata, fixture.metadataItem)
        XCTAssertNotNil(fixture.provider.runtimeSnapshot)

        let fetchOperation = fixture.provider.fetchCoderFactoryOperation()
        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let coderFactory = try XCTUnwrap(fetchOperation.result?.get())
        XCTAssertEqual(coderFactory.specVersion, fixture.metadataItem.version)
        XCTAssertEqual(coderFactory.txVersion, fixture.metadataItem.txVersion)
    }

    func testMetadataSyncCompletionRebuildsSnapshotForMatchingChain() throws {
        let fixture = try makeProvider()
        let setupExpectation = expectation(description: "Initial runtime snapshot ready")

        fixture.eventCenter.onNotify = { (event: EventProtocol) in
            guard event is RuntimeSnapshotReady else {
                return
            }

            setupExpectation.fulfill()
        }

        fixture.provider.setup()
        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        let rebuildExpectation = expectation(description: "Runtime snapshot rebuilt")
        fixture.eventCenter.onNotify = { (event: EventProtocol) in
            guard event is RuntimeSnapshotReady else {
                return
            }

            rebuildExpectation.fulfill()
        }

        let syncedMetadata = makeRuntimeMetadataItem(
            chainId: fixture.chain.chainId,
            version: fixture.metadataItem.version + 1,
            txVersion: fixture.metadataItem.txVersion + 1
        )

        fixture.provider.processRuntimeChainMetadataSyncCompleted(
            event: RuntimeMetadataSyncCompleted(
                chainId: fixture.chain.chainId,
                version: RuntimeVersion(
                    specVersion: syncedMetadata.version,
                    transactionVersion: syncedMetadata.txVersion
                ),
                metadata: syncedMetadata
            )
        )

        wait(for: [rebuildExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.snapshotFactory.calls.map { $0.chainMetadata.version }, [
            fixture.metadataItem.version,
            syncedMetadata.version
        ])
        XCTAssertEqual(fixture.provider.runtimeSnapshot?.specVersion, syncedMetadata.version)
        XCTAssertEqual(fixture.provider.runtimeSnapshot?.txVersion, syncedMetadata.txVersion)
    }

    func testChainTypesSyncRebuildsOnlyWhenRuntimeIdChanges() throws {
        let chainTypes = try makeChainTypes(runtimeId: 1)
        let fixture = try makeProvider(chainTypes: chainTypes)
        let readyExpectation = expectation(description: "Runtime snapshots ready")
        readyExpectation.expectedFulfillmentCount = 2

        fixture.eventCenter.onNotify = { (event: EventProtocol) in
            guard event is RuntimeSnapshotReady else {
                return
            }

            readyExpectation.fulfill()
        }

        fixture.provider.setup()
        fixture.provider.processRuntimeChainsTypesSyncCompleted(
            event: RuntimeChainsTypesSyncCompleted(
                versioningMap: [fixture.chain.chainId: try makeChainTypes(runtimeId: 1)]
            )
        )
        fixture.provider.processRuntimeChainsTypesSyncCompleted(
            event: RuntimeChainsTypesSyncCompleted(
                versioningMap: [fixture.chain.chainId: try makeChainTypes(runtimeId: 2)]
            )
        )

        wait(for: [readyExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(fixture.snapshotFactory.calls.count, 2)
        XCTAssertEqual(fixture.snapshotFactory.calls.first?.chainTypes, try makeChainTypes(runtimeId: 1))
        XCTAssertEqual(fixture.snapshotFactory.calls.last?.chainTypes, try makeChainTypes(runtimeId: 2))
    }
}

private extension RuntimeProviderTests {
    typealias Fixture = (
        provider: fearless.RuntimeProvider,
        chain: ChainModel,
        metadataItem: fearless.RuntimeMetadataItem,
        chainTypes: Data,
        snapshotFactory: RuntimeSnapshotFactoryStub,
        eventCenter: RecordingRuntimeProviderEventCenter
    )

    func makeProvider(
        chainTypes: Data? = nil,
        metadataItem: fearless.RuntimeMetadataItem? = nil
    ) throws -> Fixture {
        let chain = ChainModelGenerator.generate(count: 1, withTypes: true).first!
        let resolvedChainTypes: Data
        if let chainTypes {
            resolvedChainTypes = chainTypes
        } else {
            resolvedChainTypes = try makeChainTypes(runtimeId: 1)
        }
        let metadataItem = metadataItem ?? makeRuntimeMetadataItem(chainId: chain.chainId)
        let storageFacade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<fearless.RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let snapshotFactory = try RuntimeSnapshotFactoryStub()
        let eventCenter = RecordingRuntimeProviderEventCenter()
        let provider = fearless.RuntimeProvider(
            chainModel: chain,
            snapshotOperationFactory: snapshotFactory,
            snapshotHotOperationFactory: nil,
            eventCenter: eventCenter,
            operationQueue: OperationQueue(),
            repository: AnyDataProviderRepository(repository),
            usedRuntimePaths: [:],
            chainMetadata: metadataItem,
            chainTypes: resolvedChainTypes
        )

        return (provider, chain, metadataItem, resolvedChainTypes, snapshotFactory, eventCenter)
    }

    func makeRuntimeMetadataItem(
        chainId: ChainModel.Id,
        version: UInt32 = 10,
        txVersion: UInt32 = 3
    ) -> fearless.RuntimeMetadataItem {
        fearless.RuntimeMetadataItem(
            chain: chainId,
            version: version,
            txVersion: txVersion,
            metadata: Data([0x01, 0x02, 0x03])
        )
    }

    func makeChainTypes(runtimeId: UInt32) throws -> Data {
        let json: JSON = .dictionaryValue(["runtime_id": .unsignedIntValue(UInt64(runtimeId))])
        return try JSONEncoder().encode(json)
    }
}

private final class RuntimeSnapshotFactoryStub: fearless.RuntimeSnapshotFactoryProtocol {
    struct Call {
        let chainTypes: Data
        let chainMetadata: fearless.RuntimeMetadataItem
        let usedRuntimePaths: [String: [String]]
    }

    private let metadata: RuntimeMetadata
    private let catalog: TypeRegistryCatalogProtocol
    private let lock = NSLock()
    private(set) var calls: [Call] = []

    init() throws {
        metadata = try RuntimeMetadata(
            wrapping: RuntimeMetadataProtocolStub(),
            metaReserved: 0,
            version: 0
        )
        catalog = TypeRegistryCatalogStub()
    }

    func createRuntimeSnapshotWrapper(
        chainTypes: Data,
        chainMetadata: fearless.RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        lock.lock()
        calls.append(
            Call(
                chainTypes: chainTypes,
                chainMetadata: chainMetadata,
                usedRuntimePaths: usedRuntimePaths
            )
        )
        lock.unlock()

        return ClosureOperation<RuntimeSnapshot?> {
            RuntimeSnapshot(
                typeRegistryCatalog: self.catalog,
                specVersion: chainMetadata.version,
                txVersion: chainMetadata.txVersion,
                metadata: self.metadata
            )
        }
    }
}

private final class TypeRegistryCatalogStub: TypeRegistryCatalogProtocol {
    func node(for _: String, version _: UInt64) -> Node? {
        nil
    }

    func override(for _: String, constantName _: String, version _: UInt64) -> String? {
        nil
    }

    func replacingRuntimeMetadata(
        _: RuntimeMetadata,
        usedRuntimePaths _: [String: [String]]
    ) throws -> TypeRegistryCatalogProtocol {
        self
    }
}

private final class RuntimeMetadataProtocolStub: RuntimeMetadataProtocol {
    let schema: Schema? = nil
    let modules: [RuntimeModuleMetadata] = []
    let extrinsic: RuntimeExtrinsicMetadata = RuntimeMetadataV1.ExtrinsicMetadata(
        version: 0,
        signedExtensions: []
    )

    init() {}

    required init(scaleDecoder _: ScaleDecoding) throws {}

    func encode(scaleEncoder _: ScaleEncoding) throws {}
}

private final class RecordingRuntimeProviderEventCenter: EventCenterProtocol {
    private(set) var observers: [EventVisitorProtocol] = []
    var onNotify: ((EventProtocol) -> Void)?

    func notify(with event: EventProtocol) {
        onNotify?(event)
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        observers.append(observer)
    }

    func remove(observer: EventVisitorProtocol) {
        observers.removeAll { $0 === observer }
    }
}
