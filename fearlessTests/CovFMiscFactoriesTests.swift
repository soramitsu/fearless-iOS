import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovFMiscPhishingTests: XCTestCase {
    func testSetupEnqueuesDownloadThatReplacesStoredListAndThrottleCancelsIt() throws {
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> = SubstrateStorageTestFacade().createRepository()
        let manager = CovFMiscPhishingManager()
        let url = try XCTUnwrap(URL(string: "https://phishing.covf.invalid/all.json"))
        let service = GitHubPhishingAPIService(url: url, operationFactory: GitHubOperationFactory(), operationManager: manager, storage: storage)
        XCTAssertTrue(service.isThrottled)
        service.throttle()
        XCTAssertTrue(manager.enqueued.isEmpty)

        service.setup()
        XCTAssertFalse(service.isThrottled)
        XCTAssertEqual(manager.enqueued.count, 2)
        let network = try XCTUnwrap(manager.enqueued.first as? BaseOperation<[PhishingItem]>)
        let replace = try XCTUnwrap(manager.enqueued.last)
        XCTAssertTrue(replace.dependencies.contains(network))

        network.result = .success([PhishingItem(source: "covf", publicKey: "0xbad")])
        replace.removeDependency(network)
        OperationQueue().addOperations([replace], waitUntilFinished: true)
        let fetch = storage.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetch], waitUntilFinished: true)
        XCTAssertEqual(try XCTUnwrap(fetch.result).get().map(\.publicKey), ["0xbad"])

        service.setup()
        XCTAssertEqual(manager.enqueued.count, 2)
        service.throttle()
        XCTAssertTrue(service.isThrottled)
        XCTAssertTrue(network.isCancelled)
    }

    func testReplaceFailsWhenTheDownloadWasCancelled() throws {
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> = SubstrateStorageTestFacade().createRepository()
        let manager = CovFMiscPhishingManager()
        let service = GitHubPhishingAPIService(
            url: try XCTUnwrap(URL(string: "https://phishing.covf.invalid/all.json")),
            operationFactory: GitHubOperationFactory(), operationManager: manager, storage: storage
        )
        service.setup()
        service.throttle()
        let replace = try XCTUnwrap(manager.enqueued.last as? BaseOperation<Void>)
        manager.enqueued.dropLast().forEach { replace.removeDependency($0) }
        OperationQueue().addOperations([replace], waitUntilFinished: true)
        guard case .failure? = replace.result else {
            return XCTFail("Replacing without a download must fail")
        }
    }
}

final class CovFMiscFactoriesTests: XCTestCase {
    func testServiceFactoriesBuildTheProductionServicesWithoutStartingThem() {
        XCTAssertTrue(ScamSyncServiceFactory.createService() is ScamSyncService)
        XCTAssertTrue(GitHubPhishingServiceFactory.createService() is GitHubPhishingAPIService)
        XCTAssertTrue(PolkaswapSettingsFactory.createService() is PolkaswapSettingsSyncService)
    }

    func testBundledPolkaswapSettingsAreValidOnlyFromTheAppBundle() throws {
        let settings = try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings())
        XCTAssertFalse(settings.availableDexIds.isEmpty)
        XCTAssertFalse(settings.xstusdId.isEmpty)
        XCTAssertNil(PolkaswapSettingsFactory.bundledSettings(bundle: Bundle(for: CovFMiscFactoriesTests.self)))
    }

    func testChildSubscriptionFactoryCreatesEmptyHandlingSubscriptionForKeys() {
        let factory = ChildSubscriptionFactory(
            storageFacade: SubstrateStorageTestFacade(), operationManager: OperationManager(),
            eventCenter: CovFBalEventCenter(), logger: CovFBalLogger()
        )
        let subscription = factory.createEmptyHandlingSubscription(keys: SubscriptionStorageKeys(remote: Data([1, 2]), local: "covf-local"))
        let typed = subscription as? EmptyHandlingStorageSubscription<ChainStorageItem>
        XCTAssertEqual(typed?.remoteStorageKey, Data([1, 2]))
        XCTAssertEqual(typed?.localStorageKey, "covf-local")
    }

    func testBalanceLocksFactoryNeedsARegisteredChain() {
        XCTAssertNil(BalanceLocksFetchingFactory.buildBalanceLocksFetcher(for: CovFFixtures.asset()))
    }

    func testEquilibriumFactoryBuildsServiceForTheWallet() {
        let service = EquilibriumTotalBalanceServiceFactory.createService(
            wallet: AccountGenerator.generateMetaAccount(), chainAsset: CovFFixtures.asset(type: .equilibrium)
        )
        XCTAssertTrue(service is EquilibriumTotalBalanceService)
    }
}

private final class CovFMiscPhishingManager: OperationManagerProtocol {
    var enqueued: [Operation] = []
    func enqueue(operations: [Operation], in _: OperationMode) { enqueued.append(contentsOf: operations) }
}
