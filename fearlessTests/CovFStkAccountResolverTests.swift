import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

typealias CovFStkDecoded = BaseStakingAccountResolver.DecodedChanges

/// Exercises the shared resolver logic with a decoding step the test controls.
final class CovFStkResolver: BaseStakingAccountResolver {
    private let lock = NSLock()
    private var storedResolveCount = 0
    private var storedDecodedIds: [UInt16] = []
    private var storedChanges: BaseStakingAccountResolver.DecodedChanges?

    var resolveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedResolveCount
    }

    var decodedSubscriptionIds: [UInt16] {
        lock.lock()
        defer { lock.unlock() }
        return storedDecodedIds
    }

    /// `nil` makes decoding fail.
    var decodedChanges: BaseStakingAccountResolver.DecodedChanges? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedChanges
        }
        set {
            lock.lock()
            storedChanges = newValue
            lock.unlock()
        }
    }

    override func resolveKeysAndSubscribe() {
        lock.lock()
        storedResolveCount += 1
        lock.unlock()
    }

    override func createDecodingWrapper(
        from _: fearless.StorageUpdateData,
        subscription: BaseStakingAccountResolver.Subscription
    ) -> CompoundOperationWrapper<BaseStakingAccountResolver.DecodedChanges> {
        lock.lock()
        storedDecodedIds.append(subscription.subscriptionId)
        let changes = storedChanges
        lock.unlock()
        let operation = ClosureOperation<BaseStakingAccountResolver.DecodedChanges> {
            guard let changes = changes else {
                throw CovFStkError.stub("decoding")
            }
            return changes
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class CovFStkAccountResolverTests: XCTestCase {
    private let controllerKeys = SubscriptionStorageKeys(remote: Data([0xc1, 0x01]), local: "controller-local")
    private let ledgerKeys = SubscriptionStorageKeys(remote: Data([0x1e, 0x02]), local: "ledger-local")

    private func makeResolver(_ harness: CovFStkHarness) -> CovFStkResolver {
        CovFStkResolver(
            accountId: CovFStkFixtures.accountId,
            chainAsset: CovFStkFixtures.chainAsset,
            chainFormat: CovFStkFixtures.format,
            chainRegistry: harness.registry,
            childSubscriptionFactory: harness.factory,
            operationQueue: harness.queue,
            repository: AnyDataProviderRepository(harness.repository),
            logger: harness.logger
        )
    }

    private func stash(_ stash: Data, _ controller: Data) throws -> StashItem {
        try StashItem(stash: CovFStkFixtures.address(stash), controller: CovFStkFixtures.address(controller))
    }

    // MARK: Subscription lifecycle

    func testInitResolvesOnceAndUnsubscribeWithoutSubscriptionDoesNotReachTheNode() {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)

        XCTAssertEqual(resolver.resolveCount, 1)
        resolver.unsubscribe()

        XCTAssertTrue(harness.engine.unsubscribeAttempts.isEmpty)
        XCTAssertTrue(harness.logger.errors.isEmpty)
    }

    func testSubscribeRequestsBothKeysBuildsChildrenAndEndsTheSubscriptionOnce() {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)

        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        XCTAssertEqual(harness.engine.methods, [RPCMethod.storageSubscribe])
        XCTAssertEqual(harness.engine.params, [[
            controllerKeys.remote.toHex(includePrefix: true),
            ledgerKeys.remote.toHex(includePrefix: true)
        ]])
        XCTAssertEqual(harness.factory.children.map(\.remoteStorageKey), [controllerKeys.remote, ledgerKeys.remote])
        XCTAssertEqual(harness.factory.children.map(\.localKey), ["controller-local", "ledger-local"])

        resolver.unsubscribe()
        resolver.unsubscribe()

        XCTAssertEqual(harness.engine.unsubscribed, [1])
    }

    func testSubscribeWithoutConnectionLogsAndLaterUpdatesAreIgnored() {
        let harness = CovFStkHarness(connected: false)
        let resolver = makeResolver(harness)

        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)
        resolver.handleUpdate(CovFStkFixtures.update(changes: [(controllerKeys.remote, Data([0x01]))]))

        XCTAssertTrue(harness.engine.methods.isEmpty)
        XCTAssertTrue(harness.factory.children.isEmpty)
        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive error"))
        XCTAssertEqual(harness.logger.warnings, ["Staking update received but subscription is missing"])
        XCTAssertTrue(resolver.decodedSubscriptionIds.isEmpty)
        XCTAssertEqual(harness.queue.operationCount, 0)
    }

    func testRefusedSubscriptionIsLoggedAndLeavesNothingToEnd() {
        let harness = CovFStkHarness()
        harness.engine.subscribeError = CovFStkError.stub("refused")
        let resolver = makeResolver(harness)

        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)
        resolver.unsubscribe()

        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive error"))
        XCTAssertEqual(harness.factory.children.count, 2)
        XCTAssertTrue(harness.engine.unsubscribeAttempts.isEmpty)
    }

    func testResubscribingEndsTheReplacedSubscriptionAndUnsubscribeFailureIsLogged() {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)

        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)
        XCTAssertEqual(harness.engine.unsubscribed, [1])

        harness.engine.unsubscribeError = CovFStkError.stub("gone")
        resolver.unsubscribe()
        resolver.unsubscribe()

        XCTAssertEqual(harness.engine.unsubscribeAttempts, [1, 2])
        XCTAssertTrue(harness.logger.hasError(prefix: "Can't unsubscribe from staking storage"))
    }

    func testSubscriptionFailureCallbackIsLogged() throws {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        try withExtendedLifetime(resolver) {
            try harness.engine.fail(error: CovFStkError.stub("dropped"), unsubscribed: true)
        }

        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive subscription error"))
    }

    // MARK: Updates and stash persistence

    func testControllerUpdateReachesChildrenAndStoresStashWithNewController() throws {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)
        resolver.decodedChanges = CovFStkDecoded(controller: CovFStkFixtures.otherId, ledger: nil)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        try harness.engine.deliver(block: CovFStkFixtures.blockHash.toHex(includePrefix: true), changes: [
            [controllerKeys.remote.toHex(includePrefix: true), "0x0a"],
            ["0xdead", "0x0b"],
            [ledgerKeys.remote.toHex(includePrefix: true), NSNull()]
        ])
        harness.queue.waitUntilAllOperationsAreFinished()

        let children = harness.factory.children
        XCTAssertEqual(children.count, 2)
        guard children.count == 2 else { return }
        XCTAssertEqual(children[0].updates, [Data([0x0a])])
        XCTAssertEqual(children[0].blockHashes, [CovFStkFixtures.blockHash])
        XCTAssertEqual(children[1].updates, [nil])
        XCTAssertEqual(resolver.decodedSubscriptionIds, [1])
        let expected = try stash(CovFStkFixtures.accountId, CovFStkFixtures.otherId)
        XCTAssertEqual(harness.repository.items, [expected])
        XCTAssertEqual(harness.repository.savedUpdates, [[expected]])
        XCTAssertEqual(harness.repository.savedDeletes, [[]])
    }

    func testLedgerStashReplacesStoredStashWithAccountAsController() throws {
        let stored = try stash(CovFStkFixtures.accountId, CovFStkFixtures.accountId)
        let harness = CovFStkHarness(items: [stored])
        let resolver = makeResolver(harness)
        let ledger = try CovFStkFixtures.ledger(stash: CovFStkFixtures.otherId)
        resolver.decodedChanges = CovFStkDecoded(controller: nil, ledger: ledger)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        resolver.handleUpdate(CovFStkFixtures.update(changes: [(ledgerKeys.remote, Data([0x01]))]))
        harness.queue.waitUntilAllOperationsAreFinished()

        let expected = try stash(CovFStkFixtures.otherId, CovFStkFixtures.accountId)
        XCTAssertEqual(harness.repository.items, [expected])
        XCTAssertEqual(harness.repository.savedUpdates, [[expected]])
        XCTAssertEqual(harness.repository.savedDeletes, [[stored.stash]])
    }

    func testMissingControllerAndLedgerDeletesStoredStash() throws {
        let stored = try stash(CovFStkFixtures.otherId, CovFStkFixtures.accountId)
        let harness = CovFStkHarness(items: [stored])
        let resolver = makeResolver(harness)
        resolver.decodedChanges = CovFStkDecoded(controller: nil, ledger: nil)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        resolver.handleUpdate(CovFStkFixtures.update(changes: [(ledgerKeys.remote, nil)]))
        harness.queue.waitUntilAllOperationsAreFinished()

        XCTAssertTrue(harness.repository.items.isEmpty)
        XCTAssertEqual(harness.repository.savedUpdates, [[]])
        XCTAssertEqual(harness.repository.savedDeletes, [[stored.stash]])
    }

    func testMissingControllerAndLedgerWithEmptyStoreSavesNothing() throws {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)
        resolver.decodedChanges = CovFStkDecoded(controller: nil, ledger: nil)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        resolver.handleUpdate(CovFStkFixtures.update(changes: []))
        harness.queue.waitUntilAllOperationsAreFinished()

        XCTAssertTrue(harness.repository.items.isEmpty)
        XCTAssertEqual(harness.repository.savedUpdates, [[]])
        XCTAssertEqual(harness.repository.savedDeletes, [[]])
    }

    func testUnchangedStashIsNotRewritten() throws {
        let stored = try stash(CovFStkFixtures.accountId, CovFStkFixtures.otherId)
        let harness = CovFStkHarness(items: [stored])
        let resolver = makeResolver(harness)
        resolver.decodedChanges = CovFStkDecoded(controller: CovFStkFixtures.otherId, ledger: nil)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        resolver.handleUpdate(CovFStkFixtures.update(changes: [(controllerKeys.remote, CovFStkFixtures.otherId)]))
        harness.queue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(harness.repository.items, [stored])
        XCTAssertEqual(harness.repository.savedUpdates, [[]])
        XCTAssertEqual(harness.repository.savedDeletes, [[]])
    }

    func testNewControllerForSameStashUpdatesWithoutDeleting() throws {
        let stored = try stash(CovFStkFixtures.accountId, CovFStkFixtures.accountId)
        let harness = CovFStkHarness(items: [stored])
        let resolver = makeResolver(harness)
        resolver.decodedChanges = CovFStkDecoded(controller: CovFStkFixtures.thirdId, ledger: nil)
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        resolver.handleUpdate(CovFStkFixtures.update(changes: [(controllerKeys.remote, CovFStkFixtures.thirdId)]))
        harness.queue.waitUntilAllOperationsAreFinished()

        let expected = try stash(CovFStkFixtures.accountId, CovFStkFixtures.thirdId)
        XCTAssertEqual(harness.repository.items, [expected])
        XCTAssertEqual(harness.repository.savedUpdates, [[expected]])
        XCTAssertEqual(harness.repository.savedDeletes, [[]])
    }

    func testDecodingFailureLeavesStoredStashUntouched() throws {
        let stored = try stash(CovFStkFixtures.accountId, CovFStkFixtures.otherId)
        let harness = CovFStkHarness(items: [stored])
        let resolver = makeResolver(harness)
        resolver.decodedChanges = nil
        resolver.subscribe(with: controllerKeys, ledgerKeys: ledgerKeys)

        resolver.handleUpdate(CovFStkFixtures.update(changes: [(controllerKeys.remote, Data([0x01]))]))
        harness.queue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(resolver.decodedSubscriptionIds, [1])
        XCTAssertEqual(harness.repository.items, [stored])
        XCTAssertTrue(harness.repository.savedUpdates.isEmpty)
    }

    // MARK: Building blocks

    func testDecodingOperationIsOnlyMadeForAChangedKeyAndReportsCoderFailure() throws {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)
        let changed = CovFStkChild(keys: controllerKeys)
        let unchanged = CovFStkChild(keys: ledgerKeys)
        let data = fearless.StorageUpdateData(update: CovFStkFixtures.update(changes: [(controllerKeys.remote, Data([0x01]))]))
        let coder = BaseOperation<RuntimeCoderFactoryProtocol>()
        coder.result = .failure(CovFStkError.stub("coder"))

        let missing: BaseOperation<Data>? = resolver.createDecodingOperation(
            for: unchanged,
            path: .stakingLedger,
            updateData: data,
            coderOperation: coder
        )
        let made: BaseOperation<Data>? = resolver.createDecodingOperation(
            for: changed,
            path: .controller,
            updateData: data,
            coderOperation: coder
        )

        XCTAssertNil(missing)
        let operation = try XCTUnwrap(made)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let result = try XCTUnwrap(operation.result)
        XCTAssertEqual(covFFailure(result) as? CovFStkError, .stub("coder"))
    }

    func testProcessingOperationPrefersControllerThenLedgerStash() throws {
        let harness = CovFStkHarness()
        let resolver = makeResolver(harness)
        let ledger = try CovFStkFixtures.ledger(stash: CovFStkFixtures.thirdId)
        let controllerStash = try stash(CovFStkFixtures.accountId, CovFStkFixtures.otherId)
        let ledgerStash = try stash(CovFStkFixtures.thirdId, CovFStkFixtures.accountId)
        let cases: [(CovFStkDecoded, StashItem?)] = [
            (CovFStkDecoded(controller: CovFStkFixtures.otherId, ledger: ledger), controllerStash),
            (CovFStkDecoded(controller: nil, ledger: ledger), ledgerStash),
            (CovFStkDecoded(controller: nil, ledger: nil), nil)
        ]

        for (changes, expected) in cases {
            let decoded = BaseOperation<CovFStkDecoded>()
            decoded.result = .success(changes)
            let processing = resolver.createProcessingOperation(
                dependingOn: decoded,
                initAccountId: CovFStkFixtures.accountId,
                chainFormat: CovFStkFixtures.format
            )
            OperationQueue().addOperations([processing], waitUntilFinished: true)
            switch processing.result {
            case let .success(item)?:
                XCTAssertEqual(item, expected)
            case let .failure(error)?:
                XCTFail("Unexpected error \(error)")
            case .none:
                XCTFail("No result")
            }
        }
    }
}

