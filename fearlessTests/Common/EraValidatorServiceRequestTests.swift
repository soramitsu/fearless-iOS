import RobinHood
import SSFModels
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
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 5), .completed)
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

        init(requestTimeout: TimeInterval = 60) throws {
            chain = try XCTUnwrap(ChainModelGenerator.generate(count: 1).first)
            provider = ProviderFactory(facade: facade, manager: manager)
            service = EraValidatorService(
                chain: chain,
                storageFacade: facade,
                providerFactory: provider,
                operationManager: manager,
                eventCenter: EventCenterProtocolStub(),
                chainRegistry: ChainRegistryProtocolStub(),
                requestTimeout: requestTimeout
            )
        }

        func drain() { service.syncQueue.sync {} }

        func fetch() throws -> EraStakersInfo {
            let operation = service.fetchInfoOperation()
            let done = XCTestExpectation(description: "snapshot operation completes")
            operation.completionBlock = { done.fulfill() }
            manager.enqueue(operations: [operation], in: .transient)
            XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 5), .completed)
            return try XCTUnwrap(operation.result).get()
        }
    }
}
