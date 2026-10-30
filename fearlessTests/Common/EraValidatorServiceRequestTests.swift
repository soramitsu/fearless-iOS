import RobinHood
import SSFModels
import SSFRuntimeCodingService
import XCTest
@testable import fearless

final class EraValidatorServiceRequestTests: XCTestCase {
    func testSetupSubscribesOnceToChainQualifiedActiveEraStorage() throws {
        let fixture = try Fixture()
        fixture.service.setup()
        fixture.service.setup()
        fixture.drain()
        let key = try LocalStorageKeyFactory().createFromStoragePath(.activeEra, chainId: fixture.chain.chainId)
        XCTAssertEqual(fixture.provider.storageKeys, [key])
    }

    func testActiveEraTracksTheLatestReceivedIndex() throws {
        let fixture = try Fixture()
        fixture.service.syncQueue.sync {
            fixture.service.didReceiveActiveEra(3)
            fixture.service.didReceiveActiveEra(4)
        }
        XCTAssertEqual(fixture.service.activeEra, 4)
    }

    func testNewSnapshotReplacesThePreviousCachedEra() throws {
        let fixture = try Fixture()
        fixture.service.syncQueue.sync {
            fixture.service.didReceiveSnapshot(EraStakersInfo(activeEra: 7, validators: []))
        }
        XCTAssertEqual(try fixture.fetch().activeEra, 7)
        fixture.service.syncQueue.sync {
            fixture.service.didReceiveSnapshot(EraStakersInfo(activeEra: 8, validators: []))
        }
        XCTAssertEqual(try fixture.fetch().activeEra, 8)
    }

    func testSnapshotOfAnotherEraIsNotServedForTheActiveEra() throws {
        let fixture = try Fixture(requestTimeout: 0.05)
        fixture.service.syncQueue.sync {
            fixture.service.didReceiveActiveEra(9)
            fixture.service.didReceiveSnapshot(EraStakersInfo(activeEra: 8, validators: []))
        }
        XCTAssertThrowsError(try fixture.fetch()) { error in
            guard case EraValidatorServiceError.requestTimedOut = error else { return XCTFail("Unexpected \(error)") }
        }
    }

    func testMissingSnapshotTimesOutInsteadOfLeavingFetchOperationExecuting() throws {
        let fixture = try Fixture(requestTimeout: 0.05)
        XCTAssertThrowsError(try fixture.fetch()) { error in
            guard case EraValidatorServiceError.requestTimedOut = error else { return XCTFail("Unexpected \(error)") }
        }
    }

