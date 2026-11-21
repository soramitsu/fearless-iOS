import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// Staking replaces its services when the chain changes and throttles the old ones. Their `throttle()` returned
/// early while the service was running, so a throttled service kept running and kept its subscriptions.
final class RewardCalculatorServiceThrottleTests: XCTestCase {
    func testInflationServiceThrottleEndsItsSubscriptionSoSetupSubscribesAgain() throws {
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let providers = CountingStorageProviderFactory(facade: facade, manager: manager)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let service = InflationRewardCalculatorService(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            assetPrecision: 10,
            eraValidatorsService: SoraRewardServiceEraStub(),
            operationManager: manager,
            providerFactory: providers,
            chainRegistry: SoraRewardServiceRegistry(),
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade
        )

        service.setup()
        service.throttle()
        try drain(service)
        XCTAssertEqual(providers.createdKeys.count, 1)
        XCTAssertEqual(try isActive(service), false, "the throttled service stops")

        service.setup()
        try drain(service)
        XCTAssertEqual(providers.createdKeys.count, 2, "starting again subscribes again")
        XCTAssertEqual(try isActive(service), true)
    }

    func testPortionServiceThrottleStopsTheService() throws {
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("ksm", symbol: "KSM", assetPresicion: 12)
        let service = PortionRewardCalculatorService(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            assetPrecision: 12,
            eraValidatorsService: SoraRewardServiceEraStub(),
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: SoraRewardServiceRegistry(),
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade,
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: manager)
        )

        service.setup()
        try drain(service)
        XCTAssertEqual(try isActive(service), true)

        service.throttle()
        try drain(service)
        XCTAssertEqual(try isActive(service), false, "the throttled service stops")
    }

    func testSoraServiceThrottleStopsTheService() throws {
        let fixture = try SoraRewardServiceFixture(dexCount: 1)

        fixture.service.setup()
        try drain(fixture.service)
        XCTAssertEqual(try isActive(fixture.service), true)

        fixture.service.throttle()
        try drain(fixture.service)
        XCTAssertEqual(try isActive(fixture.service), false, "the throttled service stops")
    }

    // MARK: - Private

    /// Waits until the service's serial queue has run everything queued so far.
    private func drain(_ service: AnyObject) throws {
        let queue = try XCTUnwrap(Mirror(reflecting: service).descendant("syncQueue") as? DispatchQueue)
        queue.sync {}
    }

    private func isActive(_ service: AnyObject) throws -> Bool {
        try XCTUnwrap(Mirror(reflecting: service).descendant("isActive") as? Bool)
    }
}

final class CountingStorageProviderFactory: SubstrateDataProviderFactoryProtocol {
    private let underlying: SubstrateDataProviderFactory
    private let lock = NSLock()
    private var keys: [String] = []

    var createdKeys: [String] {
        lock.lock()
        defer { lock.unlock() }
        return keys
    }

    init(facade: fearless.StorageFacadeProtocol, manager: OperationManagerProtocol) {
        underlying = SubstrateDataProviderFactory(facade: facade, operationManager: manager)
    }

    func createStashItemProvider(for address: String) -> StreamableProvider<StashItem> {
        underlying.createStashItemProvider(for: address)
    }

    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
        lock.lock()
        keys.append(key)
        lock.unlock()
        return underlying.createStorageProvider(for: key)
    }
}
