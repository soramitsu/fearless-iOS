import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovFBalSubstrateRepositories: SubstrateRepositoryFactoryProtocol {
    private(set) var stashRepositoryRequests = 0

    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem> {
        AnyDataProviderRepository(CovFRepository<ChainStorageItem>())
    }

    func createStashItemRepository() -> AnyDataProviderRepository<StashItem> {
        stashRepositoryRequests += 1
        return AnyDataProviderRepository(CovFRepository<StashItem>())
    }

    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject> {
        AnyDataProviderRepository(CovFRepository<SingleValueProviderObject>())
    }
}

final class CovFBalObservable<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func addObserver(_: AnyObject, deliverOn _: DispatchQueue, executing _: @escaping ([DataProviderChange<T>]) -> Void) {}
    func removeObserver(_: AnyObject) {}
}

final class CovFBalSubstrateProviders: SubstrateDataProviderFactoryProtocol {
    private(set) var stashAddresses: [String] = []

    func createStashItemProvider(for address: String) -> StreamableProvider<StashItem> {
        stashAddresses.append(address)
        return StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<StashItem>()),
            repository: AnyDataProviderRepository(CovFRepository<StashItem>()),
            observable: AnyDataProviderRepositoryObservable(CovFBalObservable<StashItem>()),
            operationManager: OperationManager()
        )
    }

    func createStorageProvider(for _: String) -> StreamableProvider<ChainStorageItem> {
        StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<ChainStorageItem>()),
            repository: AnyDataProviderRepository(CovFRepository<ChainStorageItem>()),
            observable: AnyDataProviderRepositoryObservable(CovFBalObservable<ChainStorageItem>()),
            operationManager: OperationManager()
        )
    }
}

final class CovFBalChild: StorageChildSubscribing {
    let remoteStorageKey: Data

    init(remoteStorageKey: Data) {
        self.remoteStorageKey = remoteStorageKey
    }

    func processUpdate(_: Data?, blockHash _: Data?) {}
}

final class CovFBalChildFactory: ChildSubscriptionFactoryProtocol {
    private let lock = NSLock()
    private var storedKeys: [Data] = []

    var remoteKeys: [Data] {
        lock.lock()
        defer { lock.unlock() }
        return storedKeys
    }

    func createEmptyHandlingSubscription(keys: SubscriptionStorageKeys) -> StorageChildSubscribing {
        lock.lock()
        storedKeys.append(keys.remote)
        lock.unlock()
        return CovFBalChild(remoteStorageKey: keys.remote)
    }
}

final class CovFBalStakingHarness {
    let registry = CovFBalRegistry()
    let engine = CovFBalEngine()
    let logger = CovFBalLogger()
    let repositories = CovFBalSubstrateRepositories()
    let providers = CovFBalSubstrateProviders()
    let children = CovFBalChildFactory()
    let accountId = Data(repeating: 5, count: 32)
    let chainAsset = CovFBalChains.chainAsset()

    init(runtime: Bool) throws {
        if runtime {
            registry.runtime = try CovFBalRuntime.make()
        }
        registry.connection = engine
    }

    func staking() -> StakingAccountUpdatingService {
        StakingAccountUpdatingService(
            chainRegistry: registry,
            substrateRepositoryFactory: repositories,
            substrateDataProviderFactory: providers,
            childSubscriptionFactory: children,
            operationQueue: OperationQueue(),
            logger: logger
        )
    }

    func pool() -> PoolStakingAccountUpdatingService {
        PoolStakingAccountUpdatingService(
            chainRegistry: registry,
            substrateRepositoryFactory: repositories,
            substrateDataProviderFactory: providers,
            childSubscriptionFactory: children,
            operationQueue: OperationQueue(),
            logger: logger
        )
    }

    /// Every recorded subscription has exactly the given storage items, keyed by `accountId`.
    func assertSubscriptions(items: [(String, String)], file: StaticString = #filePath, line: UInt = #line) throws {
        let prefixes = try items.map { try CovFBalRuntime.prefix($0.0, $0.1) }
        for keys in engine.subscribedKeys {
            XCTAssertEqual(keys.count, prefixes.count, file: file, line: line)
            for (key, prefix) in zip(keys, prefixes) {
                XCTAssertTrue(key.hasPrefix(prefix), "\(key) is not under \(prefix)", file: file, line: line)
                XCTAssertTrue(key.hasSuffix(accountId.toHex()), "\(key) is not keyed by the account", file: file, line: line)
            }
        }
    }
}