    func testFailureReachesWaitingRequestAndRecoveryDeliversNewEra() throws {
        let fixture = try Fixture()
        let error = NSError(domain: "era-runtime", code: 42)
        let waiting = fixture.service.fetchInfoOperation()
        let done = XCTestExpectation(description: "waiting request completes")
        waiting.completionBlock = { done.fulfill() }
        fixture.manager.enqueue(operations: [waiting], in: .transient)
        fixture.service.syncQueue.sync {
            fixture.service.didReceiveSnapshot(EraStakersInfo(activeEra: 7, validators: []))
        }
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 30), .completed)
        XCTAssertEqual(try XCTUnwrap(waiting.result).get().activeEra, 7)

        fixture.service.syncQueue.sync { fixture.service.didFail(error) }
        XCTAssertThrowsError(try fixture.fetch()) { XCTAssertEqual($0 as NSError, error) }
        fixture.service.syncQueue.sync {
            fixture.service.didReceiveActiveEra(8)
            fixture.service.didReceiveSnapshot(EraStakersInfo(activeEra: 8, validators: []))
        }
        XCTAssertEqual(try fixture.fetch().activeEra, 8)
    }

    func testFailureIsReportedOnceThenTheNextRequestWaitsForFreshData() throws {
        let fixture = try Fixture(requestTimeout: 0.05)
        let error = NSError(domain: "era-runtime", code: 42)
        fixture.service.syncQueue.sync { fixture.service.didFail(error) }
        XCTAssertThrowsError(try fixture.fetch()) { XCTAssertEqual($0 as NSError, error) }
        XCTAssertThrowsError(try fixture.fetch()) { error in
            guard case EraValidatorServiceError.requestTimedOut = error else { return XCTFail("Unexpected \(error)") }
        }
    }

    func testFailureOfAReplacedReadKeepsTheNewerSnapshot() throws {
        let fixture = try Fixture()
        let error = NSError(domain: "era-read", code: 1)
        fixture.service.syncQueue.sync {
            let replaced = fixture.service.beginActiveEraRead()
            _ = fixture.service.beginActiveEraRead()
            fixture.service.didReceiveSnapshot(EraStakersInfo(activeEra: 5, validators: []))
            fixture.service.didFail(error, read: replaced)
        }
        XCTAssertEqual(try fixture.fetch().activeEra, 5)
    }

    func testFailureOfTheCurrentReadIsReported() throws {
        let fixture = try Fixture()
        let error = NSError(domain: "era-read", code: 2)
        fixture.service.syncQueue.sync {
            let current = fixture.service.beginActiveEraRead()
            fixture.service.didFail(error, read: current)
        }
        XCTAssertThrowsError(try fixture.fetch()) { XCTAssertEqual($0 as NSError, error) }
    }

    func testRequestAfterAFailedReadReadsTheActiveEraAgainOncePerTimeout() throws {
        let registry = CountingRegistry()
        let fixture = try Fixture(registry: registry)
        let key = try LocalStorageKeyFactory().createFromStoragePath(.activeEra, chainId: fixture.chain.chainId)
        let repository: CoreDataRepository<ChainStorageItem, fearless.CDChainStorageItem> = fixture.facade.createRepository()
        let save = repository.saveOperation({ [ChainStorageItem(identifier: key, data: Data([1, 0, 0, 0, 0]))] }, { [] })
        OperationQueue().addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()

        fixture.service.setup()
        // The subscription delivers the stored era; reading it fails because no runtime is available.
        wait(for: [registry.expectation(atLeast: 1)], timeout: 30)
        fixture.drain()

        XCTAssertThrowsError(try fixture.fetch()) { error in
            guard case ChainRegistryError.runtimeMetadaUnavailable = error else { return XCTFail("Unexpected \(error)") }
        }
        wait(for: [registry.expectation(atLeast: 2)], timeout: 30)
        fixture.drain()
        XCTAssertThrowsError(try fixture.fetch(), "The read that followed failed again and is reported once")
        fixture.drain()
        XCTAssertEqual(registry.runtimeRequests, 2, "Another read waits for the request timeout")
    }

    private final class CountingRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
        private let lock = NSLock()
        private var requests = 0

        var runtimeRequests: Int {
            lock.lock(); defer { lock.unlock() }
            return requests
        }

        override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
            lock.lock(); requests += 1; lock.unlock()
            return nil
        }

        func expectation(atLeast count: Int) -> XCTestExpectation {
            XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.runtimeRequests >= count }, object: nil)
        }
    }

    private final class ProviderFactory: SubstrateDataProviderFactoryProtocol {
        let underlying: SubstrateDataProviderFactory
        private(set) var storageKeys: [String] = []

        init(facade: StorageFacadeProtocol, manager: OperationManagerProtocol) {
            underlying = SubstrateDataProviderFactory(facade: facade, operationManager: manager)
        }

        func createStashItemProvider(for address: String) -> StreamableProvider<StashItem> {
            underlying.createStashItemProvider(for: address)
        }

        func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
            storageKeys.append(key)
            return underlying.createStorageProvider(for: key)
        }
    }

    private final class Fixture {
        let facade = SubstrateStorageTestFacade()
        let manager = OperationManager()
        let chain: ChainModel
        let provider: ProviderFactory
        let service: EraValidatorService

        init(requestTimeout: TimeInterval = 60, registry: ChainRegistryProtocol = ChainRegistryProtocolStub()) throws {
            chain = try XCTUnwrap(ChainModelGenerator.generate(count: 1).first)
            provider = ProviderFactory(facade: facade, manager: manager)
            service = EraValidatorService(
                chain: chain,
                storageFacade: facade,
                providerFactory: provider,
                operationManager: manager,
                eventCenter: EventCenterProtocolStub(),
                chainRegistry: registry,
                requestTimeout: requestTimeout
            )
        }

        func drain() { service.syncQueue.sync {} }

        func fetch() throws -> EraStakersInfo {
            let operation = service.fetchInfoOperation()
            let done = XCTestExpectation(description: "snapshot operation completes")
            operation.completionBlock = { done.fulfill() }
            manager.enqueue(operations: [operation], in: .transient)
            XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 30), .completed)
            return try XCTUnwrap(operation.result).get()
        }
    }
}
