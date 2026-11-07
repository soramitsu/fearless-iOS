import Cuckoo
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// Every owner of an engine subscription must end it on the node when it lets the subscription go.
/// `cancelForIdentifier` only withdraws a request that has not been answered, so before these owners used
/// `unsubsribe` each case below left an established subscription running on the scripted SORA node and its
/// handler registered in the engine.
final class SubscriptionOwnerUnsubscribeTests: XCTestCase {
    private static let stakingTimeout: TimeInterval = 15

    // MARK: Storage subscription container

    func testStorageSubscriptionContainerEndsItsSubscriptionWhenReleased() {
        let connection = ScriptedSubstrateConnection()
        let child = RecordingStorageChild(remoteStorageKey: Data(repeating: 0x01, count: 32))
        var container: StorageSubscriptionContainer? = StorageSubscriptionContainer(
            engine: connection.engine,
            children: [child],
            logger: Logger.shared
        )

        connection.waitUntil("the node confirms the subscription") { connection.deliveredRemoteIds == ["sub-1"] }
        connection.node.produceBlock()
        connection.waitUntil("the first block reaches the child") { child.updates.count == 1 }
        XCTAssertNotNil(container)

        container = nil

        connection.waitUntil("the node ends the subscription") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)

        connection.node.produceBlock()
        connection.settle()
        XCTAssertEqual(child.updates.count, 1, "no block arrives after the container is released")
    }

    // MARK: WebSocket provider source

    func testWebSocketProviderSourceEndsItsSubscriptionWhenReleased() throws {
        let connection = ScriptedSubstrateConnection()
        let key = Data(repeating: 0x02, count: 32)
        let triggerDelegate = CountingTriggerDelegate()
        let trigger = DataProviderProxyTrigger()
        trigger.delegate = triggerDelegate
        var source: WebSocketProviderSource<CrowdloanFunds>? = try WebSocketProviderSource(
            itemIdentifier: "crowdloan-funds",
            codingPath: .crowdloanFunds,
            keyOperationClosure: { _ in ClosureOperation { [key] } },
            runtimeService: Self.runtime(),
            engine: connection.engine,
            trigger: trigger,
            operationManager: OperationManager()
        )

        connection.waitUntil("the node confirms the subscription", timeout: Self.stakingTimeout) {
            connection.deliveredRemoteIds == ["sub-1"]
        }
        connection.node.produceBlock()
        connection.waitUntil("the first block reaches the source") { triggerDelegate.count == 1 }
        XCTAssertNotNil(source)

        source = nil

        connection.waitUntil("the node ends the subscription") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)

        connection.node.produceBlock()
        connection.settle()
        XCTAssertEqual(triggerDelegate.count, 1, "no block arrives after the source is released")
    }

    // MARK: Spec version subscription

    func testSpecVersionSubscriptionEndsItsRuntimeVersionSubscription() {
        let connection = ScriptedSubstrateConnection()
        let syncService = RecordingRuntimeSyncService()
        let subscription = SpecVersionSubscription(
            chainId: "sora",
            runtimeSyncService: syncService,
            connection: connection.engine,
            logger: Logger.shared
        )

        subscription.subscribe()
        connection.waitUntil("the node confirms the subscription") { connection.deliveredRemoteIds == ["sub-1"] }
        connection.node.upgradeRuntime(specVersion: 2)
        connection.waitUntil("the upgrade reaches the sync service") { syncService.appliedSpecVersions == [2] }

        subscription.unsubscribe()

        connection.waitUntil("the node ends the subscription") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(
            connection.node.requests("state_unsubscribeRuntimeVersion").map(\.stringParams),
            [["sub-1"]],
            "the node ends a runtime version subscription only through its own unsubscribe method"
        )
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)

        connection.node.upgradeRuntime(specVersion: 3)
        connection.settle()
        XCTAssertEqual(syncService.appliedSpecVersions, [2], "no upgrade arrives after unsubscribing")
    }

    // MARK: Staking account subscription

    func testStakingAccountSubscriptionEndsTheOldSubscriptionOnAStashChangeAndTheLastOneWhenReleased() throws {
        let connection = ScriptedSubstrateConnection()
        let staking = try StakingFixture(connection: connection.makeChainConnection())
        let provider = SubstrateDataProviderFactory(
            facade: staking.storageFacade,
            operationManager: OperationManager()
        ).createStashItemProvider(for: staking.address)
        var subscription: StakingAccountSubscriptionV14? = StakingAccountSubscriptionV14(
            accountId: staking.accountId,
            chainAsset: staking.chainAsset,
            chainFormat: staking.chainFormat,
            chainRegistry: staking.chainRegistry,
            provider: provider,
            childSubscriptionFactory: RecordingChildSubscriptionFactory(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
        subscription?.resolveKeysAndSubscribe()

        // The provider may deliver the first stash item twice (initial fetch and save notification), so the
        // subscription IDs are not fixed: one subscription must run, and every replaced one must have ended.
        try staking.save(StashItem(stash: staking.address, controller: staking.address))
        connection.waitUntil("one stash subscription runs", timeout: Self.stakingTimeout) {
            connection.node.liveSubscriptions.count == 1
                && connection.deliveredRemoteIds == connection.node.liveSubscriptions
        }
        let first = connection.node.liveSubscriptions

        // The controller changes: StakingAccountSubscription resubscribes for the new keys.
        try staking.save(StashItem(stash: staking.address, controller: staking.otherAddress))
        connection.waitUntil("only the new stash subscription runs", timeout: Self.stakingTimeout) {
            connection.node.liveSubscriptions.count == 1
                && connection.node.liveSubscriptions != first
                && connection.deliveredRemoteIds == connection.node.liveSubscriptions
        }
        XCTAssertTrue(
            connection.node.requests("state_unsubscribeStorage").map(\.stringParams).contains(first),
            "the stash change ends the previous subscription on the node"
        )

        subscription = nil

        connection.waitUntil("the node ends the last subscription") { connection.node.liveSubscriptions.isEmpty }
        let opened = Set(connection.node.requests("state_subscribeStorage").indices.map { "sub-\($0 + 1)" })
        let ended = Set(connection.node.requests("state_unsubscribeStorage").flatMap(\.stringParams))
        XCTAssertEqual(ended, opened, "every subscription it opened was ended on the node")
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)
    }

    // MARK: Staking account resolver

    func testStakingAccountResolverKeepsOneSubscriptionAndEndsItWhenReleased() throws {
        let connection = ScriptedSubstrateConnection()
        let staking = try StakingFixture(connection: connection.makeChainConnection())
        var resolver: StakingAccountResolverV14? = StakingAccountResolverV14(
            accountId: staking.accountId,
            chainAsset: staking.chainAsset,
            chainFormat: staking.chainFormat,
            chainRegistry: staking.chainRegistry,
            childSubscriptionFactory: RecordingChildSubscriptionFactory(),
            operationQueue: OperationQueue(),
            repository: staking.repository,
            logger: Logger.shared
        )

        // StakingAccountUpdatingService resolves once more after init has.
        resolver?.resolveKeysAndSubscribe()

        connection.waitUntil("both resolutions subscribed and one subscription runs", timeout: Self.stakingTimeout) {
            connection.node.requests("state_subscribeStorage").count == 2
                && connection.node.liveSubscriptions == ["sub-2"]
                && connection.deliveredRemoteIds == ["sub-2"]
        }
        XCTAssertEqual(connection.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])

        resolver = nil

        connection.waitUntil("the node ends the subscription") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)
    }

    // MARK: Pool staking account subscription

    func testPoolStakingAccountSubscriptionKeepsOneSubscriptionAndEndsItWhenReleased() throws {
        let connection = ScriptedSubstrateConnection()
        let staking = try StakingFixture(connection: connection.makeChainConnection())
        var subscription: PoolStakingAccountSubscription? = PoolStakingAccountSubscription(
            accountId: staking.accountId,
            chainAsset: staking.chainAsset,
            chainFormat: staking.chainFormat,
            chainRegistry: staking.chainRegistry,
            childSubscriptionFactory: RecordingChildSubscriptionFactory(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        // PoolStakingAccountUpdatingService subscribes once more after init has.
        subscription?.subscribeRemote()

        connection.waitUntil("both calls subscribed and one subscription runs", timeout: Self.stakingTimeout) {
            connection.node.requests("state_subscribeStorage").count == 2
                && connection.node.liveSubscriptions == ["sub-2"]
                && connection.deliveredRemoteIds == ["sub-2"]
        }
        XCTAssertEqual(connection.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])

        subscription = nil

        connection.waitUntil("the node ends the subscription") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)
    }

    func testPoolStakingAccountSubscriptionEndsItOnTheConnectionThatOpenedIt() throws {
        let original = ScriptedSubstrateConnection()
        let replacement = ScriptedSubstrateConnection()
        let staking = try StakingFixture(connection: original.makeChainConnection())
        var subscription: PoolStakingAccountSubscription? = PoolStakingAccountSubscription(
            accountId: staking.accountId,
            chainAsset: staking.chainAsset,
            chainFormat: staking.chainFormat,
            chainRegistry: staking.chainRegistry,
            childSubscriptionFactory: RecordingChildSubscriptionFactory(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
        original.waitUntil("the subscription is confirmed", timeout: Self.stakingTimeout) {
            original.deliveredRemoteIds == ["sub-1"]
        }

        // ChainRegistry replaces a chain's connection when the chain's nodes change.
        staking.currentConnection = try replacement.makeChainConnection()
        subscription = nil

        original.waitUntil("the original node ends the subscription") { original.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(original.node.requests("state_unsubscribeStorage").map(\.stringParams), [["sub-1"]])
        XCTAssertEqual(original.registeredSubscriptionCount, 0)
        replacement.settle()
        XCTAssertTrue(replacement.node.requests.isEmpty, "the replacement connection never had this subscription")
        XCTAssertNil(subscription)
    }

    // MARK: Cross-chain dispatch watcher

    func testCrossChainDispatchWatcherEndsAnUnfinalizedWatchOnTheNode() async throws {
        let connection = ScriptedSubstrateConnection()
        let subscriptionId = try connection.submitAndWatch("0x00")
        let watcher = try ReviewedCrossChainDispatchWatcher(
            connection: connection.engine,
            runtime: Self.runtime(),
            timeout: 5
        )

        let outcome = Task { await watcher.outcome(subscriptionId: subscriptionId, extrinsicHash: Self.extrinsicHash) }
        connection.waitUntil("the watcher follows the extrinsic", timeout: 4) {
            connection.deliveredRemoteIds == [subscriptionId]
        }
        connection.node.reportExtrinsicStatus(["inBlock": Self.blockHash])

        // No finality within the timeout: the watcher reads the best block, which the node does not serve.
        let result = await outcome.value
        XCTAssertEqual(result, .unknown)

        connection.waitUntil("the node ends the watch") { connection.node.liveSubscriptions.isEmpty }
        XCTAssertEqual(connection.node.requests("author_unwatchExtrinsic").map(\.stringParams), [[subscriptionId]])
        connection.waitUntil("the engine drops the watcher") { connection.registeredSubscriptionCount == 0 }

        connection.node.reportExtrinsicStatus(["finalized": Self.blockHash])
        connection.settle()
        XCTAssertEqual(connection.registeredSubscriptionCount, 0)
    }

    func testCrossChainDispatchWatcherDropsItsWatcherAfterFinality() async throws {
        let connection = ScriptedSubstrateConnection()
        let subscriptionId = try connection.submitAndWatch("0x00")
        let watcher = try ReviewedCrossChainDispatchWatcher(
            connection: connection.engine,
            runtime: Self.runtime(),
            timeout: 60
        )

        let outcome = Task { await watcher.outcome(subscriptionId: subscriptionId, extrinsicHash: Self.extrinsicHash) }
        connection.waitUntil("the watcher follows the extrinsic") { connection.deliveredRemoteIds == [subscriptionId] }
        connection.node.reportExtrinsicStatus(["inBlock": Self.blockHash])
        connection.node.reportExtrinsicStatus(["finalized": Self.blockHash], isFinal: true)

        let result = await outcome.value
        XCTAssertEqual(result, .unknown, "the node does not serve the finalized block")

        connection.waitUntil("the engine drops the watcher") { connection.registeredSubscriptionCount == 0 }
        connection.settle()
        XCTAssertTrue(
            connection.node.requests("author_unwatchExtrinsic").isEmpty,
            "the node ended the watch itself after finality"
        )
    }

    // MARK: Fixtures

    private static let blockHash = "0x" + String(repeating: "ab", count: 32)
    private static let extrinsicHash = "0x" + String(repeating: "cd", count: 32)
    private static var cachedRuntime: AssetHubRuntimeFixture?

    /// Asset Hub Polkadot metadata: it has the Staking and NominationPools storage the staking owners encode keys for.
    private static func runtime() throws -> AssetHubRuntimeFixture {
        if let cachedRuntime {
            return cachedRuntime
        }
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        cachedRuntime = runtime
        return runtime
    }

    private final class StakingFixture {
        let accountId = Data(repeating: 0x11, count: 32)
        let otherAccountId = Data(repeating: 0x22, count: 32)
        let chainFormat = ChainFormat.substrate(0)
        let chainAsset: ChainAsset
        let chainRegistry = MockChainRegistryProtocol()
        let storageFacade = SubstrateStorageTestFacade()
        let repository: AnyDataProviderRepository<StashItem>
        private let lock = NSLock()
        private var connection: ChainConnection

        var currentConnection: ChainConnection {
            get {
                lock.lock()
                defer { lock.unlock() }
                return connection
            }
            set {
                lock.lock()
                connection = newValue
                lock.unlock()
            }
        }

        var address: String {
            (try? accountId.toAddress(using: chainFormat)) ?? ""
        }

        var otherAddress: String {
            (try? otherAccountId.toAddress(using: chainFormat)) ?? ""
        }

        init(connection: ChainConnection) throws {
            self.connection = connection
            let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
            chainAsset = ChainAsset(
                chain: chain,
                asset: ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
            )
            repository = SubstrateRepositoryFactory(storageFacade: storageFacade).createStashItemRepository()

            let runtime = try SubscriptionOwnerUnsubscribeTests.runtime()
            stub(chainRegistry) { stub in
                stub.getConnection(for: any()).then { [weak self] _ in self?.currentConnection }
                stub.getRuntimeProvider(for: any()).thenReturn(runtime)
            }
        }

        func save(_ stashItem: StashItem) throws {
            let operation = repository.saveOperation({ [stashItem] }, { [] })
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            if case let .failure(error) = operation.result {
                throw error
            }
        }
    }
}

private final class RecordingStorageChild: StorageChildSubscribing {
    let remoteStorageKey: Data
    private let lock = NSLock()
    private var received: [Data?] = []

    init(remoteStorageKey: Data) {
        self.remoteStorageKey = remoteStorageKey
    }

    var updates: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return received
    }

    func processUpdate(_ data: Data?, blockHash _: Data?) {
        lock.lock()
        received.append(data)
        lock.unlock()
    }
}

private final class RecordingChildSubscriptionFactory: ChildSubscriptionFactoryProtocol {
    func createEmptyHandlingSubscription(keys: SubscriptionStorageKeys) -> StorageChildSubscribing {
        RecordingStorageChild(remoteStorageKey: keys.remote)
    }
}

private final class CountingTriggerDelegate: DataProviderTriggerDelegate {
    private let tally = UpdateTally()

    var count: Int {
        tally.count
    }

    func didTrigger() {
        tally.add()
    }
}

private final class RecordingRuntimeSyncService: RuntimeSyncServiceProtocol {
    private let lock = NSLock()
    private var applied: [UInt32] = []

    var appliedSpecVersions: [UInt32] {
        lock.lock()
        defer { lock.unlock() }
        return applied
    }

    func register(chain _: ChainModel, with _: ChainConnection) {}

    func unregister(chainId _: ChainModel.Id) {}

    func apply(version: fearless.RuntimeVersion, for _: ChainModel.Id) {
        lock.lock()
        applied.append(version.specVersion)
        lock.unlock()
    }

    func hasChain(with _: ChainModel.Id) -> Bool {
        true
    }

    func isChainSyncing(_: ChainModel.Id) -> Bool {
        false
    }
}