final class CovFStkResolverV14Tests: XCTestCase {
    private func ledgerScale(stash: Data) -> String {
        // StakingLedger on Asset Hub: stash, Compact total (40), Compact active (20), empty unlocking.
        stash.toHex(includePrefix: true) + "a05000"
    }

    func testResolverWithoutRuntimeLogsAndCannotDecode() throws {
        let harness = CovFStkHarness()
        let resolver = harness.makeV14Resolver()

        XCTAssertTrue(harness.logger.hasError(prefix: "Did receive error"))
        XCTAssertTrue(harness.engine.methods.isEmpty)

        let subscription = BaseStakingAccountResolver.Subscription(
            controller: CovFStkChild(keys: SubscriptionStorageKeys(remote: Data([0x01]), local: "c")),
            ledger: CovFStkChild(keys: SubscriptionStorageKeys(remote: Data([0x02]), local: "l")),
            subscriptionId: 9,
            connection: harness.engine
        )
        let update = fearless.StorageUpdateData(update: CovFStkFixtures.update(changes: [(Data([0x01]), Data([0x02]))]))
        let wrapper = resolver.createDecodingWrapper(from: update, subscription: subscription)

        XCTAssertThrowsError(try CovFFixtures.execute(wrapper)) { error in
            guard let registryError = error as? fearless.ChainRegistryError, case .runtimeMetadaUnavailable = registryError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testCoderFailureIsLoggedWithoutSubscribing() {
        let harness = CovFStkHarness(runtime: CovFStkRuntime(.failure(CovFStkError.stub("coder"))))
        let logged = covFStkExpectation("key error logged")
        harness.logger.onError = { message in
            if message.hasPrefix("Did receiver error") {
                logged.fulfill()
            }
        }

        let resolver = harness.makeV14Resolver()
        withExtendedLifetime(resolver) {
            wait(for: [logged], timeout: 5)
        }

        XCTAssertTrue(harness.engine.methods.isEmpty)
        XCTAssertTrue(harness.factory.children.isEmpty)
    }

    func testResolverSubscribesBondedAndLedgerKeysAndStoresDecodedController() throws {
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        let subscribed = covFStkExpectation("subscribed")
        harness.engine.onSubscribe = { subscribed.fulfill() }

        let resolver = harness.makeV14Resolver()
        wait(for: [subscribed], timeout: 5)

        let params = try XCTUnwrap(harness.engine.params.first)
        XCTAssertEqual(params.count, 2)
        guard params.count == 2 else { return }
        let controllerKey = try Data(hexStringSSF: params[0])
        let ledgerKey = try Data(hexStringSSF: params[1])
        XCTAssertEqual(Data(controllerKey.prefix(32)), try CovFStkFixtures.storagePrefix(.controller))
        XCTAssertEqual(Data(controllerKey.suffix(32)), CovFStkFixtures.accountId)
        XCTAssertEqual(Data(ledgerKey.prefix(32)), try CovFStkFixtures.storagePrefix(.stakingLedger))
        XCTAssertEqual(Data(ledgerKey.suffix(32)), CovFStkFixtures.accountId)
        let expectedLocalKeys = try [
            CovFStkFixtures.localKey(.controller, accountId: CovFStkFixtures.accountId),
            CovFStkFixtures.localKey(.stakingLedger, accountId: CovFStkFixtures.accountId)
        ]
        XCTAssertEqual(harness.factory.children.map(\.localKey), expectedLocalKeys)

        try harness.engine.deliver(changes: [[params[0], CovFStkFixtures.otherId.toHex(includePrefix: true)]])
        harness.queue.waitUntilAllOperationsAreFinished()

        let expected = try StashItem(
            stash: CovFStkFixtures.address(CovFStkFixtures.accountId),
            controller: CovFStkFixtures.address(CovFStkFixtures.otherId)
        )
        XCTAssertEqual(harness.repository.items, [expected])
        withExtendedLifetime(resolver) {}
    }

    func testResolverDecodesLedgerStashAsStashOfThisController() throws {
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        let subscribed = covFStkExpectation("subscribed")
        harness.engine.onSubscribe = { subscribed.fulfill() }

        let resolver = harness.makeV14Resolver()
        wait(for: [subscribed], timeout: 5)

        let params = try XCTUnwrap(harness.engine.params.first)
        XCTAssertEqual(params.count, 2)
        guard params.count == 2 else { return }
        try harness.engine.deliver(changes: [[params[1], ledgerScale(stash: CovFStkFixtures.thirdId)]])
        harness.queue.waitUntilAllOperationsAreFinished()

        let expected = try StashItem(
            stash: CovFStkFixtures.address(CovFStkFixtures.thirdId),
            controller: CovFStkFixtures.address(CovFStkFixtures.accountId)
        )
        XCTAssertEqual(harness.repository.items, [expected])
        withExtendedLifetime(resolver) {}
    }

    func testMalformedLedgerIsNotSaved() throws {
        let harness = CovFStkHarness(runtime: try CovFStkFixtures.assetHub())
        let subscribed = covFStkExpectation("subscribed")
        harness.engine.onSubscribe = { subscribed.fulfill() }

        let resolver = harness.makeV14Resolver()
        wait(for: [subscribed], timeout: 5)

        let params = try XCTUnwrap(harness.engine.params.first)
        XCTAssertEqual(params.count, 2)
        guard params.count == 2 else { return }
        try harness.engine.deliver(changes: [[params[1], "0x00"]])
        harness.queue.waitUntilAllOperationsAreFinished()

        XCTAssertTrue(harness.repository.items.isEmpty)
        XCTAssertTrue(harness.repository.savedUpdates.isEmpty)
        withExtendedLifetime(resolver) {}
    }

    func testAssemblyBuildsTheV14Resolver() {
        let harness = CovFStkHarness()
        let resolver = StakingAccountResolverAssembly.createResolver(
            accountId: CovFStkFixtures.accountId,
            chainAsset: CovFStkFixtures.chainAsset,
            chainFormat: CovFStkFixtures.format,
            chainRegistry: harness.registry,
            childSubscriptionFactory: harness.factory,
            operationQueue: harness.queue,
            repository: AnyDataProviderRepository(harness.repository),
            logger: harness.logger
        )

        XCTAssertTrue(resolver is StakingAccountResolverV14)
        XCTAssertEqual(harness.logger.errors.count, 1, "the resolver tried to resolve its keys without a runtime")
    }
}