final class CovFBalStakingUpdatingTests: XCTestCase {
    func testStakingSetupSubscribesToControllerAndLedgerAndClearingEndsIt() throws {
        let harness = try CovFBalStakingHarness(runtime: true)
        let service = harness.staking()
        let address = try harness.accountId.toAddress(using: .substrate(42))

        try service.setupSubscription(
            for: harness.accountId, chainAsset: harness.chainAsset, chainFormat: .substrate(42), stakingType: .relaychain
        )

        XCTAssertEqual(harness.repositories.stashRepositoryRequests, 1)
        XCTAssertEqual(harness.providers.stashAddresses, [address])
        XCTAssertEqual(harness.registry.runtimeRequests, [harness.chainAsset.chain.chainId, harness.chainAsset.chain.chainId])
        XCTAssertTrue(covFBalEventually { harness.engine.subscribedKeys.count == 2 })
        XCTAssertTrue(covFBalEventually { harness.engine.unsubscribed.count == 1 })
        try harness.assertSubscriptions(items: [("Staking", "Bonded"), ("Staking", "Ledger")])
        XCTAssertTrue(covFBalEventually { harness.children.remoteKeys.count == 4 })

        service.clearSubscription()

        XCTAssertTrue(covFBalEventually { harness.engine.unsubscribed.count == 2 })
        XCTAssertEqual(harness.engine.subscribedKeys.count, 2)
    }

    func testStakingSetupWithoutRuntimeReportsBothResolutionsAndSubscribesNothing() throws {
        let harness = try CovFBalStakingHarness(runtime: false)
        let service = harness.staking()

        try service.setupSubscription(
            for: harness.accountId, chainAsset: harness.chainAsset, chainFormat: .substrate(42), stakingType: .relaychain
        )
        covFBalSettle(0.1)

        XCTAssertEqual(harness.registry.runtimeRequests.count, 2)
        XCTAssertEqual(harness.logger.errors.filter { $0.contains("Did receive error") }.count, 2)
        XCTAssertTrue(harness.engine.subscribedKeys.isEmpty)

        service.clearSubscription()
        XCTAssertTrue(harness.engine.unsubscribed.isEmpty)
    }

    func testPoolSetupSubscribesToPoolMembershipAndClearingEndsIt() throws {
        let harness = try CovFBalStakingHarness(runtime: true)
        let service = harness.pool()

        try service.setupSubscription(
            for: harness.accountId, chainAsset: harness.chainAsset, chainFormat: .substrate(42), stakingType: .relaychain
        )

        XCTAssertEqual(harness.registry.runtimeRequests.count, 2)
        XCTAssertTrue(covFBalEventually { harness.engine.subscribedKeys.count == 2 })
        XCTAssertTrue(covFBalEventually { harness.engine.unsubscribed.count == 1 })
        try harness.assertSubscriptions(items: [("NominationPools", "PoolMembers")])
        XCTAssertTrue(covFBalEventually { harness.children.remoteKeys.count == 2 })
        XCTAssertEqual(
            harness.children.remoteKeys.map { $0.toHex(includePrefix: true) },
            harness.engine.subscribedKeys.flatMap { $0 }
        )
        XCTAssertEqual(harness.repositories.stashRepositoryRequests, 0)
        XCTAssertTrue(harness.providers.stashAddresses.isEmpty)

        service.clearSubscription()

        XCTAssertTrue(covFBalEventually { harness.engine.unsubscribed.count == 2 })
    }

    func testPoolSetupWithoutRuntimeReportsBothAttempts() throws {
        let harness = try CovFBalStakingHarness(runtime: false)
        let service = harness.pool()

        try service.setupSubscription(
            for: harness.accountId, chainAsset: harness.chainAsset, chainFormat: .substrate(42), stakingType: .relaychain
        )
        covFBalSettle(0.1)

        XCTAssertEqual(harness.registry.runtimeRequests.count, 2)
        XCTAssertEqual(harness.logger.errors.filter { $0.contains("unexpected error") }.count, 2)
        XCTAssertTrue(harness.engine.subscribedKeys.isEmpty)

        service.clearSubscription()
        XCTAssertTrue(harness.engine.unsubscribed.isEmpty)
    }
}
