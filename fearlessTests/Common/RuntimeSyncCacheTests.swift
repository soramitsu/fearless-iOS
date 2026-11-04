import XCTest
import RobinHood
import SSFModels
import SSFUtils
@testable import fearless

final class RuntimeSyncCacheTests: XCTestCase {
    func testMatchingCachedMetadataReadiesRecreatedProviderWithoutRemoteFetch() throws {
        let fixture = try Fixture(cachedVersionOffset: 0, cachedTransactionOffset: 0)
        defer { fixture.service.unregister(chainId: fixture.chain.chainId) }
        let ready = expectation(description: "cached runtime replay reaches new provider")
        let observer = Observer()
        observer.snapshot = { event in
            guard event.chainModel.chainId == fixture.chain.chainId else { return }
            ready.fulfill()
        }
        fixture.events.add(observer: observer, dispatchIn: .global())
        let provider = fearless.RuntimeProviderFactory(
            fileOperationFactory: RuntimeFilesOperationFactoryProtocolStub(), repository: fixture.repository,
            dataOperationFactory: DataOperationFactoryProtocolStub(), eventCenter: fixture.events,
            operationQueue: OperationQueue()
        ).createRuntimeProvider(for: fixture.chain, chainTypes: try XCTUnwrap(AssetHubStakingRoute.runtimeTypes(for: fixture.chain.chainId, existing: nil)), usedRuntimePaths: [:])
        provider.setup()
        XCTAssertNil(provider.snapshot)
        fixture.service.apply(version: fixture.version, for: fixture.chain.chainId)
        wait(for: [ready], timeout: 30)
        XCTAssertEqual(provider.snapshot?.specVersion, fixture.version.specVersion)
        XCTAssertEqual(provider.snapshot?.txVersion, fixture.version.transactionVersion)
        XCTAssertTrue(fixture.connection.requests.isEmpty)
        provider.cleanup()
        withExtendedLifetime(observer) {}
    }

    func testChangedSpecVersionFetchesCurrentMetadataInsteadOfReplayingStaleCache() throws {
        try verifyChangedVersion(cachedVersionOffset: -1, cachedTransactionOffset: 0)
    }

    func testChangedTransactionVersionFetchesCurrentMetadataInsteadOfReplayingStaleCache() throws {
        try verifyChangedVersion(cachedVersionOffset: 0, cachedTransactionOffset: -1)
    }

    private func verifyChangedVersion(cachedVersionOffset: Int, cachedTransactionOffset: Int) throws {
        let fixture = try Fixture(cachedVersionOffset: cachedVersionOffset, cachedTransactionOffset: cachedTransactionOffset)
        defer { fixture.service.unregister(chainId: fixture.chain.chainId) }
        let synced = expectation(description: "current metadata arrives")
        let observer = Observer()
        observer.metadata = { event in
            XCTAssertEqual(event.chainId, fixture.chain.chainId)
            XCTAssertEqual(event.metadata.version, fixture.version.specVersion)
            XCTAssertEqual(event.metadata.txVersion, fixture.version.transactionVersion)
            XCTAssertEqual(event.metadata.metadata, fixture.metadata)
            synced.fulfill()
        }
        fixture.events.add(observer: observer, dispatchIn: .global())
        fixture.service.apply(version: fixture.version, for: fixture.chain.chainId)
        wait(for: [synced], timeout: 30)
        XCTAssertEqual(fixture.connection.requests.map { $0.0 }, [RPCMethod.getRuntimeMetadata])
        withExtendedLifetime(observer) {}
    }

    private final class Observer: EventVisitorProtocol {
        var metadata: ((RuntimeMetadataSyncCompleted) -> Void)?
        var snapshot: ((RuntimeSnapshotReady) -> Void)?
        func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted) { metadata?(event) }
        func processRuntimeSnapshorReady(event: RuntimeSnapshotReady) { snapshot?(event) }
    }

    private final class Fixture {
        let chain: ChainModel
        let version: fearless.RuntimeVersion
        let metadata: Data
        let repository: AnyDataProviderRepository<fearless.RuntimeMetadataItem>
        let events = EventCenter()
        let connection: AssetHubStorageFixture
        let service: fearless.RuntimeSyncService
        let storage = SubstrateStorageTestFacade()

        init(cachedVersionOffset: Int, cachedTransactionOffset: Int) throws {
            connection = try AssetHubStorageFixture(name: "westend")
            chain = AssetHubTestSupport.makeAsset(chainId: connection.runtime.chainId).chain
            version = fearless.RuntimeVersion(specVersion: connection.runtime.factory.specVersion, transactionVersion: connection.runtime.factory.txVersion)
            let url = try XCTUnwrap(Bundle(for: RuntimeSyncCacheTests.self).url(forResource: "asset-hub-westend-metadata-v14", withExtension: ""))
            let hex = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
            metadata = try Data(hexStringSSF: hex)
            connection.metadataResponse = hex
            let underlying: CoreDataRepository<fearless.RuntimeMetadataItem, CDRuntimeMetadataItem> = storage.createRepository()
            repository = AnyDataProviderRepository(underlying)
            let item = fearless.RuntimeMetadataItem(chain: chain.chainId, version: UInt32(Int(version.specVersion) + cachedVersionOffset), txVersion: UInt32(Int(version.transactionVersion) + cachedTransactionOffset), metadata: metadata)
            let save = repository.saveOperation({ [item] }, { [] })
            OperationQueue().addOperations([save], waitUntilFinished: true)
            _ = try XCTUnwrap(save.result).get()
            service = fearless.RuntimeSyncService(
                repository: repository, filesOperationFactory: RuntimeFilesOperationFactoryProtocolStub(),
                dataOperationFactory: DataOperationFactoryProtocolStub(), eventCenter: events
            )
            service.register(chain: chain, with: connection)
        }
    }
}
